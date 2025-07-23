import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:kakan/config/theme.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_bloc.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_event.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_state.dart';
import 'package:kakan/features/home/presentation/widgets/share_screen.dart';
import 'package:kakan/features/profile/domain/entities/profile_post_entity.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_post_delete/delete_post_bloc.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_post_delete/delete_post_event.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_post_delete/delete_post_state.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_post_list/profile_posts_bloc.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_post_list/profile_posts_event.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:toastification/toastification.dart';

class AudioFeedWidget extends StatefulWidget {
  final ProfilePostEntity? post;
  final String name;
  final String username;
  final String? profileImage;

  const AudioFeedWidget({
    super.key,
    this.post,
    required this.name,
    required this.username,
    this.profileImage,
  });

  @override
  State<AudioFeedWidget> createState() => _AudioFeedWidgetState();
}

class _AudioFeedWidgetState extends State<AudioFeedWidget> {
  late AudioPlayer _audioPlayer;
  late int _likes;
  late int _reposts;
  late bool _flagLiked;
  bool _isMuted = false;
  bool _isDeleting = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _audioError;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _likes = widget.post?.likesCount ?? 100;
    _reposts = widget.post?.repostCount ?? 5;
    _flagLiked = widget.post?.flagLiked ?? false;
    _audioPlayer = AudioPlayer();
    if (kDebugMode) {
      print('AudioFeedWidget: Passed profile details: name=${widget.name}, username=${widget.username}, profileImage=${widget.profileImage}');
    }
    _initAudio();
    _audioPlayer.durationStream.listen((d) {
      if (mounted) {
        setState(() {
          _duration = d ?? Duration.zero;
        });
      }
    });
    _audioPlayer.positionStream.listen((p) {
      if (mounted) {
        setState(() {
          _position = p;
        });
      }
    });
  }

  Future<void> _initAudio() async {
    if (_retryCount >= _maxRetries) {
      setState(() {
        _audioError = 'Failed to load audio after $_maxRetries attempts';
      });
      return;
    }

    try {
      await _audioPlayer.setUrl(widget.post?.mediaFile ?? '');
      if (mounted) {
        setState(() {
          _audioError = null;
          _retryCount = 0;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing audio: $e');
      }
      if (mounted) {
        setState(() {
          _audioError = 'Failed to load audio. Tap to retry.';
          _retryCount++;
        });
        if (_retryCount < _maxRetries) {
          await Future.delayed(const Duration(seconds: 2));
          _initAudio();
        }
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_isDeleting || _audioError != null) return;
    setState(() {
      if (_audioPlayer.playing) {
        _audioPlayer.pause();
      } else {
        _audioPlayer.play();
      }
    });
  }

  void _toggleMute() {
    if (_isDeleting || _audioError != null) return;
    setState(() {
      _isMuted = !_isMuted;
      _audioPlayer.setVolume(_isMuted ? 0 : 1);
    });
  }

  void _retryAudio() {
    setState(() {
      _audioError = null;
      _retryCount = 0;
    });
    _initAudio();
  }

  void _toggleLike() {
    if (_isDeleting) return;
    setState(() {
      _flagLiked = !_flagLiked;
      _likes = _flagLiked ? _likes + 1 : _likes - 1;
    });
    context.read<FeedBloc>().add(LikeDislikePostEvent(postId: widget.post!.id));
  }

  void _toggleRepost() async {
    if (_isDeleting) return;
    final TextEditingController titleController =
        TextEditingController(text: '${widget.post?.title ?? 'Repost'} (Repost)');
    final TextEditingController captionController =
        TextEditingController(text: widget.post?.caption);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Repost'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: captionController,
              decoration: const InputDecoration(labelText: 'Caption'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, {
              'title': titleController.text,
              'caption': captionController.text,
            }),
            child: const Text('Repost'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      context.read<FeedBloc>().add(RepostEvent(
        postId: widget.post!.id,
        title: result['title']!,
        caption: result['caption']!,
      ));
    }
  }

  void _toggleShare() {
    if (_isDeleting) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ShareScreen(
        mediaFile: widget.post?.mediaFile,
        mediaType: widget.post?.mediaType,
        caption: widget.post?.caption,
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    if (_isDeleting) return;
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bottomSheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _confirmDelete(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.report, color: Colors.grey),
                title: Text('Report'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Report functionality not implemented')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context) async {
    if (_isDeleting) return;
    final deleteBloc = context.read<DeletePostBloc>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete Post'),
        content: Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && widget.post?.id != null && mounted) {
      setState(() {
        _isDeleting = true;
      });
      deleteBloc.add(DeletePostRequested(postId: widget.post!.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => di.sl<DeletePostBloc>(),
      child: Builder(
        builder: (providerContext) => BlocListener<DeletePostBloc, DeletePostState>(
          listener: (context, state) {
            if (state is DeletePostSuccess) {
              if (mounted) {
                setState(() {
                  _isDeleting = false;
                });
                toastification.show(
                  context: context,
                  title: Text('Post deleted successfully'),
                  type: ToastificationType.success,
                  style: ToastificationStyle.fillColored,
                  autoCloseDuration: Duration(seconds: 3),
                );
                context.read<ProfilePostsBloc>().add(GetProfilePostsEvent(
                    mediaType: widget.post?.mediaType ?? 'audio'));
              }
            } else if (state is DeletePostError) {
              if (mounted) {
                setState(() {
                  _isDeleting = false;
                });
                toastification.show(
                  context: context,
                  title: Text(state.message),
                  type: ToastificationType.error,
                  style: ToastificationStyle.fillColored,
                  autoCloseDuration: Duration(seconds: 3),
                );
              }
            }
          },
          child: BlocListener<FeedBloc, FeedState>(
            listener: (context, state) {
              if (state is FeedActionSuccess) {
                if (mounted) {
                  toastification.show(
                    context: context,
                    title: Text(state.newPostId != null ? 'Repost created successfully' : 'Action completed successfully'),
                    type: ToastificationType.success,
                    style: ToastificationStyle.fillColored,
                    autoCloseDuration: const Duration(seconds: 3),
                  );
                  if (state.newPostId != null) {
                    context.read<ProfilePostsBloc>().add(GetProfilePostsEvent(
                        mediaType: widget.post?.mediaType ?? 'audio'));
                  }
                }
              } else if (state is FeedActionError) {
                if (mounted) {
                  if (state.message.contains('like')) {
                    setState(() {
                      _flagLiked = !_flagLiked;
                      _likes = _flagLiked ? _likes + 1 : _likes - 1;
                    });
                    toastification.show(
                      context: context,
                      title: Text(state.message),
                      type: ToastificationType.error,
                      style: ToastificationStyle.fillColored,
                      autoCloseDuration: const Duration(seconds: 3),
                    );
                  }
                }
              }
            },
            child: Container(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8), // Slightly rounded corners
                            border: Border.all(color: appTheme.primaryColor, width: 2),
                            image: DecorationImage(
  image: widget.profileImage != null && widget.profileImage!.isNotEmpty
      ? NetworkImage(widget.profileImage!)
      : const AssetImage('assets/images/avataruser.png') as ImageProvider,
  fit: BoxFit.cover,
  onError: widget.profileImage != null && widget.profileImage!.isNotEmpty
      ? (exception, stackTrace) {
          if (kDebugMode) {
            print("Error loading profile image: $exception");
          }
        }
      : null,
),

                            color: Colors.grey, // Fallback color if image fails
                          ),
                          child: widget.profileImage == null || widget.profileImage!.isEmpty
                              ? Center(
                                  child: Text(
                                    widget.username.isNotEmpty ? widget.username[0].toUpperCase() : 'U',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '@${widget.username}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.more_horiz),
                          onPressed: _isDeleting ? null : () => _showMoreOptions(context),
                        ),
                      ],
                    ),
                  ),
                  if (_audioError != null)
                    GestureDetector(
                      onTap: _retryAudio,
                      child: Container(
                        height: 100,
                        color: Colors.grey,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _audioError!,
                                style: const TextStyle(color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Tap to retry',
                                style: TextStyle(color: Colors.blue),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        Container(
                          height: 100,
                          color: Colors.black,
                          child: const Center(
                            child: Icon(Icons.music_note, color: Colors.white, size: 50),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  _audioPlayer.playing ? Icons.pause : Icons.play_arrow,
                                  color: Colors.blue,
                                  size: 30,
                                ),
                                onPressed: _togglePlayPause,
                              ),
                              Expanded(
                                child: Slider(
                                  value: _position.inSeconds.toDouble(),
                                  max: _duration.inSeconds.toDouble() > 0
                                      ? _duration.inSeconds.toDouble()
                                      : 1.0,
                                  activeColor: appTheme.primaryColor,
                                  inactiveColor: Colors.grey,
                                  onChanged: (value) {
                                    _audioPlayer.seek(Duration(seconds: value.toInt()));
                                  },
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  _isMuted ? Icons.volume_off : Icons.volume_up,
                                  color: Colors.grey,
                                  size: 24,
                                ),
                                onPressed: _toggleMute,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _flagLiked ? Icons.favorite : Icons.favorite_border,
                                color: _flagLiked ? Colors.red : Colors.black,
                                size: 16,
                              ),
                              onPressed: _isDeleting ? null : _toggleLike,
                            ),
                            SizedBox(width: 4),
                            Text('$_likes Likes'),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.repeat, color: Colors.green, size: 16),
                              onPressed: _isDeleting ? null : _toggleRepost,
                            ),
                            SizedBox(width: 4),
                            Text('$_reposts Reposts'),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.send, color: Colors.grey, size: 16),
                          onPressed: _isDeleting ? null : _toggleShare,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      widget.post?.caption ?? 'No caption available',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                    child: Text(
                      widget.post?.created ?? 'Unknown time',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}