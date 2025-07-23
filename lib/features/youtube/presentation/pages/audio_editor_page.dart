import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:go_router/go_router.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/features/youtube/data/api_service.dart';
import 'package:kakan/injection_container.dart' as di;

class AudioEditorPage extends StatefulWidget {
  final String audioPath;
  final String title;
  final String videoId;

  const AudioEditorPage({
    Key? key,
    required this.audioPath,
    required this.title,
    required this.videoId,
  }) : super(key: key);

  @override
  State<AudioEditorPage> createState() => _AudioEditorPageState();
}

class _AudioEditorPageState extends State<AudioEditorPage> {
  late AudioPlayer _player;
  late PlayerController _waveformController;
  Duration _audioDuration = Duration.zero;
  double _trimStartPercent = 0.0;
  double _trimEndPercent = 1.0;
  double _currentPositionPercent = 0.0;
  bool _isPlaying = false;
  bool _isExporting = false;
  bool _isWaveformLoaded = false;
  final YoutubeApiService _apiService = di.sl<YoutubeApiService>();
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _waveformController = PlayerController();
    _initAudio();
    _player.positionStream.listen((position) {
      if (mounted && _audioDuration.inSeconds > 0) {
        setState(() {
          _currentPositionPercent = position.inSeconds / _audioDuration.inSeconds;
          if (_currentPositionPercent > _trimEndPercent) {
            _player.pause();
            _player.seek(Duration(seconds: (_trimStartPercent * _audioDuration.inSeconds).floor()));
            _isPlaying = false;
          }
        });
      }
    });
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _isPlaying = false;
          _currentPositionPercent = _trimStartPercent;
          _player.seek(Duration(seconds: (_trimStartPercent * _audioDuration.inSeconds).floor()));
        });
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
      if (mounted) {
        setState(() {
          _audioDuration = duration ?? Duration.zero;
          _isWaveformLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load audio: $e')),
        );
        context.pop();
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _waveformController.dispose();
    super.dispose();
  }

  double get _trimStartSeconds =>
      _audioDuration.inSeconds > 0 ? _audioDuration.inSeconds * _trimStartPercent : 0.0;
  double get _trimEndSeconds =>
      _audioDuration.inSeconds > 0 ? _audioDuration.inSeconds * _trimEndPercent : 0.0;
  double get _currentPositionSeconds =>
      _audioDuration.inSeconds > 0 ? _audioDuration.inSeconds * _currentPositionPercent : 0.0;

  Future<String> _ioOutputPath(String extension) async {
    final tempPath = (await getTemporaryDirectory()).path;
    final name = p.basenameWithoutExtension(widget.audioPath);
    final epoch = DateTime.now().millisecondsSinceEpoch;
    return "$tempPath/${name}_$epoch.$extension";
  }

  Future<void> _exportAudio() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    final outputPath = await _ioOutputPath('mp3');
    final start = _trimStartSeconds.floor();
    final duration = (_trimEndSeconds - _trimStartSeconds).floor().clamp(1, _audioDuration.inSeconds);
    final command = '-y -ss $start -t $duration -i "${widget.audioPath}" -acodec libmp3lame "$outputPath"';

    try {
      final sess = await FFmpegKit.execute(command);
      final returnCode = await sess.getReturnCode();
      if (!ReturnCode.isSuccess(returnCode)) {
        final logs = await sess.getAllLogs();
        final errorMessage = logs.map((log) => log.getMessage()).join('\n');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to export audio')),
          );
        }
        setState(() => _isExporting = false);
        return;
      }

      final file = File(outputPath);
      if (!await file.exists() || await file.length() < 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Exported audio file is invalid')),
          );
        }
        setState(() => _isExporting = false);
        return;
      }

      for (int attempt = 0; attempt < _maxRetries; attempt++) {
        try {
          final fileSize = await file.length();
          await _apiService.saveDownloadedVideo(
            title: widget.title,
            filePath: outputPath,
            duration: _formatDuration(Duration(seconds: duration)),
            mediaType: 'audio',
            onSendProgress: (sent, total) {},
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Audio uploaded successfully'), backgroundColor: Colors.green),
            );
            context.push('/home', extra: {'filePath': outputPath});
          }
          break;
        } catch (e) {
          if (attempt < _maxRetries - 1) {
            await Future.delayed(_retryDelay * (attempt + 1));
            continue;
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload audio: $e'),
                backgroundColor: Colors.redAccent,
                action: SnackBarAction(label: 'Retry', onPressed: _exportAudio),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to export audio')),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(d.inHours)}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  Widget _trimBar(BuildContext context) {
    final width = MediaQuery.of(context).size.width - 32;
    final handleSize = 24.0;
    final waveColor = Colors.cyanAccent;
    final start = Duration(seconds: _trimStartSeconds.floor());
    final end = Duration(seconds: _trimEndSeconds.floor());
    final current = Duration(seconds: _currentPositionSeconds.floor());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _isWaveformLoaded
            ? Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                    ),
                    child: AudioFileWaveforms(
                      size: Size(width, 90),
                      playerController: _waveformController,
                      waveformType: WaveformType.fitWidth,
                      playerWaveStyle: PlayerWaveStyle(
                        fixedWaveColor: waveColor,
                        liveWaveColor: Colors.white,
                        waveThickness: 2,
                        spacing: 4,
                        scaleFactor: 50,
                      ),
                      continuousWaveform: false,
                    ),
                  ),
                  // Current Playback Position
                  Positioned(
                    left: width * _currentPositionPercent.clamp(_trimStartPercent, _trimEndPercent) - handleSize / 2,
                    child: GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          _currentPositionPercent += details.delta.dx / width;
                          _currentPositionPercent = _currentPositionPercent.clamp(_trimStartPercent, _trimEndPercent);
                          final newPosition = Duration(seconds: (_currentPositionPercent * _audioDuration.inSeconds).floor());
                          _player.seek(newPosition);
                        });
                      },
                      child: Container(
                        width: handleSize,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.yellowAccent,
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: const Icon(Icons.play_arrow, color: Colors.black, size: 16),
                      ),
                    ),
                  ),
                  // Start Trim Handle
                  Positioned(
                    left: width * _trimStartPercent - handleSize / 2,
                    child: GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          final newPercent = _trimStartPercent + details.delta.dx / width;
                          _trimStartPercent = newPercent.clamp(0.0, _trimEndPercent - 0.01);
                          if (_currentPositionPercent < _trimStartPercent) {
                            _currentPositionPercent = _trimStartPercent;
                            _player.seek(Duration(seconds: (_trimStartPercent * _audioDuration.inSeconds).floor()));
                          }
                        });
                      },
                      child: Container(
                        width: handleSize,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.greenAccent,
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: const Icon(Icons.arrow_left, color: Colors.black),
                      ),
                    ),
                  ),
                  // End Trim Handle
                  Positioned(
                    left: width * _trimEndPercent - handleSize / 2,
                    child: GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          final newPercent = _trimEndPercent + details.delta.dx / width;
                          _trimEndPercent = newPercent.clamp(_trimStartPercent + 0.01, 1.0);
                          if (_currentPositionPercent > _trimEndPercent) {
                            _currentPositionPercent = _trimEndPercent;
                            _player.seek(Duration(seconds: (_trimEndPercent * _audioDuration.inSeconds).floor()));
                          }
                        });
                      },
                      child: Container(
                        width: handleSize,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.redAccent,
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: const Icon(Icons.arrow_right, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              )
            : Container(
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                ),
                child: const Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatDuration(start), style: const TextStyle(color: Colors.white70, fontSize: 14)),
            Text(_formatDuration(end), style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Current: ${_formatDuration(current)}',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Trim', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      body: _audioDuration == Duration.zero
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _trimBar(context),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 32),
                            onPressed: () async {
                              if (_isPlaying) {
                                await _player.pause();
                                setState(() => _isPlaying = false);
                              } else {
                                if (_currentPositionPercent >= _trimEndPercent) {
                                  await _player.seek(Duration(seconds: (_trimStartPercent * _audioDuration.inSeconds).floor()));
                                  _currentPositionPercent = _trimStartPercent;
                                }
                                await _player.play();
                                setState(() => _isPlaying = true);
                              }
                            },
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '${_formatDuration(Duration(seconds: _currentPositionSeconds.floor()))} / ${_formatDuration(_audioDuration)}',
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _isExporting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : ElevatedButton(
                          onPressed: _exportAudio,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple[700],
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text(
                            'SAVE',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}