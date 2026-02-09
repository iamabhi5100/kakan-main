// lib/features/youtube/presentation/pages/video_editor_screen.dart
//
// On Android: Uses NativeVideoView (VideoView) to avoid Mali green diagonal glitch.
// On iOS: Uses standard VideoPlayer.
// Save / Share / Testing: All use the same Code-2-style Mali-safe FFmpeg export
// (bwdif, setsar, scale even dims, yuv420p, pad mod32, libx264 baseline@3.1, BT.709, CFR 30fps).

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'package:kakan/core/utils/session_manager.dart';
import 'package:kakan/features/home/presentation/widgets/share_screen.dart';
import 'package:kakan/features/youtube/data/api_service.dart';
import 'package:kakan/features/youtube/presentation/widgets/native_video_player.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:kakan/services/ffmpeg_exporter.dart';

const String _postsUrl = 'https://staging.api.kakan.co/v1/posts/';

/* ===================== THEME (Neon green & blue, white text) ===================== */
const _bg = Color(0xFF0A0C10);
const _card = Color(0xFF12151C);
const _cardElevated = Color(0xFF1A1E28);
const _muted = Color(0xFF8B95A5);
const _text = Color(0xFFF0F3F8);
const _accent = Color(0xFF00E5A8);       // Neon green
const _accent2 = Color(0xFF00B4D8);      // Neon blue
const _overlay = Color(0xCC0A0C10);
const _neonGreenGlow = Color(0x4000E5A8);
const _neonBlueGlow = Color(0x4000B4D8);

/* ===================== SCREEN ===================== */
class VideoEditorScreen extends StatefulWidget {
  final String videoPath;
  final String videoId;
  final String title;

