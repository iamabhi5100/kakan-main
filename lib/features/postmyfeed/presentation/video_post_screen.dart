import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kakan/config/theme.dart';
import 'package:kakan/features/postmyfeed/presentation/bloc/post_bloc/post_bloc.dart';
import 'package:kakan/features/postmyfeed/presentation/bloc/post_bloc/post_event.dart';
import 'package:kakan/features/postmyfeed/presentation/bloc/post_bloc/post_state.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:toastification/toastification.dart';
import 'package:video_player/video_player.dart';

class VideoPostScreen extends StatefulWidget {
  final String? filePath;
  final String? mediaId;

  const VideoPostScreen({super.key, this.filePath, this.mediaId});

  @override
  State<VideoPostScreen> createState() => _VideoPostScreenState();
}

class _VideoPostScreenState extends State<VideoPostScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  String _shareTo = 'All';
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    print('DEBUG: Initializing VideoPostScreen with filePath: ${widget.filePath}, mediaId: ${widget.mediaId}');
    if (widget.filePath != null) {
      _titleController.text = widget.filePath!.split('/').last.split('.').first;
      print('DEBUG: Setting title to: ${_titleController.text}');
      if (widget.filePath!.startsWith('http')) {
        _videoController = VideoPlayerController.network(widget.filePath!)
          ..initialize().then((_) {
            if (mounted) {
              print('DEBUG: VideoPlayerController (network) initialized for ${widget.filePath}');
              setState(() {});
            }
          }).catchError((error) {
            print('DEBUG: Error initializing VideoPlayerController (network): $error');
          });
      } else {
        _videoController = VideoPlayerController.file(File(widget.filePath!))
          ..initialize().then((_) {
            if (mounted) {
              print('DEBUG: VideoPlayerController (file) initialized for ${widget.filePath}');
              setState(() {});
            }
          }).catchError((error) {
            print('DEBUG: Error initializing VideoPlayerController (file): $error');
          });
      }
    } else {
      print('DEBUG: No filePath provided to VideoPostScreen');
    }
  }

  @override
  void dispose() {
    print('DEBUG: Disposing VideoPostScreen');
    _titleController.dispose();
    _captionController.dispose();
    _videoController?.pause();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => di.sl<PostBloc>(),
      child: BlocListener<PostBloc, PostState>(
        listener: (context, state) {
          if (state is PostCreated) {
            toastification.show(
              context: context,
              type: ToastificationType.success,
              style: ToastificationStyle.fillColored,
              title: const Text('Success'),
              description: const Text('Video uploaded successfully!'),
              alignment: Alignment.topCenter,
              autoCloseDuration: const Duration(seconds: 3),
              icon: const Icon(Icons.check_circle),
              boxShadow: lowModeShadow,
              showProgressBar: true,
            );
            print('DEBUG: Navigating to /home after successful upload');
            context.go('/home');
          } else if (state is PostError) {
            String errorMessage = state.message;
            if (state.message.contains('Media file is required')) {
              errorMessage = 'Media file is required. Please ensure a valid video is selected.';
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to upload video: $errorMessage')),
            );
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('New Post'),
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () {
                print('DEBUG: Back button pressed');
                Navigator.of(context).pop();
              },
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 200,
                  color: Colors.grey[300],
                  child: widget.filePath != null && _videoController != null && _videoController!.value.isInitialized
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            VideoPlayer(_videoController!),
                            IconButton(
                              icon: Icon(
                                _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 50,
                              ),
                              onPressed: () {
                                if (_videoController!.value.isPlaying) {
                                  print('DEBUG: Pausing video');
                                  _videoController!.pause();
                                } else {
                                  print('DEBUG: Playing video');
                                  _videoController!.play();
                                }
                                setState(() {});
                              },
                            ),
                          ],
                        )
                      : Center(
                          child: widget.filePath != null
                              ? Text(
                                  'Selected Video: ${widget.filePath!.split('/').last}',
                                  style: const TextStyle(color: Colors.white),
                                )
                              : const Icon(Icons.play_circle_outline, size: 50, color: Colors.white),
                        ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Title*',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: 'Enter Title (Max 50 Letters)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLength: 50,
                  onChanged: (value) {
                    print('DEBUG: Title changed to: $value');
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Caption (Optional)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _captionController,
                  decoration: InputDecoration(
                    hintText: 'Add a caption...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 4,
                  onChanged: (value) {
                    print('DEBUG: Caption changed to: $value');
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Share to'),
                    const Spacer(),
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _shareTo == 'All',
                      onSelected: (selected) {
                        if (selected) {
                          print('DEBUG: Share to set to All');
                          setState(() => _shareTo = 'All');
                        }
                      },
                      selectedColor: appTheme.primaryColor.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: appTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('My Followers'),
                      selected: _shareTo == 'My Followers',
                      onSelected: (selected) {
                        if (selected) {
                          print('DEBUG: Share to set to My Followers');
                          setState(() => _shareTo = 'My Followers');
                        }
                      },
                      selectedColor: appTheme.primaryColor.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: appTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                BlocBuilder<PostBloc, PostState>(
                  builder: (context, state) {
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: state is PostLoading
                            ? null
                            : () {
                                if (widget.filePath == null) {
                                  print('DEBUG: Validation failed - No video selected');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please select a video')),
                                  );
                                  return;
                                }
                                if (_titleController.text.trim().isEmpty) {
                                  print('DEBUG: Validation failed - Title is empty');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please provide a title')),
                                  );
                                  return;
                                }
                                print('DEBUG: Creating post with mediaId: ${widget.mediaId}');
                                context.read<PostBloc>().add(
                                      CreatePostEvent(
                                        mediaType: 'video',
                                        title: _titleController.text.trim(),
                                        caption: _captionController.text.isEmpty ? null : _captionController.text,
                                        mediaFilePath: widget.filePath,
                                        mediaId: widget.mediaId,
                                        shareTo: _shareTo.toLowerCase(),
                                      ),
                                    );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: state is PostLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'Share',
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}