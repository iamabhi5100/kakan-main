import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart'; // ⬅️ add
import 'package:kakan/config/constant_api.dart';
import 'package:kakan/config/theme.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_bloc.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_event.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_state.dart';
import 'package:kakan/features/home/presentation/widgets/comments_screen.dart';
import 'package:kakan/features/home/presentation/widgets/feed_data_list.dart';
import 'package:kakan/features/home/presentation/widgets/share_screen.dart';
import 'package:kakan/features/profile/domain/entities/profile_post_entity.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_post_delete/delete_post_bloc.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_post_delete/delete_post_event.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_post_delete/delete_post_state.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_post_list/profile_posts_bloc.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_post_list/profile_posts_event.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:toastification/toastification.dart';
import 'package:video_player/video_player.dart';

class VideoFeedWidget extends StatefulWidget {
  final ProfilePostEntity? post;
  final String name;
  final String username;
  final String? profileImage;
  final String userId;
  const VideoFeedWidget({
    super.key,
    this.post,
    required this.name,
    required this.username,
    this.profileImage,
    required this.userId,
  });
  @override
  State<VideoFeedWidget> createState() => _VideoFeedWidgetState();
}

/// ---- Date helpers (same logic) ----
DateTime? _tryParseWithPatterns(String raw) {
  try {
    return DateTime.parse(raw).toLocal();
  } catch (_) {}
  const patterns = <String>[
    'dd/MM/yyyy, hh:mm a',
    'dd/MM/yyyy, HH:mm',
    'dd/MM/yyyy HH:mm',
    'dd-MM-yyyy HH:mm',
    'yyyy-MM-dd HH:mm:ss',
    'yyyy-MM-dd HH:mm',
    "yyyy-MM-dd'T'HH:mm:ss'Z'",
    "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
    "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
  ];
  for (final p in patterns) {
    try {
      return DateFormat(p).parseLoose(raw).toLocal();
    } catch (_) {}
  }
  return null;
}

String _formatDisplayDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 'Unknown time';
  final dt = _tryParseWithPatterns(raw);
  if (dt == null) return raw;
  return DateFormat('d MMM yyyy, h:mm a').format(dt);
}

class _VideoFeedWidgetState extends State<VideoFeedWidget> {
  late VideoPlayerController _controller;
  late int _likes;
  late int _reposts;
  late bool _flagLiked;
  bool _isMuted = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _likes = widget.post?.likesCount ?? 0;
    _reposts = widget.post?.repostCount ?? 0;
    _flagLiked = widget.post?.flagLiked ?? false;

