// lib/features/youtube/presentation/pages/audio_editor_page.dart
// (Audio editor screen with trimming, exporting, uploading, and ringtone flows)
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/features/home/presentation/widgets/share_screen.dart';
import 'package:kakan/features/youtube/data/api_service.dart';
import 'package:kakan/features/youtube/presentation/pages/contact_picker_page.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

// Theming
const _bg       = Color(0xFF0F1115);
const _card     = Color(0xFF171A20);
const _muted    = Color(0xFF9AA4B2);
const _text     = Color(0xFFE6EAF2);
const _accent   = Color(0xFF00E5A8);
const _accent2  = Color(0xFF4C82FB);
const _fieldBg  = Color(0xFF141821);
const _trimBg   = Color(0xFF131720);
const _overlay  = Color(0x7F000000);

class AudioEditorPage extends StatefulWidget {
  final String audioPath;
  final String title;
  final String videoId;
  final String? thumbnailUrl;

  const AudioEditorPage({
    Key? key,
    required this.audioPath,
    required this.title,
    required this.videoId,
    this.thumbnailUrl,
  }) : super(key: key);

  @override
  State<AudioEditorPage> createState() => _AudioEditorPageState();
}

class _AudioEditorPageState extends State<AudioEditorPage>
    with TickerProviderStateMixin {
  final YoutubeApiService _apiService = di.sl<YoutubeApiService>();

  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  // Ringtone channel
  static const MethodChannel _channel =
      MethodChannel('com.example.kakan/ringtone_channel');

  // Audio + waveform
  late final AudioPlayer _player;
  late final PlayerController _waveformController;

  // Durations & trim state
  Duration _audioDuration = Duration.zero;
  double _trimStartPercent = 0.0;
  double _trimEndPercent = 1.0;
  double _currentPositionPercent = 0.0;

  // Text fields (mm:ss)
  late final TextEditingController _trimStartController;
  late final TextEditingController _trimEndController;
  late final FocusNode _startFocusNode;
  late final FocusNode _endFocusNode;

  // State/UI
  bool _isPlaying = false;
  bool _isWaveformLoaded = false;
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  // Export/Upload progress UX
  final _isExporting = ValueNotifier<bool>(false);
  final _isUploading = ValueNotifier<bool>(false);
  final _uploadProgress = ValueNotifier<double>(0.0);
  late final AnimationController _indeterminateCtrl; // shimmer
  late final AnimationController _pulseCtrl;         // pulse

  // Streams
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;

  // Prefetched video thumbnail
  String? _prefetchedThumbPath;

  @override
  void initState() {
    super.initState();

    _player = AudioPlayer();
    _waveformController = PlayerController();

    _trimStartController = TextEditingController();
    _trimEndController   = TextEditingController();
    _startFocusNode = FocusNode();
    _endFocusNode   = FocusNode();

    _indeterminateCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
          ..repeat(reverse: true);

    _initAudio();
    _maybePrefetchThumbnail();

    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state.playing);
      if (state.processingState == ProcessingState.completed) {
        _player.seek(Duration(
          milliseconds: (_trimStartPercent * _audioDuration.inMilliseconds).round(),
        ));
        setState(() => _currentPositionPercent = _trimStartPercent);
      }
    });

    _positionSubscription = _player.positionStream.listen((position) {
      if (!mounted || _audioDuration.inMilliseconds <= 0) return;

      final currentMillis = position.inMilliseconds;
      final endMillis = (_trimEndPercent * _audioDuration.inMilliseconds).round();

      setState(() {
        _currentPositionPercent = (currentMillis / _audioDuration.inMilliseconds)
            .clamp(_trimStartPercent, _trimEndPercent);
      });

      if (_isPlaying && currentMillis >= endMillis) {
        _player.pause();
        _player.seek(Duration(milliseconds: endMillis));
      }
    });
  }

  Future<void> _initAudio() async {
    try {
      await _player.setFilePath(widget.audioPath);
      final duration = await _player.load();
      await _waveformController.preparePlayer(
        path: widget.audioPath,
        shouldExtractWaveform: true,
      );
      if (!mounted) return;
      setState(() {
        _audioDuration = duration ?? Duration.zero;
        _isWaveformLoaded = true;
      });
      _updateTextControllers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load audio: $e')),
      );
      context.pop();
    }
  }

  Future<void> _maybePrefetchThumbnail() async {
    final url = widget.thumbnailUrl;
    if (url == null || url.isEmpty) return;

    try {
      final uri = Uri.tryParse(url);
      if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) return;

      final ext = p.extension(uri.path).toLowerCase();
      final safeExt = (ext == '.png' || ext == '.jpg' || ext == '.jpeg') ? ext.replaceFirst('.', '') : 'jpg';
      final out = await _ioOutputPath(safeExt);

      final client = HttpClient();
      final req = await client.getUrl(uri);
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final file = File(out);
        final sink = file.openWrite();
        await resp.forEach((bytes) => sink.add(bytes));
        await sink.flush();
        await sink.close();

        if (await file.exists() && await file.length() > 0) {
          setState(() => _prefetchedThumbPath = out);
          debugPrint('AudioEditorPage: Prefetched thumbnail to $out');
        }
      }
      client.close(force: true);
    } catch (e) {
      debugPrint('AudioEditorPage: thumbnail prefetch failed: $e');
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _indeterminateCtrl.dispose();
    _pulseCtrl.dispose();
    _isExporting.dispose();
    _isUploading.dispose();
    _uploadProgress.dispose();
    _player.dispose();
    _waveformController.dispose();
    _trimStartController.dispose();
    _trimEndController.dispose();
    _startFocusNode.dispose();
    _endFocusNode.dispose();
    super.dispose();
  }

  double get _trimStartSeconds => _audioDuration.inMilliseconds > 0
      ? _audioDuration.inMilliseconds / 1000 * _trimStartPercent
      : 0.0;
  double get _trimEndSeconds => _audioDuration.inMilliseconds > 0
      ? _audioDuration.inMilliseconds / 1000 * _trimEndPercent
      : 0.0;

  Future<String> _ioOutputPath(String extension) async {
    final tempPath = (await getTemporaryDirectory()).path;
    final name = p.basenameWithoutExtension(widget.audioPath);
    final epoch = DateTime.now().millisecondsSinceEpoch;
    return "$tempPath/${name}_$epoch.$extension";
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return h > 0 ? "${two(h)}:$m:$s" : "$m:$s";
  }

  Duration? _parseDuration(String text) {
    try {
      final parts = text.split(':');
      if (parts.length != 2) return null;
      final minutes = int.parse(parts[0]);
      final seconds = int.parse(parts[1]);
      if (minutes < 0 || seconds < 0 || seconds >= 60) return null;
      return Duration(minutes: minutes, seconds: seconds);
    } catch (_) {
      return null;
    }
  }

  void _updateTextControllers() {
    final startText = _formatDuration(
      Duration(milliseconds: (_trimStartSeconds * 1000).round()),
    );
    final endText = _formatDuration(
      Duration(milliseconds: (_trimEndSeconds * 1000).round()),
    );
    if (!_startFocusNode.hasFocus && _trimStartController.text != startText) {
      _trimStartController.text = startText;
    }
    if (!_endFocusNode.hasFocus && _trimEndController.text != endText) {
      _trimEndController.text = endText;
    }
  }

  Future<String?> _exportTrimmedAudio() async {
    if (_isExporting.value || _isUploading.value) return null;
    _isExporting.value = true;

    final outputPath = await _ioOutputPath('mp3');
    final start = _trimStartSeconds;
    final duration =
        (_trimEndSeconds - _trimStartSeconds).clamp(0.1, double.infinity);
    final command =
        '-y -ss $start -t $duration -i "${widget.audioPath}" -vn -c:a libmp3lame -q:a 2 "$outputPath"';

    try {
      final sess = await FFmpegKit.execute(command);
      final rc = await sess.getReturnCode();
      if (!ReturnCode.isSuccess(rc)) {
        final logs = await sess.getAllLogs();
        final errorMessage = logs.map((l) => l.getMessage()).join('\n');
        throw ServerException(message: 'FFmpeg failed: $errorMessage');
      }
      final f = File(outputPath);
      if (!await f.exists() || await f.length() < 1024) {
        throw ServerException(message: 'Exported audio is invalid.');
      }
      return outputPath;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export: $e'), backgroundColor: Colors.redAccent),
      );
      return null;
    } finally {
      _isExporting.value = false;
    }
  }

  Future<String> _exportWaveformThumbnail(String audioPath) async {
    final out = await _ioOutputPath('png');
    final color = _hex(_accent);
    final cmd =
        '-y -i "$audioPath" -filter_complex "aformat=channel_layouts=mono,showwavespic=s=720x720:split_channels=0:colors=$color" -frames:v 1 "$out"';

    final sess = await FFmpegKit.execute(cmd);
    final rc = await sess.getReturnCode();
    if (!ReturnCode.isSuccess(rc)) {
      final logs = await sess.getAllLogs();
      final msg = logs.map((l) => l.getMessage()).join('\n');
      throw ServerException(message: 'Thumbnail export failed: $msg');
    }
    final f = File(out);
    if (!await f.exists() || await f.length() == 0) {
      throw ServerException(message: 'Thumbnail file missing or empty.');
    }
    return out;
  }

  Future<void> _uploadAudio(String outputPath, {String? thumbnailPath}) async {
    _isUploading.value = true;
    _uploadProgress.value = 0.0;

    try {
      for (int attempt = 0; attempt < _maxRetries; attempt++) {
        try {
          final duration = (_trimEndSeconds - _trimStartSeconds).round();
          await _apiService.saveDownloadedVideo(
            title: widget.title,
            filePath: outputPath,
            duration: _formatDuration(Duration(seconds: duration)),
            mediaType: 'audio',
            thumbnailPath: thumbnailPath,
            onSendProgress: (sent, total) {
              final progress = total == 0 ? 0.0 : (sent / total).clamp(0.0, 1.0);
              _uploadProgress.value = progress;
            },
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Audio uploaded successfully'),
              backgroundColor: Colors.green,
            ),
          );
          if (mounted) context.push('/home', extra: {'filePath': outputPath});
          return;
        } catch (e) {
          if (attempt >= _maxRetries - 1) rethrow;
          await Future.delayed(_retryDelay * (attempt + 1));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload audio: $e'),
          backgroundColor: Colors.redAccent,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _uploadAudio(outputPath, thumbnailPath: thumbnailPath),
          ),
        ),
      );
    } finally {
      _isUploading.value = false;
    }
  }

  Future<void> _exportAudio() async {
    final trimmed = await _exportTrimmedAudio();
    if (trimmed == null) return;

    String? thumbPathForUpload = _prefetchedThumbPath;
    if (thumbPathForUpload == null) {
      try {
        thumbPathForUpload = await _exportWaveformThumbnail(trimmed);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Thumbnail generation failed (continuing): $e')),
        );
      }
    }

    await _uploadAudio(trimmed, thumbnailPath: thumbPathForUpload);
  }

  Future<void> _shareAudio() async {
    final trimmed = await _exportTrimmedAudio();
    if (trimmed == null) return;

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ShareScreen(
        mediaFile: trimmed,
        mediaType: 'audio',
        caption: widget.title,
      ),
    );
  }

  // =========================
  // Ringtone UI
  // =========================

  Future<void> _showRingtoneModal() async {
    final trimmed = await _exportTrimmedAudio();
    if (trimmed == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) => SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grab handle
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: const [
                Icon(Icons.ring_volume, color: _accent),
                SizedBox(width: 8),
                Text('Set as Ringtone', style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 18),

            _RingtoneOptionCard(
              icon: Icons.phone_android,
              title: 'Default (All Calls)',
              subtitle: 'Use this audio for all incoming calls',
              accent: _accent,
              onTap: () async {
                Navigator.pop(modalContext);
                final success = await _setGlobalRingtone(trimmed);
                if (success) {
                  await _showRingtoneSuccessSheet(
                    title: 'Ringtone set!',
                    subtitle: 'Applied as default for all calls (both SIMs where supported).',
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to set default ringtone')),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            _RingtoneOptionCard(
              icon: Icons.person,
              title: 'Specific Contacts',
              subtitle: 'Choose contacts to assign this ringtone',
              accent: _accent2,
              onTap: () async {
                Navigator.pop(modalContext);
                final contacts = await _pickContacts();
                if (contacts != null && contacts.isNotEmpty) {
                  bool allSuccess = true;
                  for (var contact in contacts) {
                    final ok = await _setContactRingtone(contact.id, trimmed);
                    if (!ok) allSuccess = false;
                  }
                  if (allSuccess) {
                    await _showRingtoneSuccessSheet(
                      title: 'Ringtone set!',
                      subtitle: 'Assigned to ${contacts.length} contact${contacts.length == 1 ? '' : 's'}.',
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to set for some contacts')),
                    );
                  }
                }
              },
            ),

            const SizedBox(height: 16),
            const Divider(color: Color(0xFF2A3242)),
            const SizedBox(height: 8),
            Row(
              children: const [
                Icon(Icons.info_outline, color: _muted, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You may be prompted to allow system settings or contacts permission.',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<bool> _setGlobalRingtone(String filePath) async {
    try {
      final canWrite = await _channel.invokeMethod<bool>('canWriteSettings');
      if (canWrite != true) {
        await _channel.invokeMethod('openWriteSettings');
        return false;
      }
      return await _channel.invokeMethod<bool>(
                'setGlobalRingtone', {'filePath': filePath}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _setContactRingtone(String contactId, String filePath) async {
    try {
      if (!await Permission.contacts.isGranted) {
        await Permission.contacts.request();
      }
      return await _channel.invokeMethod<bool>('setContactRingtone', {
            'contactId': contactId,
            'filePath': filePath,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<List<Contact>?> _pickContacts() async {
    if (!await Permission.contacts.isGranted) {
      await Permission.contacts.request();
      return null;
    }
    return await Navigator.of(context).push<List<Contact>>(
      MaterialPageRoute(builder: (_) => const ContactPickerPage()),
    );
  }

  Future<void> _openSoundSettings() async {
    try {
      await _channel.invokeMethod('openSoundSettings');
    } catch (_) {}
  }

  Future<void> _showRingtoneSuccessSheet({
    required String title,
    required String subtitle,
  }) async {
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          minimum: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.85, end: 1.0),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [_accent2, _accent]),
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withOpacity(0.35),
                        blurRadius: 22,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check_rounded, size: 40, color: Colors.white),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  color: _text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openSoundSettings();
                      },
                      icon: const Icon(Icons.settings, color: _text),
                      label: const Text('Sound settings', style: TextStyle(color: _text)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF2A3242)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text('Done',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent2,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  ThemeData _theme(BuildContext context) {
    return Theme.of(context).copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _bg,
      colorScheme: const ColorScheme.dark(
        primary: _accent,
        secondary: _accent2,
        surface: _card,
        background: _bg,
        onPrimary: _bg,
      ),
      textTheme: Theme.of(context).textTheme.apply(
            bodyColor: _text,
            displayColor: _text,
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _bg,
        foregroundColor: _text,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _fieldBg,
        hintStyle: const TextStyle(color: _muted),
        labelStyle: const TextStyle(color: _muted),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF30384A)),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _accent),
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent2,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF232A36),
        contentTextStyle: TextStyle(color: _text),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _progressOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: ValueListenableBuilder<bool>(
          valueListenable: _isExporting,
          builder: (_, exporting, __) {
            return ValueListenableBuilder<bool>(
              valueListenable: _isUploading,
              builder: (_, uploading, __) {
                final visible = exporting || uploading;
                return AnimatedOpacity(
                  opacity: visible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: visible
                      ? Container(
                          color: _overlay,
                          alignment: Alignment.bottomCenter,
                          child: SafeArea(
                            minimum: const EdgeInsets.all(16),
                            child: _ProgressPanel(
                              exporting: exporting,
                              uploading: uploading,
                              uploadProgressListenable: _uploadProgress,
                              shimmerController: _indeterminateCtrl,
                              pulseController: _pulseCtrl,
                              title: exporting ? 'Exporting audio…' : 'Uploading audio…',
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _trimBar(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;

      const handleStartColor = _accent;
      const handleEndColor   = _accent2;
      const playheadColor    = Colors.yellowAccent;
      const liveWaveColor    = Colors.cyanAccent;

      return Column(
        children: [
          SizedBox(
            height: 112,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 78,
                  decoration: BoxDecoration(
                    color: _trimBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2A3242)),
                  ),
                  child: AudioFileWaveforms(
                    size: Size(width, 78),
                    playerController: _waveformController,
                    enableSeekGesture: false,
                    waveformType: WaveformType.fitWidth,
                    playerWaveStyle: const PlayerWaveStyle(
                      fixedWaveColor: Color(0xFF2D3748),
                      liveWaveColor: liveWaveColor,
                      spacing: 4,
                      waveThickness: 2.2,
                      scaleFactor: 100,
                    ),
                  ),
                ),
                Positioned(
                  left: width * _trimStartPercent,
                  right: width * (1.0 - _trimEndPercent),
                  child: Container(
                    height: 78,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          handleStartColor.withOpacity(0.18),
                          handleEndColor.withOpacity(0.18),
                        ],
                      ),
                      border: Border.all(color: const Color(0x66FFFFFF)),
                    ),
                  ),
                ),
                Positioned(
                  left: (width * _currentPositionPercent)
                      .clamp(width * _trimStartPercent, width * _trimEndPercent),
                  child: Container(
                    width: 2.5,
                    height: 92,
                    decoration: BoxDecoration(
                      color: playheadColor,
                      boxShadow: [
                        BoxShadow(
                          color: playheadColor.withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: width * _trimStartPercent - 12,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        final newPercent = _trimStartPercent + details.delta.dx / width;
                        _trimStartPercent = newPercent.clamp(0.0, _trimEndPercent - 0.05);
                      });
                      _updateTextControllers();
                    },
                    child: _buildTrimHandle(handleStartColor, isLeft: true),
                  ),
                ),
                Positioned(
                  left: width * _trimEndPercent - 12,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        final newPercent = _trimEndPercent + details.delta.dx / width;
                        _trimEndPercent = newPercent.clamp(_trimStartPercent + 0.05, 1.0);
                      });
                      _updateTextControllers();
                    },
                    child: _buildTrimHandle(handleEndColor, isLeft: false),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _trimStartController,
                  focusNode: _startFocusNode,
                  style: const TextStyle(color: _text, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: 'Start',
                    hintText: 'mm:ss',
                  ),
                  onSubmitted: (value) {
                    final newDur = _parseDuration(value);
                    if (newDur != null && _audioDuration.inMilliseconds > 0) {
                      setState(() {
                        final newPercent = (newDur.inMilliseconds / _audioDuration.inMilliseconds)
                            .clamp(0.0, 1.0);
                        _trimStartPercent = newPercent.clamp(0.0, _trimEndPercent - 0.05);
                      });
                    }
                    _updateTextControllers();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _trimEndController,
                  focusNode: _endFocusNode,
                  style: const TextStyle(color: _text, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: 'End',
                    hintText: 'mm:ss',
                  ),
                  onSubmitted: (value) {
                    final newDur = _parseDuration(value);
                    if (newDur != null && _audioDuration.inMilliseconds > 0) {
                      setState(() {
                        final newPercent = (newDur.inMilliseconds / _audioDuration.inMilliseconds)
                            .clamp(0.0, 1.0);
                        _trimEndPercent = newPercent.clamp(_trimStartPercent + 0.05, 1.0);
                      });
                    }
                    _updateTextControllers();
                  },
                ),
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _buildTrimHandle(Color color, {required bool isLeft}) {
    return Container(
      width: 24,
      height: 98,
      decoration: BoxDecoration(
        color: color,
        borderRadius: isLeft
            ? const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8))
            : const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, spreadRadius: 2),
        ],
      ),
      child: Center(
        child: Icon(isLeft ? Icons.chevron_left : Icons.chevron_right, color: _bg),
      ),
    );
  }

  void _handlePlayPause() {
    if (_isPlaying) {
      _player.pause();
    } else {
      final startMillis =
          (_trimStartPercent * _audioDuration.inMilliseconds).round();
      final currentMillis = _player.position.inMilliseconds;
      final endMillis =
          (_trimEndPercent * _audioDuration.inMilliseconds).round();

      if (currentMillis < startMillis || currentMillis >= endMillis) {
        _player.seek(Duration(milliseconds: startMillis));
      }
      _player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _theme(context);
    return Theme(
      data: theme,
      child: Scaffold(
        key: _messengerKey,
        backgroundColor: _bg,
        appBar: AppBar(
          title: Text(
            widget.title,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // Preview card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 14,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            // Play/Pause
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: Icon(
                                  _isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.black,
                                ),
                                iconSize: 50,
                                onPressed: _handlePlayPause,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _isWaveformLoaded
                                  ? '${_formatDuration(Duration(milliseconds: (_currentPositionPercent * _audioDuration.inMilliseconds).round()))}  /  ${_formatDuration(_audioDuration)}'
                                  : '00:00 / 00:00',
                              style: const TextStyle(color: _muted),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Trim section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 14,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                        child: _isWaveformLoaded
                            ? _trimBar(context)
                            : const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: CircularProgressIndicator(color: _accent),
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Footer actions
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _isExporting,
                        builder: (_, exporting, __) {
                          return ValueListenableBuilder<bool>(
                            valueListenable: _isUploading,
                            builder: (_, uploading, __) {
                              final busy = exporting || uploading;
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _PrimaryButton(
                                    icon: Icons.save_alt,
                                    label: 'SAVE',
                                    onPressed: _exportAudio,
                                    enabled: !busy,
                                  ),
                                  _PrimaryButton(
                                    icon: Icons.share,
                                    label: 'SHARE',
                                    onPressed: _shareAudio,
                                    enabled: !busy,
                                  ),
                                  _PrimaryButton(
                                    icon: Icons.ring_volume,
                                    label: 'RINGTONE',
                                    onPressed: _showRingtoneModal,
                                    enabled: !busy,
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Export/Upload overlay
            _progressOverlay(),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final bool enabled;

  const _PrimaryButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _accent2,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  final bool exporting;
  final bool uploading;
  final ValueListenable<double> uploadProgressListenable;
  final AnimationController shimmerController;
  final AnimationController pulseController;
  final String title;

  const _ProgressPanel({
    required this.exporting,
    required this.uploading,
    required this.uploadProgressListenable,
    required this.shimmerController,
    required this.pulseController,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 18,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseIcon(pulse: pulseController),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: _text,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: exporting
                ? _IndeterminateBar(controller: shimmerController)
                : ValueListenableBuilder<double>(
                    valueListenable: uploadProgressListenable,
                    builder: (_, p, __) => _DeterminateBar(progress: p),
                  ),
          ),
          const SizedBox(height: 10),
          if (uploading)
            ValueListenableBuilder<double>(
              valueListenable: uploadProgressListenable,
              builder: (_, p, __) => Text(
                'Uploading ${(_clamp01(p) * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: _muted),
              ),
            )
          else
            const Text(
              'Optimizing & preparing your audio…',
              style: TextStyle(color: _muted),
            ),
        ],
      ),
    );

    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      offset: const Offset(0, 0.06),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: 1.0,
        child: panel,
      ),
    );
  }
}

double _clamp01(double v) => v.clamp(0.0, 1.0);

class _PulseIcon extends StatelessWidget {
  final AnimationController pulse;
  const _PulseIcon({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      width: 42,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (_, __) {
          final scale = 0.9 + pulse.value * 0.1;
          final opacity = 0.6 + pulse.value * 0.4;
          return Transform.scale(
            scale: scale,
            child: Container(
              decoration: BoxDecoration(
                color: _accent.withOpacity(opacity),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _accent.withOpacity(0.25 + pulse.value * 0.25),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.graphic_eq, color: _bg),
            ),
          );
        },
      ),
    );
  }
}

class _IndeterminateBar extends StatelessWidget {
  final AnimationController controller;
  const _IndeterminateBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      key: const ValueKey('indeterminate'),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: const Color(0xFF222937),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2A3242)),
        ),
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, __) {
            final dx = controller.value;
            return Stack(
              children: [
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment(-1 + dx * 2, 0),
                    widthFactor: 0.35,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0x0052FFCF),
                            Color(0xFF52FFCF),
                            Color(0x0052FFCF),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DeterminateBar extends StatelessWidget {
  final double progress;
  const _DeterminateBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final p = _clamp01(progress);
    return ClipRRect(
      key: const ValueKey('determinate'),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: const Color(0xFF222937),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2A3242)),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: p),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) => FractionallySizedBox(
              widthFactor: value,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_accent2, _accent],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingtoneOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _RingtoneOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _bg.withOpacity(0.32),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withOpacity(0.55), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.18),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withOpacity(0.7)),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: _text, fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(color: _muted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _muted),
          ],
        ),
      ),
    );
  }
}

String _hex(Color c) {
  return '#${c.red.toRadixString(16).padLeft(2, '0')}${c.green.toRadixString(16).padLeft(2, '0')}${c.blue.toRadixString(16).padLeft(2, '0')}';
}
