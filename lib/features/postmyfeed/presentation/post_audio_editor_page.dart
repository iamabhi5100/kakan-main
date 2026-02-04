import 'dart:async';
import 'dart:io';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class PostAudioEditorPage extends StatefulWidget {
  final String audioPath;
  final String? title;
  final String? mediaId;

  const PostAudioEditorPage({
    Key? key,
    required this.audioPath,
    this.title,
    this.mediaId,
  }) : super(key: key);

  @override
  State<PostAudioEditorPage> createState() => _PostAudioEditorPageState();
}

class _PostAudioEditorPageState extends State<PostAudioEditorPage> {
  late AudioPlayer _player;
  late PlayerController _waveformController;
  Duration _audioDuration = Duration.zero;
  double _trimStartPercent = 0.0;
  double _trimEndPercent = 1.0;
  double _currentPositionPercent = 0.0;
  bool _isPlaying = false;
  bool _isExporting = false;
  bool _isWaveformLoaded = false;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  late final TextEditingController _trimStartController;
  late final TextEditingController _trimEndController;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _waveformController = PlayerController();
    _trimStartController = TextEditingController();
    _trimEndController = TextEditingController();
    _initAudio();

    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
        if (state.processingState == ProcessingState.completed) {
          _player.seek(Duration(
              milliseconds:
                  (_trimStartPercent * _audioDuration.inMilliseconds).round()));
          setState(() {
            _currentPositionPercent = _trimStartPercent;
          });
        }
      }
    });

    _positionSubscription = _player.positionStream.listen((position) {
      if (mounted && _audioDuration.inMilliseconds > 0) {
        final currentMillis = position.inMilliseconds;
        final endMillis =
            (_trimEndPercent * _audioDuration.inMilliseconds).round();

        setState(() {
          _currentPositionPercent =
              (currentMillis / _audioDuration.inMilliseconds)
                  .clamp(_trimStartPercent, _trimEndPercent);
        });

        if (_isPlaying && currentMillis >= endMillis) {
          _player.pause();
          _player.seek(Duration(milliseconds: endMillis));
        }
      }
    });
  }

  Future<void> _initAudio() async {
    try {
      if (widget.audioPath.startsWith('http')) {
        await _player.setUrl(widget.audioPath);
      } else {
        await _player.setFilePath(widget.audioPath);
      }
      final duration = await _player.load();
      await _waveformController.preparePlayer(
        path: widget.audioPath,
        shouldExtractWaveform: true,
      );
      if (mounted) {
        setState(() {
          _audioDuration = duration ?? Duration.zero;
          _isWaveformLoaded = true;
          _updateTextControllers();
        });
      }
    } catch (e) {
      if (mounted) {
        _messengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Failed to load audio: $e')),
        );
        context.pop();
      }
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _player.dispose();
    _waveformController.dispose();
    _trimStartController.dispose();
    _trimEndController.dispose();
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

  Future<String?> _exportTrimmedAudio() async {
    if (_isExporting) return null;
    setState(() => _isExporting = true);

    final outputPath = await _ioOutputPath('mp3');
    final start = _trimStartSeconds;
    final duration =
        (_trimEndSeconds - _trimStartSeconds).clamp(0.1, double.infinity);
    final command =
        '-y -ss $start -t $duration -i "${widget.audioPath}" -c:a libmp3lame -q:a 2 "$outputPath"';

    try {
      final sess = await FFmpegKit.execute(command);
      final returnCode = await sess.getReturnCode();
      if (!ReturnCode.isSuccess(returnCode)) {
        throw Exception('FFmpeg failed to export audio.');
      }
      final file = File(outputPath);
      if (!await file.exists() || await file.length() < 1024) {
        throw Exception('Exported audio file is invalid.');
      }
      return outputPath;
    } catch (e) {
      if (mounted) {
        _messengerKey.currentState?.showSnackBar(
          SnackBar(
              content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _proceedToPost() async {
    final outputPath = await _exportTrimmedAudio();
    if (outputPath == null) return;

    if (mounted) {
      context.push(
        '/audio-post',
        extra: {
          'filePath': outputPath,
          'mediaId': widget.mediaId,
          'title': widget.title,
        },
      );
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  Duration? _parseDuration(String text) {
    try {
      final parts = text.split(':');
      if (parts.length != 2) return null;
      final minutes = int.parse(parts[0]);
      final seconds = int.parse(parts[1]);
      if (minutes < 0 || seconds < 0 || seconds >= 60) return null;
      return Duration(minutes: minutes, seconds: seconds);
    } catch (e) {
      return null;
    }
  }

  void _updateTextControllers() {
    final startText =
        _formatDuration(Duration(milliseconds: (_trimStartSeconds * 1000).round()));
    final endText =
        _formatDuration(Duration(milliseconds: (_trimEndSeconds * 1000).round()));

    if (_trimStartController.text != startText) {
      _trimStartController.text = startText;
    }
    if (_trimEndController.text != endText) {
      _trimEndController.text = endText;
    }
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
    return Scaffold(
      key: _messengerKey,
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Trim Audio'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isExporting ? null : _proceedToPost,
            tooltip: 'Confirm Trim',
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _isWaveformLoaded
              ? Column(
                  children: [
                    Text(
                      widget.title ?? 'Audio Track',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                              fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_formatDuration(Duration(milliseconds: (_currentPositionPercent * _audioDuration.inMilliseconds).round()))} / ${_formatDuration(_audioDuration)}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.grey[400]),
                    ),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white12,
                        border: Border.all(color: Colors.white38, width: 2),
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                        ),
                        iconSize: 50,
                        onPressed: _handlePlayPause,
                      ),
                    ),
                    const Spacer(),
                    _trimBar(context),
                    const Spacer(flex: 2),
                    if (_isExporting)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                  ],
                )
              : const Center(
                  child: CircularProgressIndicator(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _trimBar(BuildContext context) {
    const startColor = Colors.greenAccent;
    const endColor = Colors.redAccent;
    const playheadColor = Colors.yellowAccent;
    const liveWaveColor = Colors.cyanAccent;

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;

      return LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;

        return Column(
          children: [
            SizedBox(
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AudioFileWaveforms(
                      size: Size(width, 70),
                      playerController: _waveformController,
                      enableSeekGesture: false,
                      waveformType: WaveformType.fitWidth,
                      playerWaveStyle: const PlayerWaveStyle(
                        fixedWaveColor: Colors.grey,
                        liveWaveColor: liveWaveColor,
                        spacing: 4,
                        waveThickness: 2.5,
                        scaleFactor: 100,
                      ),
                    ),
                  ),
                  Positioned(
                    left: width * _trimStartPercent,
                    right: width * (1.0 - _trimEndPercent),
                    child: Container(
                      height: 70,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            startColor.withOpacity(0.3),
                            endColor.withOpacity(0.3)
                          ],
                        ),
                        border: Border.all(color: Colors.white54),
                      ),
                    ),
                  ),
                  Positioned(
                    left: (width * _currentPositionPercent)
                        .clamp(width * _trimStartPercent, width * _trimEndPercent),
                    child: Container(
                      width: 2.5,
                      height: 80,
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
                          final newPercent =
                              _trimStartPercent + details.delta.dx / width;
                          _trimStartPercent =
                              newPercent.clamp(0.0, _trimEndPercent - 0.05);
                        });
                        _updateTextControllers();
                      },
                      child: _buildTrimHandle(startColor, isLeft: true),
                    ),
                  ),
                  Positioned(
                    left: width * _trimEndPercent - 12,
                    child: GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          final newPercent =
                              _trimEndPercent + details.delta.dx / width;
                          _trimEndPercent =
                              newPercent.clamp(_trimStartPercent + 0.05, 1.0);
                        });
                        _updateTextControllers();
                      },
                      child: _buildTrimHandle(endColor, isLeft: false),
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
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'Start Trim Timer',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[600]!),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                    onSubmitted: (value) {
                      final newDuration = _parseDuration(value);
                      if (newDuration != null && _audioDuration.inMilliseconds > 0) {
                        setState(() {
                          final newPercent =
                              (newDuration.inMilliseconds / _audioDuration.inMilliseconds)
                                  .clamp(0.0, 1.0);
                          _trimStartPercent =
                              newPercent.clamp(0.0, _trimEndPercent - 0.05);
                        });
                      }
                      _updateTextControllers();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _trimEndController,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'End Trim Timer',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[600]!),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                    onSubmitted: (value) {
                      final newDuration = _parseDuration(value);
                      if (newDuration != null && _audioDuration.inMilliseconds > 0) {
                        setState(() {
                          final newPercent =
                              (newDuration.inMilliseconds / _audioDuration.inMilliseconds)
                                  .clamp(0.0, 1.0);
                          _trimEndPercent =
                              newPercent.clamp(_trimStartPercent + 0.05, 1.0);
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
    });
  }

  Widget _buildTrimHandle(Color color, {required bool isLeft}) {
    return Container(
      width: 24,
      height: 90,
      decoration: BoxDecoration(
        color: color,
        borderRadius: isLeft
            ? const BorderRadius.only(
                topLeft: Radius.circular(8), bottomLeft: Radius.circular(8))
            : const BorderRadius.only(
                topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 6,
            spreadRadius: 2,
          )
        ],
      ),
      child: Center(
        child: Icon(
          isLeft ? Icons.chevron_left : Icons.chevron_right,
          color: Colors.black,
        ),
      ),
    );
  }
}