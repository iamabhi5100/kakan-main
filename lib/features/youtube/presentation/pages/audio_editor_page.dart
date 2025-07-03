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
  bool _isPlaying = false;
  bool _isExporting = false;
  final YoutubeApiService _apiService = di.sl<YoutubeApiService>();
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    print('AudioEditorPage: Initializing for ${widget.audioPath}');
    _player = AudioPlayer();
    _waveformController = PlayerController();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      await _player.setFilePath(widget.audioPath);
      final duration = await _player.load();
      setState(() {
        _audioDuration = duration ?? Duration.zero;
      });
      await _waveformController.preparePlayer(
        path: widget.audioPath,
        shouldExtractWaveform: true,
      );
      print('AudioEditorPage: Audio initialized, duration: $_audioDuration');
    } catch (e) {
      print('AudioEditorPage: Error loading audio: $e');
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
    print('AudioEditorPage: Disposed AudioPlayer and PlayerController');
    super.dispose();
  }

  double get _trimStartSeconds =>
      _audioDuration.inSeconds > 0 ? _audioDuration.inSeconds * _trimStartPercent : 0.0;
  double get _trimEndSeconds =>
      _audioDuration.inSeconds > 0 ? _audioDuration.inSeconds * _trimEndPercent : 0.0;

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

    print('AudioEditorPage: FFmpeg export command: $command');
    try {
      final sess = await FFmpegKit.execute(command);
      final returnCode = await sess.getReturnCode();
      if (!ReturnCode.isSuccess(returnCode)) {
        final logs = await sess.getAllLogs();
        final errorMessage = logs.map((log) => log.getMessage()).join('\n');
        print('AudioEditorPage: Export failed: $errorMessage');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to export audio')),
          );
        }
        setState(() => _isExporting = false);
        return;
      }
      print('AudioEditorPage: Audio exported: $outputPath');

      // Validate output file
      final file = File(outputPath);
      if (!await file.exists() || await file.length() < 1024) {
        print('AudioEditorPage: Output file invalid or too small: $outputPath');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Exported audio file is invalid')),
          );
        }
        setState(() => _isExporting = false);
        return;
      }

      // Upload with retries
      for (int attempt = 0; attempt < _maxRetries; attempt++) {
        try {
          final fileSize = await file.length();
          print('AudioEditorPage: Uploading file: $outputPath, size: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB');
          await _apiService.saveDownloadedVideo(
            title: widget.title,
            filePath: outputPath,
            duration: _formatDuration(Duration(seconds: duration)),
            mediaType: 'audio', // Explicitly set media_type to audio
            onSendProgress: (sent, total) {
              final progress = (sent / total).clamp(0.0, 1.0);
              print('AudioEditorPage: Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
            },
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Audio uploaded successfully'),
                backgroundColor: Colors.green,
              ),
            );
            context.push('/home', extra: {'filePath': outputPath});
          }
          break;
        } catch (e) {
          print('AudioEditorPage: Failed to upload audio (attempt ${attempt + 1}): $e');
          if (attempt < _maxRetries - 1) {
            await Future.delayed(_retryDelay * (attempt + 1));
            continue;
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload audio: $e'),
                backgroundColor: Colors.redAccent,
                action: SnackBarAction(
                  label: 'Retry',
                  onPressed: _exportAudio,
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('AudioEditorPage: Export failed: $e');
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
    setState(() {}); // Force UI refresh to ensure both handles render
    final width = MediaQuery.of(context).size.width - 32;
    final handleWidth = 24.0; // Increased for better visibility

    return Container(
      height: 90,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Stack(
        children: [
          // Waveform as background
          AudioFileWaveforms(
            size: Size(width, 90),
            playerController: _waveformController,
            waveformType: WaveformType.fitWidth,
            playerWaveStyle: PlayerWaveStyle(
              fixedWaveColor: Colors.blueAccent,
              liveWaveColor: Colors.lightBlue,
              waveThickness: 2,
              spacing: 4,
              scaleFactor: 50,
            ),
            continuousWaveform: false,
          ),
          // Selection overlay (the trimmed area)
          Positioned(
            left: width * _trimStartPercent,
            top: 0,
            child: Container(
              width: width * (_trimEndPercent - _trimStartPercent),
              height: 90,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${_formatDuration(Duration(seconds: _trimStartSeconds.floor()))} - ${_formatDuration(Duration(seconds: _trimEndSeconds.floor()))}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
          // Left handle (start trim)
          Positioned(
            left: width * _trimStartPercent - handleWidth / 2,
            top: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) {
                print('AudioEditorPage: Dragging start handle, delta: ${details.primaryDelta}');
                setState(() {
                  _trimStartPercent += details.primaryDelta! / width;
                  _trimStartPercent = _trimStartPercent.clamp(0.0, _trimEndPercent - 0.01);
                  print('AudioEditorPage: Start trim set to $_trimStartPercent');
                });
              },
              child: Container(
                width: handleWidth,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                  child: Icon(Icons.drag_handle, color: Colors.white, size: 16),
                ),
              ),
            ),
          ),
          // Right handle (end trim)
          Positioned(
            left: width * _trimEndPercent - handleWidth / 2,
            top: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) {
                print('AudioEditorPage: Dragging end handle, delta: ${details.primaryDelta}');
                setState(() {
                  _trimEndPercent += details.primaryDelta! / width;
                  _trimEndPercent = _trimEndPercent.clamp(_trimStartPercent + 0.01, 1.0);
                  print('AudioEditorPage: End trim set to $_trimEndPercent');
                });
              },
              child: Container(
                width: handleWidth,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.redAccent, // Distinct color for end handle
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                  child: Icon(Icons.drag_handle, color: Colors.white, size: 16),
                ),
              ),
            ),
          ),
        ],
      ),
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
        title: const Text(
          'Trim',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
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
                            icon: Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 32,
                            ),
                            onPressed: () async {
                              if (_isPlaying) {
                                await _player.pause();
                              } else {
                                await _player.seek(Duration(seconds: _trimStartSeconds.floor()));
                                await _player.play();
                              }
                              setState(() => _isPlaying = !_isPlaying);
                            },
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '${_formatDuration(Duration(seconds: _trimStartSeconds.floor()))} / ${_formatDuration(_audioDuration)}',
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[800],
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Volume', style: TextStyle(color: Colors.white)),
                          ),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[800],
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Fade In', style: TextStyle(color: Colors.white)),
                          ),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[800],
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Fade Out', style: TextStyle(color: Colors.white)),
                          ),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[800],
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Auto Setting', style: TextStyle(color: Colors.white)),
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