    // Carousel posts use CarouselMediaWidget; no need to init single-video controller
    final isCarousel = widget.post?.mediaItems != null && widget.post!.mediaItems!.length > 1;
    if (isCarousel) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(''));
    } else if (widget.post?.mediaFile != null && widget.post!.mediaFile!.isNotEmpty) {
      final url = _normalizeMediaUrl(widget.post!.mediaFile!);
      _controller = VideoPlayerController.networkUrl(Uri.parse(url))
        ..initialize().then((_) {
          if (mounted) setState(() {});
        }).catchError((error) {
          if (kDebugMode) {
            print("Error initializing video: $error");
          }
        });
    } else {
      _controller = VideoPlayerController.networkUrl(Uri.parse(''));
    }
  }

  static String _normalizeMediaUrl(String url) {
    if (url.isEmpty) return url;
    final t = url.trim();
    if (t.startsWith('http://') || t.startsWith('https://')) return t;
    if (t.startsWith('/') && !t.startsWith('//')) return '${ConstantApi.baseUrl}$t';
    return t;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_isDeleting) return;
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  void _toggleLike() {
    if (_isDeleting || widget.post == null) return;
    setState(() {
      _flagLiked = !_flagLiked;
      _likes = _flagLiked ? _likes + 1 : _likes - 1;
    });
    context.read<FeedBloc>().add(LikeDislikePostEvent(postId: widget.post!.id));
  }

  void _toggleRepost() async {
    if (_isDeleting || widget.post == null) return;
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
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: captionController, decoration: const InputDecoration(labelText: 'Caption')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
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
      context.read<FeedBloc>().add(
            RepostEvent(
              postId: widget.post!.id,
              title: result['title']!,
              caption: result['caption']!,
            ),
          );
    }
  }

  void _toggleShare() {
    if (_isDeleting || widget.post == null) return;
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
        postId: widget.post?.id,
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
                    const SnackBar(content: Text('Report functionality not implemented')),
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
    if (_isDeleting || widget.post == null) return;
    final deleteBloc = context.read<DeletePostBloc>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true && widget.post?.id != null && mounted) {
      setState(() => _isDeleting = true);
      deleteBloc.add(DeletePostRequested(postId: widget.post!.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.post == null) return const SizedBox.shrink();

    return BlocProvider(
      create: (_) => di.sl<DeletePostBloc>(),
      child: Builder(
        builder: (providerContext) => BlocListener<DeletePostBloc, DeletePostState>(
          listener: (context, state) {
            if (state is DeletePostSuccess && mounted) {
              setState(() => _isDeleting = false);
              toastification.show(
                context: context,
                title: const Text('Post deleted successfully'),
                type: ToastificationType.success,
                style: ToastificationStyle.fillColored,
                autoCloseDuration: const Duration(seconds: 3),
              );
              context.read<ProfilePostsBloc>().add(
                    GetProfilePostsEvent(
                      mediaType: widget.post!.mediaType,
                      userId: widget.userId,
                    ),
                  );
            } else if (state is DeletePostError && mounted) {
              setState(() => _isDeleting = false);
              toastification.show(
                context: context,
                title: Text(state.message),
                type: ToastificationType.error,
                style: ToastificationStyle.fillColored,
                autoCloseDuration: const Duration(seconds: 3),
              );
            }
          },
          child: BlocListener<FeedBloc, FeedState>(
            listener: (context, state) {
              if (state is FeedActionSuccess && mounted) {
                if (state.actionType == 'repost') {
                  toastification.show(
                    context: context,
                    title: const Text('Repost created successfully'),
                    type: ToastificationType.success,
                    style: ToastificationStyle.fillColored,
                    autoCloseDuration: const Duration(seconds: 3),
                  );
                  context.read<ProfilePostsBloc>().add(GetProfilePostsEvent(
                    mediaType: widget.post!.mediaType,
                    userId: widget.userId,
                  ));
                } else if (state.actionType != 'comment') {
                  toastification.show(
                    context: context,
                    title: const Text('Action completed successfully'),
                    type: ToastificationType.success,
                    style: ToastificationStyle.fillColored,
                    autoCloseDuration: const Duration(seconds: 3),
                  );
                }
              } else if (state is FeedActionError && mounted) {
                if (state.message.contains('like')) {
                  setState(() {
                    _flagLiked = !_flagLiked;
                    _likes = _flagLiked ? _likes + 1 : _likes - 1;
                  });
                }
                toastification.show(
                  context: context,
                  title: Text(state.message),
                  type: ToastificationType.error,
                  style: ToastificationStyle.fillColored,
                  autoCloseDuration: const Duration(seconds: 3),
                );
              }
            },

            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: appTheme.primaryColor, width: 2),
                              image: DecorationImage(
                                image: widget.profileImage != null && widget.profileImage!.isNotEmpty
                                    ? NetworkImage(widget.profileImage!)
                                    : const AssetImage('assets/images/avataruser.png') as ImageProvider,
                                fit: BoxFit.cover,
                              ),
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('@${widget.username}', style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.more_horiz),
                            onPressed: _isDeleting ? null : () => _showMoreOptions(providerContext),
                          ),
                        ],
                      ),
                    ),

                    // Video or carousel (post_type: carousel with multiple media)
                    if (widget.post?.mediaItems != null && widget.post!.mediaItems!.length > 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: CarouselMediaWidget(
                          items: widget.post!.mediaItems!,
                          height: 280,
                          normalizeUrl: _normalizeMediaUrl,
                        ),
                      )
                    else if (_controller.value.isInitialized)
                      AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            GestureDetector(
                              onTap: _togglePlayPause,
                              child: VideoPlayer(_controller),
                            ),
                            if (!_controller.value.isPlaying)
                              const Icon(Icons.play_arrow, color: Colors.white, size: 48),
                          ],
                        ),
                      )
                    else
                      Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      ),

                    // Actions
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Image.asset(
                                  _flagLiked ? 'assets/images/like_filled.png' : 'assets/images/like_outline.png',
                                  width: 30,
                                  height: 30,
                                ),
                                onPressed: _isDeleting ? null : _toggleLike,
                              ),
                              Text('$_likes'),
                              const SizedBox(width: 16),
                              IconButton(
                                icon: Image.asset('assets/images/comment.png', width: 24, height: 24),
                                onPressed: () => showCommentsBottomSheet(context, postId: widget.post!.id),
                              ),
                              Text('${widget.post!.commentsCount}'),
                              const SizedBox(width: 16),
                              if (!widget.post!.flagOwnPost)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.repeat, color: Colors.green),
                                      onPressed: _isDeleting ? null : _toggleRepost,
                                    ),
                                    Text('$_reposts'),
                                  ],
                                ),
                            ],
                          ),
                          IconButton(
                            icon: Image.asset('assets/images/send.png', width: 24, height: 24),
                            onPressed: _isDeleting ? null : _toggleShare,
                          ),
                        ],
                      ),
                    ),

                    // Texts
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(widget.post?.title ?? 'No title available', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    ),
                    if (widget.post?.caption != null && widget.post!.caption.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        child: Text(widget.post!.caption, style: const TextStyle(fontSize: 14)),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: Text(
                        _formatDisplayDate(widget.post?.created ?? ''),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),

                if (_isDeleting)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black26,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FullScreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;
  const FullScreenVideoPage({required this.controller, super.key});
  @override
  State<FullScreenVideoPage> createState() => _FullScreenVideoPageState();
}

class _FullScreenVideoPageState extends State<FullScreenVideoPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.black,
        child: Center(
          child: widget.controller.value.isInitialized
              ? FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: widget.controller.value.size.width,
                    height: widget.controller.value.size.height,
                    child: VideoPlayer(widget.controller),
                  ),
                )
              : const Center(child: CircularProgressIndicator()),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Icon(Icons.close),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
    );
  }
}
