import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/features/home/model/entities/feed_entity.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_bloc.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_event.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_state.dart';
import 'package:kakan/features/home/presentation/widgets/share_screen.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:kakan/core/utils/media_manager.dart';
import 'package:kakan/core/utils/session_manager.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:toastification/toastification.dart';
import 'package:kakan/config/theme.dart';

class FeedDataList extends StatefulWidget {
  const FeedDataList({super.key});

  @override
  State<FeedDataList> createState() => _FeedDataListState();
}

class _FeedDataListState extends State<FeedDataList> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<FeedBloc>().add(GetFeedEvent());
      }
    });
  }

  @override
  void dispose() {
    MediaManager().disposeMedia();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FeedBloc, FeedState>(
      listener: (context, state) {
        if (state is FeedActionError) {
          toastification.show(
            context: context,
            title: Text(state.message),
            type: ToastificationType.error,
            style: ToastificationStyle.fillColored,
            autoCloseDuration: const Duration(seconds: 3),
          );
        } else if (state is FeedActionSuccess) {
          toastification.show(
            context: context,
            title: Text(
              state.newPostId != null
                  ? 'Repost created successfully'
                  : 'Action completed successfully',
            ),
            type: ToastificationType.success,
            style: ToastificationStyle.fillColored,
            autoCloseDuration: const Duration(seconds: 3),
          );
        }
      },
      builder: (context, state) {
        return BlocSelector<FeedBloc, FeedState, dynamic>(
          selector: (state) {
            if (state is FeedLoading || state is FeedActionLoading) {
              return 'loading';
            } else if (state is FeedLoaded) {
              return state.feeds;
            } else if (state is FeedError) {
              return state.message;
            }
            return null;
          },
          builder: (context, selectedState) {
            if (selectedState == 'loading') {
              return const Center(child: CircularProgressIndicator());
            } else if (selectedState is List<FeedEntity>) {
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: selectedState.length,
                itemBuilder: (context, index) {
                  final feed = selectedState[index];
                  return FeedItemWidget(feed: feed);
                },
              );
            } else if (selectedState is String) {
              return Center(child: Text(selectedState));
            }
            return const SizedBox.shrink();
          },
        );
      },
    );
  }
}

class FeedItemWidget extends StatefulWidget {
  final FeedEntity feed;

  const FeedItemWidget({super.key, required this.feed});

  @override
  State<FeedItemWidget> createState() => _FeedItemWidgetState();
}

class _FeedItemWidgetState extends State<FeedItemWidget> {
  VideoPlayerController? _controller;
  AudioPlayer? _audioPlayer;
  bool _isExpanded = false;
  bool _isMuted = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _audioError;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  final SessionManager _sessionManager = di.sl<SessionManager>();

