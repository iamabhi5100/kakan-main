import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:video_editor_2/domain/entities/file_format.dart';
import 'package:video_editor_2/video_editor.dart';
import 'package:go_router/go_router.dart';
import 'package:kakan/features/youtube/data/api_service.dart';
import 'package:kakan/injection_container.dart' as di;

class CropScreen extends StatefulWidget {
  final VideoEditorController controller;
  final String videoId;
  final String title;

  const CropScreen({
    super.key,
    required this.controller,
    required this.videoId,
    required this.title,
  });

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  final _exportingProgress = ValueNotifier<double>(0.0);
  final _isExporting = ValueNotifier<bool>(false);
  final _uploadProgress = ValueNotifier<double>(0.0);
  final _isUploading = ValueNotifier<bool>(false);
  final YoutubeApiService _apiService = di.sl<YoutubeApiService>();

  Future<String> _runFFmpegCommand(String command) async {
    return await compute((cmd) async {
      final sess = await FFmpegKit.execute(cmd);
      final rc = await sess.getReturnCode();
      if (!ReturnCode.isSuccess(rc)) {
        final logs = await sess.getAllLogs();
        throw ServerException(message: 'FFmpeg failed: ${logs.map((log) => log.getMessage()).join('\n')}');
      }
      return cmd;
    }, command);
  }

  @override
  void dispose() {
    _exportingProgress.dispose();
    _isExporting.dispose();
    _uploadProgress.dispose();
    _isUploading.dispose();
    super.dispose();
  }

  Future<String> _ioOutputPath(String filePath, FileFormat format) async {
    final tempPath = (await getTemporaryDirectory()).path;
    final name = path.basenameWithoutExtension(filePath);
    final epoch = DateTime.now().millisecondsSinceEpoch;
    return "$tempPath/${name}_$epoch.${format.extension}";
  }

  Future<void> _exportVideo() async {
    if (_isExporting.value || _isUploading.value) return;
    _isExporting.value = true;

    try {
      final inputPath = widget.controller.file.path;
      final outputPath = await _ioOutputPath(inputPath, VideoExportFormat.mp4);
      final config = widget.controller.createVideoFFmpegConfig();
      final execute = config.createExportCommand(
        inputPath: inputPath,
        outputPath: outputPath,
        outputFormat: VideoExportFormat.mp4,
        scale: 1.0,
        isFiltersEnabled: true,
      );

      debugPrint('CropScreen: run export video command: [$execute]');
      await _runFFmpegCommand(execute);
      debugPrint('CropScreen: Video exported to: $outputPath');
      await _uploadVideo(outputPath);
      if (mounted) _isExporting.value = false;
    } catch (e) {
      debugPrint('CropScreen: Error exporting video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting video: $e')),
        );
        _isExporting.value = false;
      }
    }
  }

  Future<void> _uploadVideo(String filePath) async {
    if (_isUploading.value) return;
    _isUploading.value = true;
    try {
      final file = File(filePath);
      final fileSize = await file.length();
      print('CropScreen: Uploading file: $filePath, size: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB');
      await _apiService.saveDownloadedVideo(
        title: widget.title,
        filePath: filePath,
        duration: widget.controller.videoDuration.toString().split('.').first.padLeft(8, "0"),
        onSendProgress: (sent, total) {
          final progress = (sent / total).clamp(0.0, 1.0);
          _uploadProgress.value = progress;
          print('CropScreen: Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.push('/video-post', extra: {'filePath': filePath});
        Navigator.pop(context); // Return to VideoEditorScreen
      }
    } catch (e) {
      debugPrint('CropScreen: Failed to upload video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('Request Entity Too Large')
                  ? 'Video file is too large. Try a smaller video or contact support.'
                  : 'Failed to upload video: $e',
            ),
            backgroundColor: Colors.redAccent,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _uploadVideo(filePath),
            ),
          ),
        );
      }
    } finally {
      if (mounted) _isUploading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.cancel, color: Colors.white),
                    tooltip: 'Cancel',
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _isExporting,
                    builder: (context, isExporting, child) {
                      return IconButton(
                        onPressed: isExporting || _isUploading.value ? null : _exportVideo,
                        icon: isExporting
                            ? const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              )
                            : const Icon(Icons.check, color: Colors.white),
                        tooltip: 'Apply crop and upload',
                      );
                    },
                  ),
                ],
              ),
              Expanded(
                child: CropGridViewer.edit(
                  controller: widget.controller,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
              ValueListenableBuilder<double>(
                valueListenable: _exportingProgress,
                builder: (context, progress, child) {
                  return _isExporting.value && progress > 0
                      ? Column(
                          children: [
                            const SizedBox(height: 8),
                            LinearProgressIndicator(value: progress),
                            const SizedBox(height: 8),
                            Text('Exporting: ${(progress * 100).toStringAsFixed(0)}%'),
                          ],
                        )
                      : const SizedBox.shrink();
                },
              ),
              ValueListenableBuilder<double>(
                valueListenable: _uploadProgress,
                builder: (context, progress, child) {
                  return _isUploading.value && progress > 0
                      ? Column(
                          children: [
                            const SizedBox(height: 8),
                            LinearProgressIndicator(value: progress),
                            const SizedBox(height: 8),
                            Text('Uploading: ${(progress * 100).toStringAsFixed(0)}%'),
                          ],
                        )
                      : const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}