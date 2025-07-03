// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'dart:io';
// import 'package:cross_file/cross_file.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:video_editor_2/video_editor.dart';
// import 'package:video_player/video_player.dart';
// import 'package:path/path.dart' as path;

// class VideoEditScreen extends StatefulWidget {
//   final String filePath;

//   const VideoEditScreen({Key? key, required this.filePath}) : super(key: key);

//   @override
//   State<VideoEditScreen> createState() => _VideoEditScreenState();
// }

// class _VideoEditScreenState extends State<VideoEditScreen> {
//   late VideoEditorController _controller;
//   final _exportingProgress = ValueNotifier<double>(0.0);
//   final _isExporting = ValueNotifier<bool>(false);
//   bool _isInitialized = false;
//   String? _outputPath;
//   final double _trimHeight = 60;
//   int cropGridViewerKey = 0;

//   @override
//   void initState() {
//     super.initState();
//     final xFile = XFile(widget.filePath);
//     _controller = VideoEditorController.file(
//       xFile,
//       minDuration: const Duration(seconds: 1),
//       maxDuration: const Duration(minutes: 10),
//     );
//     _controller
//         .initialize(aspectRatio: 9 / 16)
//         .then((_) {
//           if (mounted) {
//             setState(() {
//               _isInitialized = true;
//             });
//           }
//         })
//         .catchError((error) {
//           if (mounted) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(content: Text('Error initializing video: $error')),
//             );
//           }
//         });
//   }

//   @override
//   void dispose() {
//     _exportingProgress.dispose();
//     _isExporting.dispose();
//     _controller.dispose();
//     super.dispose();
//   }

//   Future<String> _ioOutputPath(String filePath, String extension) async {
//     final dir = await getExternalStorageDirectory();
//     final name = path.basenameWithoutExtension(filePath);
//     final epoch = DateTime.now().millisecondsSinceEpoch;
//     return "${dir!.path}/${name}_$epoch.$extension";
//   }

//   Future<void> _exportVideo() async {
//     _isExporting.value = true;
//     try {
//       final outputPath = await _ioOutputPath(widget.filePath, 'mp4');
//       final config = _controller.createVideoFFmpegConfig();
//       final command = config.createExportCommand(
//         inputPath: widget.filePath,
//         outputPath: outputPath,
//         outputFormat: VideoExportFormat.mp4,
//       );

//       // Placeholder: fvp doesn't support FFmpeg commands directly
//       // Option 1: Use a different FFmpeg package or fork ffmpeg_kit_flutter
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Exporting video not yet implemented with fvp'),
//         ),
//       );
//       _isExporting.value = false;

//       // Uncomment and adapt if using a forked ffmpeg_kit_flutter (see below)
//       /*
//       await FFmpegKit.executeAsync(
//         command,
//         (session) async {
//           _isExporting.value = false;
//           final returnCode = await session.getReturnCode();
//           if (returnCode?.isValueSuccess() == true) {
//             setState(() {
//               _outputPath = outputPath;
//             });
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(content: Text('Video exported to: $_outputPath')),
//             );
//           } else {
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('Failed to export video')),
//             );
//           }
//         },
//         null,
//         (stats) {
//           final duration = _controller.trimmedDuration.inMilliseconds;
//           if (duration > 0) {
//             _exportingProgress.value = stats.getTime() / duration;
//           }
//         },
//       );
//       */
//     } catch (e) {
//       _isExporting.value = false;
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Error exporting video: $e')));
//     }
//   }

//   Future<void> _exportCover() async {
//     _isExporting.value = true;
//     try {
//       final outputPath = await _ioOutputPath(widget.filePath, 'jpg');
//       final config = _controller.createCoverFFmpegConfig();
//       final command = config.createExportCommand(
//         inputPath: widget.filePath,
//         outputPath: outputPath,
//       );

//       // Placeholder: fvp doesn't support FFmpeg commands directly
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Exporting cover not yet implemented with fvp'),
//         ),
//       );
//       _isExporting.value = false;

//       // Uncomment and adapt if using a forked ffmpeg_kit_flutter (see below)
//       /*
//       await FFmpegKit.executeAsync(
//         command,
//         (session) async {
//           _isExporting.value = false;
//           final returnCode = await session.getReturnCode();
//           if (returnCode?.isValueSuccess() == true) {
//             setState(() {
//               _outputPath = outputPath;
//             });
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(content: Text('Cover exported to: $_outputPath')),
//             );
//           } else {
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('Failed to export cover')),
//             );
//           }
//         },
//         null,
//         (stats) {
//           _exportingProgress.value = stats.getTime() / 1000;
//         },
//       );
//       */
//     } catch (e) {
//       _isExporting.value = false;
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Error exporting cover: $e')));
//     }
//   }

//   String _formatter(Duration duration) => [
//     duration.inMinutes.remainder(60).toString().padLeft(2, '0'),
//     duration.inSeconds.remainder(60).toString().padLeft(2, '0'),
//   ].join(":");

