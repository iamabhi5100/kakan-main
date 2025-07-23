import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/features/youtube/data/api_service.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:video_editor_2/video_editor.dart';
import 'package:video_editor_2/ui/video_viewer.dart';
import 'package:video_editor_2/ui/cover/cover_selection.dart';
import 'package:cross_file/cross_file.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class VideoEditorScreen extends StatefulWidget {
  final String videoPath;
  final String videoId;
  final String title;

  const VideoEditorScreen({
    Key? key,
    required this.videoPath,
    required this.videoId,
    required this.title,
  }) : super(key: key);

  @override
  _VideoEditorScreenState createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  late VideoEditorController _controller;
  bool _isInitialized = false;
  final _exportingProgress = ValueNotifier<double>(0.0);
  final _isExporting = ValueNotifier<bool>(false);
  final _uploadProgress = ValueNotifier<double>(0.0);
  final _isUploading = ValueNotifier<bool>(false);
  final YoutubeApiService _apiService = di.sl<YoutubeApiService>();
  int cropGridViewerKey = 0; // For web refresh issue

  @override
  void initState() {
    super.initState();
    print('VideoEditorScreen: Initializing for ${widget.videoPath}');
    _controller = VideoEditorController.file(
      XFile(widget.videoPath),
      minDuration: const Duration(seconds: 1),
      maxDuration: const Duration(seconds: 300),
    );
    _controller.initialize(aspectRatio: 16 / 9).then((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        print('VideoEditorScreen: VideoEditorController initialized successfully');
      }
    }).catchError((error, stackTrace) {
      print('VideoEditorScreen: Failed to initialize VideoEditorController - $error, stackTrace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load video: $error')),
        );
        context.pop();
      }
    }, test: (e) => e is VideoMinDurationError);
  }

  Future<String> _runFFmpegCommand(String command) async {
    print('VideoEditorScreen: Executing FFmpeg command: $command');
    try {
      final sess = await FFmpegKit.execute(command);
      final rc = await sess.getReturnCode();
      if (!ReturnCode.isSuccess(rc)) {
        final logs = await sess.getAllLogs();
        final errorMessage = logs.map((log) => log.getMessage()).join('\n');
        print('VideoEditorScreen: FFmpeg failed: $errorMessage');
        throw ServerException(message: 'FFmpeg failed: $errorMessage');
      }
      print('VideoEditorScreen: FFmpeg command executed successfully');
      return command;
    } catch (e) {
      print('VideoEditorScreen: FFmpeg command failed: $e');
      throw ServerException(message: 'FFmpeg execution failed: $e');
    }
  }

  @override
  void dispose() {
    _exportingProgress.dispose();
    _isExporting.dispose();
    _uploadProgress.dispose();
    _isUploading.dispose();
    _controller.dispose();
    print('VideoEditorScreen: Disposed VideoEditorController');
    final file = File(widget.videoPath);
    if (file.existsSync()) {
      file.deleteSync();
      print('VideoEditorScreen: Deleted temporary file: ${widget.videoPath}');
    }
    super.dispose();
  }

  Future<String> _ioOutputPath(String filePath, {required String extension}) async {
    final tempPath = (await getTemporaryDirectory()).path;
    final name = path.basenameWithoutExtension(filePath);
    final epoch = DateTime.now().millisecondsSinceEpoch;
    return "$tempPath/${name}_$epoch.$extension";
  }

  Future<void> _exportVideo() async {
    if (!_controller.initialized || _isExporting.value || _isUploading.value) {
      print('VideoEditorScreen: Export aborted - Video not loaded or export/upload in progress');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video is not loaded or export/upload in progress')),
        );
      }
      return;
    }

    _isExporting.value = true;
    try {
      final config = _controller.createVideoFFmpegConfig();
      final inputPath = widget.videoPath;
      final outputPath = await _ioOutputPath(inputPath, extension: 'mp4');
      final execute = config.createExportCommand(
        inputPath: inputPath,
        outputPath: outputPath,
        outputFormat: VideoExportFormat.mp4,
        scale: 1.0,
        isFiltersEnabled: true,
      );

      print('VideoEditorScreen: Exporting video with command: $execute');
      await _runFFmpegCommand(execute);
      print('VideoEditorScreen: Video exported successfully to $outputPath');
      await _uploadVideo(outputPath);
    } catch (e, stackTrace) {
      print('VideoEditorScreen: Error exporting video - $e, stackTrace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting video: $e')),
        );
      }
    } finally {
      if (mounted) _isExporting.value = false;
    }
  }

  Future<void> _uploadVideo(String filePath) async {
    if (_isUploading.value) {
      print('VideoEditorScreen: Upload aborted - Already uploading');
      return;
    }
    _isUploading.value = true;
    try {
      final file = File(filePath);
      final fileSize = await file.length();
      print('VideoEditorScreen: Uploading file: $filePath, size: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB');
      await _apiService.saveDownloadedVideo(
        title: widget.title,
        filePath: filePath,
        duration: _controller.videoDuration.toString().split('.').first.padLeft(8, "0"),
        onSendProgress: (sent, total) {
          final progress = (sent / total).clamp(0.0, 1.0);
          _uploadProgress.value = progress;
          print('VideoEditorScreen: Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.push('/home', extra: {'filePath': filePath});
      }
    } catch (e) {
      print('VideoEditorScreen: Failed to upload video - $e');
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

  Future<void> _exportCover() async {
    if (!_controller.initialized || _isExporting.value || _isUploading.value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video is not loaded or export/upload in progress')),
      );
      return;
    }

    _isExporting.value = true;
    try {
      final config = _controller.createCoverFFmpegConfig();
      final outputPath = await _ioOutputPath(widget.videoPath, extension: 'jpg');
      final execute = config.createExportCommand(
        inputPath: widget.videoPath,
        outputPath: outputPath,
      );

      print('VideoEditorScreen: Exporting cover with command: $execute');
      await _runFFmpegCommand(execute);
      print('VideoEditorScreen: Cover exported successfully to $outputPath');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cover exported: $outputPath')),
        );
      }
    } catch (e, stackTrace) {
      print('VideoEditorScreen: Error exporting cover - $e, stackTrace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting cover: $e')),
        );
      }
    } finally {
      if (mounted) _isExporting.value = false;
    }
  }

  Widget _topNavBar() {
    return SafeArea(
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            Expanded(
              child: IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.exit_to_app),
                tooltip: 'Leave editor',
              ),
            ),
            const VerticalDivider(endIndent: 22, indent: 22),
            Expanded(
              child: IconButton(
                onPressed: () => _controller.rotate90Degrees(RotateDirection.left),
                icon: const Icon(Icons.rotate_left),
                tooltip: 'Rotate unclockwise',
              ),
            ),
            Expanded(
              child: IconButton(
                onPressed: () => _controller.rotate90Degrees(RotateDirection.right),
                icon: const Icon(Icons.rotate_right),
                tooltip: 'Rotate clockwise',
              ),
            ),
            Expanded(
              child: IconButton(
                onPressed: () {
                  _controller.cropAspectRatio(1.0); // Square crop
                  if (kIsWeb) {
                    setState(() => cropGridViewerKey++);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Square crop applied')),
                  );
                },
                icon: const Icon(Icons.crop),
                tooltip: 'Apply square crop',
              ),
            ),
            const VerticalDivider(endIndent: 22, indent: 22),
            Expanded(
              child: PopupMenuButton(
                tooltip: 'Open export menu',
                icon: const Icon(Icons.save),
                itemBuilder: (context) => [
                  // PopupMenuItem(
                  //   onTap: _exportCover,
                  //   child: const Text('Export cover'),
                  // ),
                  PopupMenuItem(
                    onTap: _exportVideo,
                    child: const Text('Export and upload video'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String formatter(Duration duration) => [
        duration.inMinutes.remainder(60).toString().padLeft(2, '0'),
        duration.inSeconds.remainder(60).toString().padLeft(2, '0')
      ].join(":");

  List<Widget> _trimSlider() {
    return [
      AnimatedBuilder(
        animation: Listenable.merge([
          _controller,
          _controller.video,
        ]),
        builder: (_, __) {
          final duration = _controller.videoDuration.inSeconds;
          final pos = _controller.trimPosition * duration;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Row(children: [
              if (pos.isFinite) Text(formatter(Duration(seconds: pos.toInt()))),
              const Expanded(child: SizedBox()),
              AnimatedOpacity(
                opacity: _controller.isTrimming ? 1.0 : 0.0,
                duration: const Duration(seconds: 1),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(formatter(_controller.startTrim)),
                  const SizedBox(width: 10),
                  Text(formatter(_controller.endTrim)),
                ]),
              ),
            ]),
          );
        },
      ),
      Container(
        width: MediaQuery.of(context).size.width,
        margin: const EdgeInsets.symmetric(vertical: 15),
        child: TrimSlider(
          controller: _controller,
          height: 60,
          horizontalMargin: 15,
          child: TrimTimeline(
            controller: _controller,
            padding: const EdgeInsets.only(top: 10),
          ),
        ),
      ),
    ];
  }

  Widget _coverSelection() {
    return SingleChildScrollView(
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(15),
          child: CoverSelection(
            controller: _controller,
            size: 70,
            quantity: 8,
            selectedCoverBuilder: (cover, size) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  cover,
                  Icon(
                    Icons.check_circle,
                    color: const CoverSelectionStyle().selectedBorderColor,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: _controller.initialized
            ? SafeArea(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        _topNavBar(),
                        Expanded(
                          child: DefaultTabController(
                            length: 2,
                            child: Column(
                              children: [
                                Expanded(
                                  child: TabBarView(
                                    physics: const NeverScrollableScrollPhysics(),
                                    children: [
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          CropGridViewer.preview(
                                            key: ValueKey(cropGridViewerKey),
                                            controller: _controller,
                                          ),
                                          AnimatedBuilder(
                                            animation: _controller.video,
                                            builder: (_, __) => AnimatedOpacity(
                                              opacity: !_controller.isPlaying ? 1.0 : 0.0,
                                              duration: const Duration(seconds: 1),
                                              child: GestureDetector(
                                                onTap: _controller.video.play,
                                                child: Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: const BoxDecoration(
                                                    color: Colors.white,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.play_arrow,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      CoverViewer(controller: _controller),
                                    ],
                                  ),
                                ),
                                Container(
                                  height: 200,
                                  margin: const EdgeInsets.only(top: 10),
                                  child: Column(
                                    children: [
                                      TabBar(
                                        tabs: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: const [
                                              Padding(
                                                padding: EdgeInsets.all(5),
                                                child: Icon(Icons.content_cut),
                                              ),
                                              Text('Trim'),
                                            ],
                                          ),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: const [
                                              Padding(
                                                padding: EdgeInsets.all(5),
                                                child: Icon(Icons.image),
                                              ),
                                              Text('Cover'),
                                            ],
                                          ),
                                        ],
                                        labelColor: isDark ? Colors.white : Colors.black,
                                        unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
                                        indicatorColor: isDark ? Colors.cyanAccent : Colors.blue[300],
                                      ),
                                      Expanded(
                                        child: TabBarView(
                                          physics: const NeverScrollableScrollPhysics(),
                                          children: [
                                            Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: _trimSlider(),
                                            ),
                                            _coverSelection(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ValueListenableBuilder(
                                  valueListenable: _isExporting,
                                  builder: (_, bool export, __) => AnimatedOpacity(
                                    opacity: export ? 1.0 : 0.0,
                                    duration: const Duration(seconds: 1),
                                    child: AlertDialog(
                                      title: ValueListenableBuilder(
                                        valueListenable: _exportingProgress,
                                        builder: (_, double value, __) => Text(
                                          "Exporting ${(value * 100).ceil()}%",
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                ValueListenableBuilder(
                                  valueListenable: _isUploading,
                                  builder: (_, bool uploading, __) => AnimatedOpacity(
                                    opacity: uploading ? 1.0 : 0.0,
                                    duration: const Duration(seconds: 1),
                                    child: AlertDialog(
                                      title: ValueListenableBuilder(
                                        valueListenable: _uploadProgress,
                                        builder: (_, double value, __) => Text(
                                          "Uploading ${(value * 100).ceil()}%",
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}