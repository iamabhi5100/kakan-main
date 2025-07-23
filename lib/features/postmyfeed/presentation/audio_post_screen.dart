import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kakan/config/theme.dart';
import 'package:kakan/features/postmyfeed/presentation/bloc/post_bloc/post_bloc.dart';
import 'package:kakan/features/postmyfeed/presentation/bloc/post_bloc/post_event.dart';
import 'package:kakan/features/postmyfeed/presentation/bloc/post_bloc/post_state.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:toastification/toastification.dart';
import 'package:just_audio/just_audio.dart'; // Use just_audio instead of audioplayers

class AudioPostScreen extends StatefulWidget {
  final String? filePath;
  final String? mediaId;

  const AudioPostScreen({super.key, this.filePath, this.mediaId});

  @override
  State<AudioPostScreen> createState() => _AudioPostScreenState();
}

class _AudioPostScreenState extends State<AudioPostScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  String _privacy = 'Public';

  // Audio player variables
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    print('DEBUG: Initializing AudioPostScreen with filePath: ${widget.filePath}, mediaId: ${widget.mediaId}');
    if (widget.filePath != null) {
      _titleController.text = widget.filePath!.split('/').last.split('.').first;
      print('DEBUG: Setting title to: ${_titleController.text}');
      _initAudioPlayer();
    } else {
      print('DEBUG: No filePath provided to AudioPostScreen');
    }
  }

  // Initialize audio player for remote or local files
  void _initAudioPlayer() async {
    if (widget.filePath != null) {
      try {
        await _audioPlayer.setUrl(widget.filePath!); // Handles both local and remote URLs
        _audioPlayer.durationStream.listen((d) {
          setState(() {
            _duration = d ?? Duration.zero;
          });
        });
        _audioPlayer.positionStream.listen((p) {
          setState(() {
            _position = p;
          });
        });
        _audioPlayer.playingStream.listen((playing) {
          setState(() {
            _isPlaying = playing;
          });
        });
      } catch (e) {
        print('DEBUG: Error initializing audio player: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load audio: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    print('DEBUG: Disposing AudioPostScreen');
    _audioPlayer.dispose();
    _titleController.dispose();
    _captionController.dispose();
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
              description: const Text('Audio uploaded successfully!'),
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
              errorMessage = 'Media file is required. Please ensure a valid audio is selected.';
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to upload audio: $errorMessage')),
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
                // Audio player section with ListTile design
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: widget.filePath != null
                      ? ListTile(
                          leading: const Icon(Icons.music_note, size: 40, color: Colors.grey),
                          title: Text(
                            _titleController.text.isNotEmpty
                                ? _titleController.text
                                : widget.filePath!.split('/').last,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      _isPlaying ? Icons.pause : Icons.play_arrow,
                                      color: appTheme.primaryColor,
                                      size: 30,
                                    ),
                                    onPressed: () async {
                                      try {
                                        if (_isPlaying) {
                                          await _audioPlayer.pause();
                                          print('DEBUG: Audio paused');
                                        } else {
                                          await _audioPlayer.play();
                                          print('DEBUG: Audio playing');
                                        }
                                      } catch (e) {
                                        print('DEBUG: Error playing audio: $e');
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Failed to play audio: $e')),
                                        );
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.stop, color: appTheme.primaryColor, size: 30),
                                    onPressed: () async {
                                      try {
                                        await _audioPlayer.stop();
                                        await _audioPlayer.seek(Duration.zero);
                                        print('DEBUG: Audio stopped');
                                      } catch (e) {
                                        print('DEBUG: Error stopping audio: $e');
                                      }
                                    },
                                  ),
                                ],
                              ),
                              Slider(
                                activeColor: appTheme.primaryColor,
                                inactiveColor: Colors.grey[300],
                                min: 0.0,
                                max: _duration.inSeconds.toDouble() > 0
                                    ? _duration.inSeconds.toDouble()
                                    : 1.0,
                                value: _position.inSeconds.toDouble(),
                                onChanged: (value) async {
                                  try {
                                    final position = Duration(seconds: value.toInt());
                                    await _audioPlayer.seek(position);
                                    print('DEBUG: Audio seek to ${position.inSeconds} seconds');
                                  } catch (e) {
                                    print('DEBUG: Error seeking audio: $e');
                                  }
                                },
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(_position),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    _formatDuration(_duration),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      : ListTile(
                          leading: const Icon(Icons.audiotrack, size: 40, color: Colors.grey),
                          title: const Text('No audio selected'),
                          subtitle: const Text('Please select an audio file'),
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
                    setState(() {}); // Update UI when title changes
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
                    const Text('Privacy'),
                    const Spacer(),
                    ChoiceChip(
                      label: const Text('Public'),
                      selected: _privacy == 'Public',
                      onSelected: (selected) {
                        if (selected) {
                          print('DEBUG: Privacy set to Public');
                          setState(() => _privacy = 'Public');
                        }
                      },
                      selectedColor: appTheme.primaryColor.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: appTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Followers'),
                      selected: _privacy == 'Followers',
                      onSelected: (selected) {
                        if (selected) {
                          print('DEBUG: Privacy set to Followers');
                          setState(() => _privacy = 'Followers');
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
                                  print('DEBUG: Validation failed - No audio selected');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please select an audio file')),
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
                                        mediaType: 'audio',
                                        title: _titleController.text.trim(),
                                        caption: _captionController.text.isEmpty
                                            ? null
                                            : _captionController.text,
                                        mediaFilePath: widget.filePath,
                                        mediaId: widget.mediaId,
                                        thumbnailPath: null,
                                        shareTo: _privacy.toLowerCase(),
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

  // Helper method to format duration (e.g., 01:23)
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}