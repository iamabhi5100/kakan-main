// import 'package:easy_video_editor/easy_video_editor.dart';
// import 'package:flutter/material.dart';
// import 'package:kakan/features/myfiles/presentation/pages/video_edit_screen.dart';
// import 'dart:io';
// import 'package:kakan/features/youtube/data/api_service.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:video_player/video_player.dart';

// class DownloadedVideosScreen extends StatefulWidget {
//   const DownloadedVideosScreen({Key? key}) : super(key: key);

//   @override
//   State<DownloadedVideosScreen> createState() => _DownloadedVideosScreenState();
// }

// class _DownloadedVideosScreenState extends State<DownloadedVideosScreen> {
//   final ApiService _apiService = ApiService();
//   List<Map<String, dynamic>> _downloadedVideos = [];
//   bool _isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     _fetchDownloadedVideos();
//   }

//   Future<void> _fetchDownloadedVideos() async {
//     setState(() {
//       _isLoading = true;
//     });
//     try {
//       final videos = await _apiService.getDownloadedVideos();
//       setState(() {
//         _downloadedVideos = videos;
//         _isLoading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _isLoading = false;
//       });
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching downloaded videos: $e')),
//       );
//     }
//   }

//   void _playVideo(String filePath) {
//     final file = File(filePath);
//     if (file.existsSync()) {
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (context) => VideoPlayerScreen(filePath: filePath),
//         ),
//       );
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Video file not found on device')),
//       );
//     }
//   }

//   void _editVideo(String filePath) {
//     final file = File(filePath);
//     if (file.existsSync()) {
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (context) => VideoEditScreen(filePath: filePath),
//         ),
//       );
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Video file not found on device')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('My Downloaded Videos'),
//       ),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : _downloadedVideos.isEmpty
//               ? const Center(child: Text('No downloaded videos yet'))
//               : ListView.builder(
//                   itemCount: _downloadedVideos.length,
//                   itemBuilder: (context, index) {
//                     final video = _downloadedVideos[index];
//                     return ListTile(
//                       leading: video['thumbnailUrl'] != null
//                           ? Image.network(
//                               video['thumbnailUrl'],
//                               width: 60,
//                               height: 40,
//                               fit: BoxFit.cover,
//                               errorBuilder: (context, error, stackTrace) {
//                                 return const Icon(Icons.video_library, size: 40);
//                               },
//                             )
//                           : const Icon(Icons.video_library, size: 40),
//                       title: Text(video['title']),
//                       subtitle: Text('${video['channelTitle']} • ${video['createdAt']}'),
//                       trailing: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           IconButton(
//                             icon: const Icon(Icons.play_arrow),
//                             tooltip: 'Play Video',
//                             onPressed: () => _playVideo(video['filePath']),
//                           ),
//                           IconButton(
//                             icon: const Icon(Icons.edit),
//                             tooltip: 'Edit Video',
//                             onPressed: () => _editVideo(video['filePath']),
//                           ),
//                         ],
//                       ),
//                     );
//                   },
//                 ),
//     );
//   }
// }

// // VideoPlayerScreen for playing the video
// class VideoPlayerScreen extends StatefulWidget {
//   final String filePath;

//   const VideoPlayerScreen({Key? key, required this.filePath}) : super(key: key);

//   @override
//   State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
// }

// class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
//   late VideoPlayerController _controller;
//   bool _isInitialized = false;

//   @override
//   void initState() {
//     super.initState();
//     _controller = VideoPlayerController.file(File(widget.filePath))
//       ..initialize().then((_) {
//         setState(() {
//           _isInitialized = true;
//         });
//         _controller.play();
//       }).catchError((error) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error loading video: $error')),
//         );
//       });
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Play Video"),
//       ),
//       body: _isInitialized
//           ? Column(
//               children: [
//                 AspectRatio(
//                   aspectRatio: _controller.value.aspectRatio,
//                   child: VideoPlayer(_controller),
//                 ),
//                 VideoProgressIndicator(_controller, allowScrubbing: true),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     IconButton(
//                       icon: Icon(
//                         _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
//                       ),
//                       onPressed: () {
//                         setState(() {
//                           _controller.value.isPlaying
//                               ? _controller.pause()
//                               : _controller.play();
//                         });
//                       },
//                     ),
//                     IconButton(
//                       icon: const Icon(Icons.stop),
//                       onPressed: () {
//                         setState(() {
//                           _controller.pause();
//                           _controller.seekTo(Duration.zero);
//                         });
//                       },
//                     ),
//                   ],
//                 ),
//               ],
//             )
//           : const Center(child: CircularProgressIndicator()),
//     );
//   }
// }

// // VideoEditScreen for editing the video