//   Widget _trimSlider() {
//     return Column(
//       children: [
//         AnimatedBuilder(
//           animation: Listenable.merge([_controller, _controller.video]),
//           builder: (_, __) {
//             final duration = _controller.videoDuration.inSeconds;
//             final pos = _controller.trimPosition * duration;

//             return Padding(
//               padding: EdgeInsets.symmetric(horizontal: _trimHeight / 4),
//               child: Row(
//                 children: [
//                   if (pos.isFinite)
//                     Text(_formatter(Duration(seconds: pos.toInt()))),
//                   const Expanded(child: SizedBox()),
//                   AnimatedOpacity(
//                     opacity: _controller.isTrimming ? 1.0 : 0.0,
//                     duration: const Duration(milliseconds: 300),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Text(_formatter(_controller.startTrim)),
//                         const SizedBox(width: 10),
//                         Text(_formatter(_controller.endTrim)),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           },
//         ),
//         Container(
//           width: MediaQuery.of(context).size.width,
//           margin: EdgeInsets.symmetric(vertical: _trimHeight / 4),
//           child: TrimSlider(
//             controller: _controller,
//             height: _trimHeight,
//             horizontalMargin: _trimHeight / 4,
//             child: TrimTimeline(
//               controller: _controller,
//               padding: const EdgeInsets.only(top: 10),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _coverSelection() {
//     return SingleChildScrollView(
//       child: Center(
//         child: Container(
//           margin: const EdgeInsets.all(15),
//           child: CoverSelection(
//             controller: _controller,
//             size: _trimHeight + 10,
//             quantity: 8,
//             selectedCoverBuilder: (cover, size) {
//               return Stack(
//                 alignment: Alignment.center,
//                 children: [
//                   cover,
//                   Icon(
//                     Icons.check_circle,
//                     color: const CoverSelectionStyle().selectedBorderColor,
//                   ),
//                 ],
//               );
//             },
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _topNavBar() {
//     return SafeArea(
//       child: SizedBox(
//         height: _trimHeight,
//         child: Row(
//           children: [
//             Expanded(
//               child: IconButton(
//                 onPressed: () => Navigator.of(context).pop(),
//                 icon: const Icon(Icons.exit_to_app),
//                 tooltip: 'Leave editor',
//               ),
//             ),
//             const VerticalDivider(endIndent: 22, indent: 22),
//             Expanded(
//               child: IconButton(
//                 onPressed:
//                     () => _controller.rotate90Degrees(RotateDirection.left),
//                 icon: const Icon(Icons.rotate_left),
//                 tooltip: 'Rotate counterclockwise',
//               ),
//             ),
//             Expanded(
//               child: IconButton(
//                 onPressed:
//                     () => _controller.rotate90Degrees(RotateDirection.right),
//                 icon: const Icon(Icons.rotate_right),
//                 tooltip: 'Rotate clockwise',
//               ),
//             ),
//             Expanded(
//               child: IconButton(
//                 onPressed: () async {
//                   await Navigator.push(
//                     context,
//                     MaterialPageRoute<void>(
//                       builder: (context) => CropScreen(controller: _controller),
//                     ),
//                   );
//                   if (kIsWeb) {
//                     setState(() => ++cropGridViewerKey);
//                   }
//                 },
//                 icon: const Icon(Icons.crop),
//                 tooltip: 'Open crop screen',
//               ),
//             ),
//             const VerticalDivider(endIndent: 22, indent: 22),
//             Expanded(
//               child: PopupMenuButton(
//                 tooltip: 'Open export menu',
//                 icon: const Icon(Icons.save),
//                 itemBuilder:
//                     (context) => [
//                       PopupMenuItem(
//                         onTap: _exportCover,
//                         child: const Text('Export cover'),
//                       ),
//                       PopupMenuItem(
//                         onTap: _exportVideo,
//                         child: const Text('Export video'),
//                       ),
//                     ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body:
//           _isInitialized
//               ? SafeArea(
//                 child: Stack(
//                   children: [
//                     Column(
//                       children: [
//                         _topNavBar(),
//                         Expanded(
//                           child: DefaultTabController(
//                             length: 2,
//                             child: Column(
//                               children: [
//                                 Expanded(
//                                   child: TabBarView(
//                                     physics:
//                                         const NeverScrollableScrollPhysics(),
//                                     children: [
//                                       Stack(
//                                         alignment: Alignment.center,
//                                         children: [
//                                           CropGridViewer.preview(
//                                             key: ValueKey(cropGridViewerKey),
//                                             controller: _controller,
//                                           ),
//                                           AnimatedBuilder(
//                                             animation: _controller.video,
//                                             builder:
//                                                 (_, __) => AnimatedOpacity(
//                                                   opacity:
//                                                       !_controller.isPlaying
//                                                           ? 1.0
//                                                           : 0.0,
//                                                   duration: const Duration(
//                                                     milliseconds: 300,
//                                                   ),
//                                                   child: GestureDetector(
//                                                     onTap:
//                                                         _controller.video.play,
//                                                     child: Container(
//                                                       width: 40,
//                                                       height: 40,
//                                                       decoration:
//                                                           const BoxDecoration(
//                                                             color: Colors.white,
//                                                             shape:
//                                                                 BoxShape.circle,
//                                                           ),
//                                                       child: const Icon(
//                                                         Icons.play_arrow,
//                                                         color: Colors.black,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                           ),
//                                         ],
//                                       ),
//                                       CoverViewer(controller: _controller),
//                                     ],
//                                   ),
//                                 ),
//                                 Container(
//                                   height: 200,
//                                   margin: const EdgeInsets.only(top: 10),
//                                   child: Column(
//                                     children: [
//                                       const TabBar(
//                                         tabs: [
//                                           Row(
//                                             mainAxisAlignment:
//                                                 MainAxisAlignment.center,
//                                             children: [
//                                               Padding(
//                                                 padding: EdgeInsets.all(5),
//                                                 child: Icon(Icons.content_cut),
//                                               ),
//                                               Text('Trim'),
//                                             ],
//                                           ),
//                                           Row(
//                                             mainAxisAlignment:
//                                                 MainAxisAlignment.center,
//                                             children: [
//                                               Padding(
//                                                 padding: EdgeInsets.all(5),
//                                                 child: Icon(Icons.video_label),
//                                               ),
//                                               Text('Cover'),
//                                             ],
//                                           ),
//                                         ],
//                                       ),
//                                       Expanded(
//                                         child: TabBarView(
//                                           physics:
//                                               const NeverScrollableScrollPhysics(),
//                                           children: [
//                                             Column(
//                                               mainAxisAlignment:
//                                                   MainAxisAlignment.center,
//                                               children: [_trimSlider()],
//                                             ),
//                                             _coverSelection(),
//                                           ],
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                                 if (_outputPath != null)
//                                   Padding(
//                                     padding: const EdgeInsets.all(8.0),
//                                     child: Text(
//                                       'Exported: $_outputPath',
//                                       style: const TextStyle(
//                                         color: Colors.white,
//                                       ),
//                                     ),
//                                   ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     ValueListenableBuilder(
//                       valueListenable: _isExporting,
//                       builder:
//                           (_, bool exporting, __) => AnimatedOpacity(
//                             opacity: exporting ? 1.0 : 0.0,
//                             duration: const Duration(milliseconds: 300),
//                             child: AlertDialog(
//                               title: ValueListenableBuilder(
//                                 valueListenable: _exportingProgress,
//                                 builder:
//                                     (_, double value, __) => Text(
//                                       "Exporting ${(value * 100).ceil()}%",
//                                       style: const TextStyle(fontSize: 12),
//                                     ),
//                               ),
//                             ),
//                           ),
//                     ),
//                   ],
//                 ),
//               )
//               : const Center(child: CircularProgressIndicator()),
//     );
//   }
// }

// class CropScreen extends StatelessWidget {
//   const CropScreen({super.key, required this.controller});

//   final VideoEditorController controller;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.all(30),
//           child: Column(
//             children: [
//               Row(
//                 children: [
//                   Expanded(
//                     child: IconButton(
//                       onPressed: () => Navigator.pop(context),
//                       icon: const Icon(Icons.close),
//                       tooltip: 'Close crop screen',
//                     ),
//                   ),
//                   Expanded(
//                     child: IconButton(
//                       onPressed: () {
//                         controller.cropAspectRatio(null);
//                         Navigator.pop(context);
//                       },
//                       icon: const Icon(Icons.crop_free),
//                       tooltip: 'Reset crop',
//                     ),
//                   ),
//                 ],
//               ),
//               Expanded(
//                 child: CropGridViewer.edit(
//                   controller: controller,
//                   margin: const EdgeInsets.symmetric(horizontal: 20),
//                 ),
//               ),
//               Row(
//                 children: [
//                   Expanded(
//                     child: IconButton(
//                       onPressed:
//                           () =>
//                               controller.rotate90Degrees(RotateDirection.left),
//                       icon: const Icon(Icons.rotate_left),
//                       tooltip: 'Rotate left',
//                     ),
//                   ),
//                   Expanded(
//                     child: IconButton(
//                       onPressed: () => controller.setPreferredRatioFromCrop(),
//                       icon: const Icon(Icons.crop),
//                       tooltip: 'Set current crop ratio',
//                     ),
//                   ),
//                   Expanded(
//                     child: IconButton(
//                       onPressed:
//                           () => controller.preferredCropAspectRatio = 1.0,
//                       icon: const Icon(Icons.crop_square),
//                       tooltip: 'Set square ratio',
//                     ),
//                   ),
//                   Expanded(
//                     child: IconButton(
//                       onPressed:
//                           () => controller.preferredCropAspectRatio = 16 / 9,
//                       icon: const Icon(Icons.crop_16_9),
//                       tooltip: 'Set 16:9 ratio',
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
