import 'dart:io';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:flutter/material.dart';
import 'package:kakan/services/ffmpeg_exporter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

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

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  late final VideoPlayerController _controller;
  bool _busy = true;
  double _startMs = 0;
  double _endMs = 0;
  CropAspect? _crop = CropAspect.original;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        final total = _controller.value.duration.inMilliseconds.toDouble();
        _startMs = 0;
        _endMs = total > 0 ? total : 1;
        setState(() => _busy = false);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _fmt(double ms) {
    final d = Duration(milliseconds: ms.round());
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<void> _exportTrim() async {
    setState(() => _busy = true);
    try {
      final dir = await getTemporaryDirectory();
      final outPath = p.join(
        dir.path,
        '${p.basenameWithoutExtension(widget.videoPath)}_trim_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );

      final ss = (_startMs / 1000).toStringAsFixed(3);
      final dur = ((_endMs - _startMs) / 1000).toStringAsFixed(3);

      final cmd = [
        '-y','-hide_banner','-loglevel','info',
        '-hwaccel','none',
        '-ss', ss,
        '-i', widget.videoPath,
        '-t', dur,
        '-c', 'copy',
        '-movflags', '+faststart',
        outPath,
      ].join(' ');

      print('[VideoEditor] TRIM CMD: $cmd');

      final s = await FFmpegKit.execute(cmd);
      final rc = await s.getReturnCode();
      final logs = await s.getAllLogsAsString();
      print('[VideoEditor] TRIM RC=${rc?.getValue()}');
      if (!ReturnCode.isSuccess(rc)) {
        print('[VideoEditor] TRIM LOGS:\n$logs');
        throw Exception('Trim failed [${rc?.getValue()}]');
      }

      if (!mounted) return;
      Navigator.of(context).pop({
        'trimmedPath': outPath,
        'cropAspect': _crop,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _controller.value.isInitialized;
    final totalMs = ready
        ? _controller.value.duration.inMilliseconds.toDouble().clamp(1, double.infinity)
        : 1.0;

    final currentStart = _startMs.clamp(0, totalMs);
    final currentEnd = _endMs.clamp(currentStart, totalMs);
    final divisions = ((totalMs / 500).floor()).clamp(1, 2000);

    return Scaffold(
      appBar: AppBar(title: const Text('Video Editor')),
      body: _busy || !ready
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: Stack(
                    children: [
                      VideoPlayer(_controller),
                      Positioned.fill(
                        child: Center(
                          child: IconButton(
                            iconSize: 64,
                            color: Colors.white,
                            icon: Icon(_controller.value.isPlaying
                                ? Icons.pause_circle
                                : Icons.play_circle),
                            onPressed: () {
                              setState(() {
                                _controller.value.isPlaying
                                    ? _controller.pause()
                                    : _controller.play();
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      _aspectChip('Original', CropAspect.original),
                      _aspectChip('1:1', CropAspect.ratio1x1),
                      _aspectChip('9:16', CropAspect.ratio9x16),
                      _aspectChip('16:9', CropAspect.ratio16x9),
                      _aspectChip('4:5', CropAspect.ratio4x5),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text('Start: ${_fmt(currentStart.toDouble())}'),
                      const Spacer(),
                      Text('End: ${_fmt(currentEnd.toDouble())}'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: RangeSlider(
                    values: RangeValues(currentStart.toDouble(), currentEnd.toDouble()),
                    min: 0,
                    max: totalMs.toDouble(),
                    divisions: divisions,
                    labels: RangeLabels(_fmt(currentStart.toDouble()), _fmt(currentEnd.toDouble())),
                    onChanged: (rv) {
                      setState(() {
                        _startMs = rv.start.clamp(0, totalMs).toDouble();
                        _endMs = rv.end.clamp(_startMs, totalMs).toDouble();
                      });
                      _controller.seekTo(Duration(milliseconds: _startMs.toInt()));
                    },
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _exportTrim,
                      icon: const Icon(Icons.check),
                      label: const Text('Done'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _aspectChip(String label, CropAspect value) {
    final selected = _crop == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _crop = value),
    );
  }
}