  @override
  void initState() {
    super.initState();
    if (widget.feed.mediaType == 'video' && widget.feed.mediaFile.isNotEmpty) {
      _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.feed.mediaFile),
        )
        ..initialize()
            .then((_) {
              if (mounted) {
                setState(() {});
                MediaManager().setVideoController(_controller!);
              }
            })
            .catchError((error) {
              if (kDebugMode) {
                print('Error initializing video: $error');
              }
              setState(() {
                _audioError = 'Failed to load video';
              });
            });
    } else if (widget.feed.mediaType == 'audio' &&
        widget.feed.mediaFile.isNotEmpty) {
      _audioPlayer = AudioPlayer();
      _initAudio();
      _audioPlayer!.durationStream.listen((d) {
        if (mounted) {
          setState(() {
            _duration = d ?? Duration.zero;
          });
        }
      });
      _audioPlayer!.positionStream.listen((p) {
        if (mounted) {
          setState(() {
            _position = p;
          });
        }
      });
    }
  }

  Future<void> _initAudio() async {
    if (_retryCount >= _maxRetries) {
      setState(() {
        _audioError = 'Failed to load audio after $_maxRetries attempts';
      });
      return;
    }

    try {
      final accessToken = await _sessionManager.getAccessToken();
      final headers =
          accessToken != null
              ? <String, String>{'Authorization': 'Bearer $accessToken'}
              : <String, String>{};
      await _audioPlayer!.setUrl(widget.feed.mediaFile, headers: headers);
      if (mounted) {
        setState(() {
          _audioError = null;
          _retryCount = 0;
        });
        if (kDebugMode) {
          print('DEBUG: AudioPlayer initialized for ${widget.feed.mediaFile}');
        }
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
          if (kDebugMode) {
            print(
              'DEBUG: Retrying audio initialization (attempt ${_retryCount + 1}/$_maxRetries)',
            );
          }
          await Future.delayed(const Duration(seconds: 2));
          _initAudio();
        }
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  String _truncateCaption(String caption) {
    if (caption.length > 50 && !_isExpanded) {
      return '${caption.substring(0, 50)}...';
    }
    return caption;
  }

  void _toggleLike() {
    context.read<FeedBloc>().add(LikeDislikePostEvent(postId: widget.feed.id));
  }

  void _toggleRepost() async {
    final TextEditingController titleController = TextEditingController(
      text: '${widget.feed.title ?? 'Repost'} (Repost)',
    );
    final TextEditingController captionController = TextEditingController(
      text: widget.feed.caption,
    );

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
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
                onPressed:
                    () => Navigator.pop(dialogContext, {
                      'title': titleController.text,
                      'caption': captionController.text,
                    }),
                child: const Text('Repost'),
              ),
            ],
          ),
    );

    if (result != null && mounted) {
      context.read<FeedBloc>().add(
        RepostEvent(
          postId: widget.feed.id,
          title: result['title']!,
          caption: result['caption']!,
        ),
      );
    }
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bottomSheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _confirmDelete(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.report, color: Colors.grey),
                title: const Text('Report'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Report functionality not implemented'),
                    ),
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
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Delete Post'),
            content: const Text('Are you sure you want to delete this post?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true && mounted) {
      context.read<FeedBloc>().add(DeleteFeedEvent(feedId: widget.feed.id));
    }
  }

  void _togglePlayPause() {
    if (_audioPlayer == null || _audioError != null) return;
    if (_audioPlayer!.playing) {
      _audioPlayer!.pause();
    } else {
      _audioPlayer!.play();
    }
    setState(() {});
  }

  void _toggleMute() {
    if (_audioPlayer == null || _audioError != null) return;
    setState(() {
      _isMuted = !_isMuted;
      _audioPlayer!.setVolume(_isMuted ? 0 : 1);
    });
  }

  void _retryAudio() {
    setState(() {
      _audioError = null;
      _retryCount = 0;
    });
    _initAudio();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      8,
                    ), // Slightly rounded corners
                    border: Border.all(color: appTheme.primaryColor, width: 2),
                    image: DecorationImage(
                      image:
                          widget.feed.userProfileDetails.profileImage != null &&
                                  widget
                                      .feed
                                      .userProfileDetails
                                      .profileImage!
                                      .isNotEmpty
                              ? NetworkImage(
                                widget.feed.userProfileDetails.profileImage!,
                              )
                              : const AssetImage('assets/images/avataruser.png')
                                  as ImageProvider,
                      fit: BoxFit.cover,
                      onError:
                          widget.feed.userProfileDetails.profileImage != null &&
                                  widget
                                      .feed
                                      .userProfileDetails
                                      .profileImage!
                                      .isNotEmpty
                              ? (exception, stackTrace) {
                                if (kDebugMode) {
                                  print(
                                    "Error loading profile image: $exception",
                                  );
                                }
                              }
                              : null,
                    ),

                    color: Colors.grey, // Fallback color if image fails
                  ),
                  child:
                      widget.feed.userProfileDetails.profileImage == null ||
                              widget
                                  .feed
                                  .userProfileDetails
                                  .profileImage!
                                  .isEmpty
                          ? Center(
                            child: Text(
                              widget.feed.userProfileDetails.username.isNotEmpty
                                  ? widget.feed.userProfileDetails.username[0]
                                      .toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          )
                          : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.feed.userProfileDetails.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '@${widget.feed.userProfileDetails.username}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz),
                  onPressed: () => _showMoreOptions(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (widget.feed.mediaType == 'video' &&
              _controller != null &&
              _controller!.value.isInitialized)
            AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(_controller!),
                  IconButton(
                    icon: Icon(
                      _controller!.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: Colors.white,
                      size: 48,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_controller!.value.isPlaying) {
                          _controller!.pause();
                        } else {
                          _controller!.play();
                        }
                      });
                    },
                  ),
                ],
              ),
            )
          else if (widget.feed.mediaType == 'audio' && _audioPlayer != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 4.0,
              ),
              child: Column(
                children: [
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
                            child: Icon(
                              Icons.music_note,
                              color: Colors.white,
                              size: 50,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _audioPlayer!.playing
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Colors.blue,
                                size: 30,
                              ),
                              onPressed: _togglePlayPause,
                            ),
                            Expanded(
                              child: Slider(
                                value: _position.inSeconds.toDouble(),
                                max:
                                    _duration.inSeconds.toDouble() > 0
                                        ? _duration.inSeconds.toDouble()
                                        : 1.0,
                                activeColor: Theme.of(context).primaryColor,
                                inactiveColor: Colors.grey,
                                onChanged: (value) {
                                  _audioPlayer!.seek(
                                    Duration(seconds: value.toInt()),
                                  );
                                  setState(() {});
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
                      ],
                    ),
                ],
              ),
            )
          else if (widget.feed.thumbnail != null)
            Image.network(
              widget.feed.thumbnail!,
              width: double.infinity,
              fit: BoxFit.cover,
            )
          else
            Container(
              height: 100,
              color: Colors.grey,
              child: const Center(child: CircularProgressIndicator()),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    widget.feed.flagLiked
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: widget.feed.flagLiked ? Colors.red : Colors.black,
                  ),
                  onPressed: _toggleLike,
                ),
                Text('${widget.feed.likesCount} Likes'),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.repeat),
                  onPressed: _toggleRepost,
                ),
                Text('${widget.feed.repostCount} Reposts'),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder:
                          (context) => ShareScreen(
                            mediaFile: widget.feed.mediaFile,
                            mediaType: widget.feed.mediaType,
                            caption: widget.feed.caption,
                          ),
                    );
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: _truncateCaption(widget.feed.caption),
                          style: const TextStyle(color: Colors.black),
                        ),
                        if (widget.feed.caption.length > 50 && !_isExpanded)
                          const TextSpan(text: ' '),
                        if (widget.feed.caption.length > 50 && !_isExpanded)
                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isExpanded = true;
                                });
                              },
                              child: const Text(
                                'MORE',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
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
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 4.0,
            ),
            child: Text(
              widget.feed.created,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