  const VideoEditorScreen({
    super.key,
    required this.videoPath,
    required this.videoId,
    required this.title,
  });

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen>
    with TickerProviderStateMixin {
  VideoPlayerController? _playerController;
  NativeVideoController? _nativeController;
  bool _inited = false;
  final _useNative = Platform.isAndroid;

  final _isUploading = ValueNotifier(false);
  final _uploadProgress = ValueNotifier(0.0);
  final _isExporting = ValueNotifier(false);
  final _currentPositionSec = ValueNotifier<double>(0.0);
  bool _isPlaying = false;

  double _durationSec = 0.0;
  double _trimStartSec = 0.0;
  double _trimEndSec = 0.0;
  double _videoAspectRatioValue = 9 / 16; // Dynamic: vertical (shorts) or horizontal (regular)

  Timer? _positionTimer;
  void _onPlayerPositionUpdate() {
    if (!mounted) return;
    if (_playerController != null) {
      _currentPositionSec.value = _playerController!.value.position.inMilliseconds / 1000.0;
    }
  }

  late final AnimationController _pulseCtrl;

  final _api = di.sl<YoutubeApiService>();
  final _sessionManager = SessionManager();

  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  void _snack(String msg, {Color? bg}) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final m = _messengerKey.currentState;
      if (m == null) return;
      m.clearSnackBars();
      m.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.fixed,
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: bg ?? const Color(0xFF232A36),
        duration: const Duration(seconds: 4),
      ));
    });
  }

  @override
  void initState() {
    super.initState();
    _boot();
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
          ..repeat(reverse: true);
  }

  Future<void> _boot() async {
    try {
      _durationSec = (await FFmpegExporter.getMediaDuration(widget.videoPath)).inMilliseconds / 1000.0;
      if (_durationSec <= 0) _durationSec = 1.0;
      _trimEndSec = _durationSec;
      if (_useNative) {
        _nativeController = NativeVideoController();
        _videoAspectRatioValue = await FFmpegExporter.getMediaAspectRatio(widget.videoPath);
        setState(() => _inited = true);
        _positionTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
          if (!mounted) return;
          final pos = await _nativeController?.getPosition();
          if (pos != null) _currentPositionSec.value = pos.inMilliseconds / 1000.0;
        });
      } else {
        _playerController = VideoPlayerController.file(File(widget.videoPath));
        await _playerController!.initialize();
        await _playerController!.setLooping(true);
        _durationSec = _playerController!.value.duration.inMilliseconds / 1000.0;
        if (_durationSec <= 0) _durationSec = 1.0;
        _trimEndSec = _durationSec;
        _videoAspectRatioValue = _playerController!.value.aspectRatio.clamp(0.1, 10.0);
        setState(() => _inited = true);
        _playerController!.addListener(_onPlayerPositionUpdate);
      }
    } catch (e) {
      _snack('Failed to open video: $e', bg: Colors.redAccent);
      context.pop();
    }
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _playerController?.removeListener(_onPlayerPositionUpdate);
    _playerController?.dispose();
    _isUploading.dispose();
    _uploadProgress.dispose();
    _isExporting.dispose();
    _currentPositionSec.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_useNative) {
      if (_isPlaying) {
        await _nativeController?.pause();
      } else {
        await _nativeController?.play();
      }
      if (mounted) setState(() => _isPlaying = !_isPlaying);
    } else {
      if (_playerController!.value.isPlaying) {
        _playerController!.pause();
      } else {
        _playerController!.play();
      }
    }
  }

  /// Single Code-2-style Mali-safe export: used for Save, Share, and Testing.
  /// Uses current trim range (_trimStartSec, _trimEndSec).
  Future<String?> _exportMaliSafe() async {
    if (_isExporting.value) return null;
    _isExporting.value = true;
    try {
      final start = math.max(0.0, math.min(_trimStartSec, _durationSec));
      final end = math.max(start + 0.25, math.min(_trimEndSec, _durationSec));
      final out = await FFmpegExporter.exportMaliSafe(
        widget.videoPath,
        trimStart: Duration(milliseconds: (start * 1000).round()),
        trimEnd: Duration(milliseconds: (end * 1000).round()),
      );
      if (await File(out).exists()) return out;
    } catch (e) {
      if (mounted) _snack('Export failed: $e', bg: Colors.redAccent);
      return null;
    } finally {
      _isExporting.value = false;
    }
    return null;
  }

  static String _fmt(double s) {
    final d = Duration(milliseconds: (s * 1000).round());
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  // ---- filename sanitizers (≤ 100 chars) for multipart ----
  static String _sanitizeExt(String ext, {required String fallback}) {
    final e = (ext.isEmpty ? fallback : ext).toLowerCase();
    final clean = e.replaceAll(RegExp(r'[^.a-z0-9]'), '');
    return clean.isEmpty ? fallback : clean;
  }

  static String _inferVideoSubtype(String ext) {
    switch (ext) {
      case '.mp4':
      case '.m4v':
        return 'mp4';
      case '.webm':
        return 'webm';
      case '.mov':
        return 'quicktime';
      case '.mkv':
        return 'x-matroska';
      default:
        return 'mp4';
    }
  }

  static String _inferImageSubtype(String ext) {
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'jpeg';
      case '.png':
        return 'png';
      case '.webp':
        return 'webp';
      default:
        return 'jpeg';
    }
  }

  static String _buildSafeFilename({required String prefix, required String ext}) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    var base = '${prefix}_$ts'.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    const maxLen = 100;
    final remain = maxLen - ext.length;
    if (base.length > remain) base = base.substring(0, remain);
    return '$base$ext';
  }

  Future<String> _makeThumbnail(String videoPath) async {
    final dir = await getTemporaryDirectory();
    final out = p.join(dir.path, 'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg');
    final cmd = '-y -ss 00:00:01 -i "${videoPath.replaceAll('"', '\\"')}" -frames:v 1 "$out"';
    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();
    if (!ReturnCode.isSuccess(rc)) {
      final log = await session.getAllLogsAsString();
      throw Exception('Thumbnail failed: $log');
    }
    if (!await File(out).exists()) throw Exception('Thumb not found');
    return out;
  }

  Future<void> _onTestingPost() async {
    if (_isExporting.value || _isUploading.value) return;
    _isUploading.value = true;
    try {
      final token = await _sessionManager.getAccessToken();
      if (token == null || token.isEmpty) {
        _snack('You need to log in first (no token found).', bg: Colors.redAccent);
        return;
      }
      // Same export as Save/Share — single Code-2-style, no second pass
      final normalized = await _exportMaliSafe();
      if (normalized == null || !mounted) return;

      final thumbPath = await _makeThumbnail(normalized);

      final vidExt = _sanitizeExt(p.extension(normalized), fallback: '.mp4');
      final thumbExt = _sanitizeExt(p.extension(thumbPath), fallback: '.jpg');
      final videoFilename = _buildSafeFilename(prefix: 'media', ext: vidExt);
      final thumbFilename = _buildSafeFilename(prefix: 'thumb', ext: thumbExt);

      final dio = Dio(BaseOptions(
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(minutes: 5),
      ));

      final form = FormData.fromMap({
        'media_type': 'video',
        'title': 'Baby Doll',
        'caption': 'Testing Post',
        'media_file': await MultipartFile.fromFile(
          normalized,
          filename: videoFilename,
          contentType: MediaType('video', _inferVideoSubtype(vidExt)),
        ),
        'thumbnail': await MultipartFile.fromFile(
          thumbPath,
          filename: thumbFilename,
          contentType: MediaType('image', _inferImageSubtype(thumbExt)),
        ),
        'privacy': 'Public',
      });

      final resp = await dio.post(_postsUrl, data: form);
      if (!mounted) return;
      _snack('Testing POST success (status ${resp.statusCode})', bg: Colors.green);
    } catch (e, st) {
      debugPrint('Testing POST error: $e\n$st');
      if (mounted) _snack('Testing POST failed: $e', bg: Colors.redAccent);
    } finally {
      _isUploading.value = false;
    }
  }

  /// Save: same Mali-safe export as Share & Testing → then upload to app API.
  Future<void> _onSave() async {
    final path = await _exportMaliSafe();
    if (path != null) await _upload(path);
  }

  /// Share: same Mali-safe export as Save & Testing → then open share sheet.
  Future<void> _onShare() async {
    final path = await _exportMaliSafe();
    if (path == null || !mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ShareScreen(
        mediaFile: path,
        mediaType: 'video',
        title: widget.title,
        caption: widget.title,
      ),
    );
  }

  Future<String> _formatDuration(String path) async {
    Duration d;
    if (_useNative) {
      final nativeDur = await _nativeController?.getDuration();
      if (nativeDur != null && nativeDur.inMilliseconds > 0) {
        d = nativeDur;
      } else {
        d = await FFmpegExporter.getMediaDuration(path);
      }
    } else {
      d = _playerController!.value.duration;
    }
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _upload(String path) async {
    if (_isUploading.value) return;
    _isUploading.value = true;
    _uploadProgress.value = 0;

    String? thumbPath;
    try {
      final file = File(path);
      if (!await file.exists()) throw Exception('File not found');
      final duration = await _formatDuration(path);

      // Generate thumbnail from exported video (first frame) for save API
      try {
        final tempDir = await getTemporaryDirectory();
        final thumb = await VideoThumbnail.thumbnailFile(
          video: path,
          thumbnailPath: tempDir.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 512,
          quality: 85,
          timeMs: 0,
        );
        if (thumb != null && await File(thumb).exists()) thumbPath = thumb;
      } catch (_) {
        // Continue without thumbnail if generation fails
      }

      await _api.saveDownloadedVideo(
        title: widget.title,
        filePath: path,
        duration: duration,
        thumbnailPath: thumbPath,
        onSendProgress: (sent, total) {
          final p = total == 0 ? 0.0 : (sent / total).clamp(0, 1).toDouble();
          _uploadProgress.value = p;
        },
      );

      _snack('Uploaded', bg: Colors.green);
      if (mounted) context.push('/home', extra: {'filePath': path});
    } catch (e) {
      final tooLarge = e.toString().contains('Request Entity Too Large');
      _snack(tooLarge ? 'Video too large for server' : 'Upload failed: $e',
          bg: Colors.redAccent);
    } finally {
      if (thumbPath != null) {
        try {
          await File(thumbPath).delete();
        } catch (_) {}
      }
      _isUploading.value = false;
    }
  }

  double get _videoAspectRatio {
    if (_useNative) return _videoAspectRatioValue;
    return _playerController?.value.aspectRatio.clamp(0.1, 10.0) ?? _videoAspectRatioValue;
  }

  bool get _showPauseOverlay {
    if (_useNative) return !_isPlaying;
    return !(_playerController?.value.isPlaying ?? false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_inited) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _accent)),
      );
    }

    final theme = Theme.of(context).copyWith(
      scaffoldBackgroundColor: _bg,
      colorScheme: const ColorScheme.dark(
        primary: _accent,
        secondary: _accent2,
        surface: _card,
        background: _bg,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _bg,
        foregroundColor: _text,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Color(0xFFF0F3F8),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    final videoAR = _videoAspectRatio;
    final media = MediaQuery.of(context).size;
    final maxW = media.width - 24.0;
    final maxH = media.height * 0.58;
    double w = maxW;
    double h = w / videoAR;
    if (h > maxH) {
      h = maxH;
      w = h * videoAR;
    }

    return Theme(
      data: theme,
      child: ScaffoldMessenger(
        key: _messengerKey,
        child: Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            title: Text(widget.title, overflow: TextOverflow.ellipsis),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: Container(
                          width: w,
                          height: h,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: _neonGreenGlow,
                                blurRadius: 20,
                                spreadRadius: 0,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              AspectRatio(
                                aspectRatio: videoAR,
                                child: _useNative
                                    ? NativeVideoView(
                                        controller: _nativeController!,
                                        filePath: widget.videoPath,
                                        autoPlay: false,
                                        loop: false,
                                      )
                                    : VideoPlayer(_playerController!),
                              ),
                              if (_showPauseOverlay)
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.45),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.play_arrow,
                                      size: 36, color: Colors.white),
                                ),
                              // Full-size tap target on top so play/pause works (native view no longer consumes touches)
                              Positioned.fill(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _togglePlay,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _TrimBarDesign(
                      videoPath: widget.videoPath,
                      durationSec: _durationSec,
                      trimStartSec: _trimStartSec,
                      trimEndSec: _trimEndSec,
                      currentPositionSec: _currentPositionSec,
                      onTrimChanged: (s, e) {
                        setState(() {
                          _trimStartSec = s;
                          _trimEndSec = e;
                        });
                        final seekMs = (s * 1000).round();
                        if (_useNative) {
                          _nativeController?.seekTo(Duration(milliseconds: seekMs));
                        } else {
                          _playerController?.seekTo(Duration(milliseconds: seekMs));
                        }
                      },
                      fmt: _fmt,
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: _PrimaryButton(
                              icon: Icons.save_alt,
                              label: 'SAVE',
                              isPrimary: true,
                              enabled: !_isUploading.value && !_isExporting.value,
                              onPressed: _onSave,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _PrimaryButton(
                              icon: Icons.share,
                              label: 'SHARE',
                              isPrimary: false,
                              enabled: !_isUploading.value && !_isExporting.value,
                              onPressed: _onShare,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_isUploading.value || _isExporting.value) ? null : _onTestingPost,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: _accent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ).copyWith(
                            overlayColor: MaterialStateProperty.all(Colors.white.withOpacity(0.15)),
                          ),
                          child: const Text('Testing', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _overlayProgress(),
              ValueListenableBuilder<bool>(
                valueListenable: _isExporting,
                builder: (_, exporting, __) {
                  if (!exporting) return const SizedBox.shrink();
                  return Positioned.fill(
                    child: ColoredBox(
                      color: _overlay,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: _accent),
                            SizedBox(height: 12),
                            Text('Preparing video…', style: TextStyle(color: _text)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overlayProgress() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isUploading,
      builder: (_, uploading, __) {
        final visible = uploading;
        return AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: visible
              ? Container(
                  color: _overlay,
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    minimum: const EdgeInsets.all(16),
                    child: _ProgressPanel(
                      uploading: uploading,
                      progressListenable: _uploadProgress,
                      pulseCtrl: _pulseCtrl,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}

/* ===================== UI HELPERS ===================== */

class _PrimaryButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final bool isPrimary;
  final bool enabled;

  const _PrimaryButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.isPrimary = true,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isPrimary ? _accent : _accent2;
    final glow = isPrimary ? _neonGreenGlow : _neonBlueGlow;
    return ElevatedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, color: Colors.white, size: 20),
      label: Text(label,
          style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        disabledBackgroundColor: _card,
        disabledForegroundColor: _muted,
        elevation: 0,
        shadowColor: glow,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ).copyWith(
        overlayColor: MaterialStateProperty.all(Colors.white.withOpacity(0.15)),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final String value;

  const _TimeChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _cardElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _accent.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _muted, fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _text, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  final bool uploading;
  final ValueListenable<double> progressListenable;
  final AnimationController pulseCtrl;

  const _ProgressPanel({
    required this.uploading,
    required this.progressListenable,
    required this.pulseCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseIcon(ctrl: pulseCtrl),
          const SizedBox(height: 10),
          const Text('Uploading video…',
              style: TextStyle(color: _text, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ValueListenableBuilder<double>(
            valueListenable: progressListenable,
            builder: (_, p, __) => _DeterminateBar(progress: p.clamp(0, 1)),
          ),
          const SizedBox(height: 10),
          if (uploading)
            ValueListenableBuilder<double>(
              valueListenable: progressListenable,
              builder: (_, p, __) => Text(
                'Uploading ${(p * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: _muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _PulseIcon extends StatelessWidget {
  final AnimationController ctrl;
  const _PulseIcon({required this.ctrl});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      width: 42,
      child: AnimatedBuilder(
        animation: ctrl,
        builder: (_, __) {
          final scale = 0.9 + ctrl.value * 0.1;
          final opacity = 0.6 + ctrl.value * 0.4;
          return Transform.scale(
            scale: scale,
            child: Container(
              decoration: BoxDecoration(
                color: _accent.withOpacity(opacity),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _accent.withOpacity(0.25 + ctrl.value * 0.25),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.movie, color: _bg),
            ),
          );
        },
      ),
    );
  }
}

class _DeterminateBar extends StatelessWidget {
  final double progress;
  const _DeterminateBar({required this.progress});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 10,
        color: const Color(0xFF222937),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: progress,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_accent2, _accent]),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }
}

/// Trim bar design from reference: thumbnail strip, draggable left/right handles,
/// time markers, Start/End, Clip length.
class _TrimBarDesign extends StatefulWidget {
  final String videoPath;
  final double durationSec;
  final double trimStartSec;
  final double trimEndSec;
  final ValueListenable<double> currentPositionSec;
  final void Function(double start, double end) onTrimChanged;
  final String Function(double s) fmt;

  const _TrimBarDesign({
    required this.videoPath,
    required this.durationSec,
    required this.trimStartSec,
    required this.trimEndSec,
    required this.currentPositionSec,
    required this.onTrimChanged,
    required this.fmt,
  });

  @override
  State<_TrimBarDesign> createState() => _TrimBarDesignState();
}

class _TrimBarDesignState extends State<_TrimBarDesign> {
  static const int _thumbCount = 16;
  List<Uint8List?>? _thumbnails;
  bool _draggingLeft = false;
  bool _draggingRight = false;
  double _dragStartValue = 0.0;

  @override
  void initState() {
    super.initState();
    _loadThumbnails();
  }

  Future<void> _loadThumbnails() async {
    if (widget.durationSec <= 0) return;
    final list = <Uint8List?>[];
    for (int i = 0; i < _thumbCount; i++) {
      final timeMs = (widget.durationSec * 1000 * i / (_thumbCount - 1)).round();
      try {
        final data = await VideoThumbnail.thumbnailData(
          video: widget.videoPath,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 120,
          quality: 40,
          timeMs: timeMs.clamp(0, (widget.durationSec * 1000).round()),
        );
        list.add(data);
      } catch (_) {
        list.add(null);
      }
    }
    if (mounted) setState(() => _thumbnails = list);
  }

  @override
  void didUpdateWidget(covariant _TrimBarDesign oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.durationSec != widget.durationSec || oldWidget.videoPath != widget.videoPath) {
      _loadThumbnails();
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.durationSec <= 0 ? 1.0 : widget.durationSec;
    // During drag use local value so only this widget rebuilds (smooth); otherwise use widget values
    final start = _draggingLeft
        ? _dragStartValue.clamp(0.0, widget.trimEndSec.clamp(0.0, duration) - 0.25)
        : widget.trimStartSec.clamp(0.0, duration);
    final end = _draggingRight
        ? _dragStartValue.clamp(widget.trimStartSec.clamp(0.0, duration) + 0.25, duration)
        : widget.trimEndSec.clamp(0.0, duration);
    final clipLen = (end - start).clamp(0.0, duration);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardElevated, width: 1),
        boxShadow: [
          BoxShadow(
            color: _neonGreenGlow,
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Trim',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: _accent,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final stripWidth = constraints.maxWidth;
              final stripHeight = 56.0;
              final leftPx = (start / duration * stripWidth).clamp(0.0, stripWidth);
              final rightPx = (end / duration * stripWidth).clamp(0.0, stripWidth);
              const handleWidth = 14.0; // Wider handles so they are visible and easy to drag

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onPanStart: (d) {
                      final x = d.localPosition.dx;
                      final nearLeft = (x - leftPx).abs() < (x - rightPx).abs();
                      setState(() {
                        if (nearLeft) {
                          _draggingLeft = true;
                          _dragStartValue = start;
                        } else {
                          _draggingRight = true;
                          _dragStartValue = end;
                        }
                      });
                    },
                    onPanUpdate: (d) {
                      if (!_draggingLeft && !_draggingRight) return;
                      final deltaSec = (d.delta.dx / stripWidth) * duration;
                      setState(() {
                        _dragStartValue += deltaSec;
                        if (_draggingLeft) {
                          _dragStartValue = _dragStartValue.clamp(0.0, widget.trimEndSec.clamp(0.0, duration) - 0.25);
                        } else {
                          _dragStartValue = _dragStartValue.clamp(widget.trimStartSec.clamp(0.0, duration) + 0.25, duration);
                        }
                      });
                    },
                    onPanEnd: (_) {
                      final newStart = _draggingLeft
                          ? _dragStartValue.clamp(0.0, widget.trimEndSec - 0.25)
                          : widget.trimStartSec;
                      final newEnd = _draggingRight
                          ? _dragStartValue.clamp(widget.trimStartSec + 0.25, duration)
                          : widget.trimEndSec;
                      widget.onTrimChanged(newStart, newEnd);
                      setState(() {
                        _draggingLeft = false;
                        _draggingRight = false;
                      });
                    },
                    child: SizedBox(
                      height: stripHeight,
                      width: stripWidth,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Row(
                              children: _buildThumbStrip(stripWidth, stripHeight),
                            ),
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: leftPx,
                              child: Container(color: Colors.black54),
                            ),
                            Positioned(
                              left: rightPx,
                              top: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(color: Colors.black54),
                            ),
                            // Current playhead: follows playback, or follows handle during drag for smooth feel
                            ValueListenableBuilder<double>(
                              valueListenable: widget.currentPositionSec,
                              builder: (_, posSecFromPlayer, __) {
                                final dur = widget.durationSec <= 0 ? 1.0 : widget.durationSec;
                                // While dragging start/end, show playhead at drag position so it moves with the handle
                                final posSec = (_draggingLeft || _draggingRight)
                                    ? _dragStartValue
                                    : posSecFromPlayer;
                                final posPx = (posSec.clamp(0.0, dur) / dur * stripWidth).clamp(0.0, stripWidth);
                                return Positioned(
                                  left: posPx - 2,
                                  top: 0,
                                  bottom: 0,
                                  width: 4,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _neonBlueGlow,
                                          blurRadius: 6,
                                          spreadRadius: 0,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Start trim handle: visible bar with white border and neon fill
                            Positioned(
                              left: leftPx - handleWidth / 2,
                              top: 0,
                              bottom: 0,
                              width: handleWidth,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _accent,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _neonGreenGlow,
                                      blurRadius: 8,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // End trim handle: same visible style
                            Positioned(
                              left: rightPx - handleWidth / 2,
                              top: 0,
                              bottom: 0,
                              width: handleWidth,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _accent,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _neonGreenGlow,
                                      blurRadius: 8,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _timeMarkers(duration, stripWidth),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TimeChip(label: 'Start', value: widget.fmt(start)),
                const SizedBox(width: 24),
                _TimeChip(label: 'End', value: widget.fmt(end)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Clip length: ${widget.fmt(clipLen)} / ${widget.fmt(duration)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _muted,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildThumbStrip(double stripWidth, double stripHeight) {
    final count = _thumbnails?.length ?? _thumbCount;
    final cellWidth = stripWidth / count;
    final widgets = <Widget>[];
    for (int i = 0; i < count; i++) {
      final bytes = _thumbnails != null && i < _thumbnails!.length ? _thumbnails![i] : null;
      widgets.add(
        SizedBox(
          width: cellWidth,
          height: stripHeight,
          child: bytes != null
              ? Image.memory(bytes, fit: BoxFit.cover)
              : Container(color: _card),
        ),
      );
    }
    return widgets;
  }

  List<Widget> _timeMarkers(double duration, double stripWidth) {
    final markers = <Widget>[];
    final step = duration <= 8 ? 2.0 : (duration <= 20 ? 4.0 : (duration / 5).ceilToDouble());
    for (double t = 0; t <= duration + 0.01; t += step) {
      markers.add(
        Text(
          '${t.toStringAsFixed(1)}s',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _muted, fontSize: 11),
        ),
      );
    }
    return markers;
  }
}

