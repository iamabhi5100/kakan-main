// lib/features/search/presentation/video_content_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_bloc.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_event.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_state.dart';
import 'package:kakan/features/home/presentation/widgets/share_screen.dart';
import 'package:kakan/features/search/domain/entities/search_result.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:toastification/toastification.dart';
import 'package:video_player/video_player.dart';

class VideoContentScreen extends StatefulWidget {
  final SearchResult video;
  const VideoContentScreen({Key? key, required this.video}) : super(key: key);

  @override
  _VideoContentScreenState createState() => _VideoContentScreenState();
}

class _VideoContentScreenState extends State<VideoContentScreen> {
  late final VideoPlayerController _controller;
  late final Future<void> _initFuture;
  late bool _flagLiked;
  late int _likes;
  late int _reposts;

  @override
  void initState() {
    super.initState();
    _flagLiked = widget.video.flagLiked ?? false;
    _likes = widget.video.likesCount ?? 0;
    _reposts = widget.video.repostCount ?? 0;
    final url = widget.video.mediaFile ?? '';
    _controller = VideoPlayerController.network(url);
    _initFuture = _controller.initialize().then((_) {
      _controller.play();
      _controller.setLooping(true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta = widget.video;

    return BlocProvider(
      create: (_) => di.sl<FeedBloc>(),
      child: Builder(
        builder: (providerContext) => BlocListener<FeedBloc, FeedState>(
          listener: (context, state) {
            if (state is FeedActionSuccess) {
              if (mounted) {
                toastification.show(
                  context: context,
                  title: Text(state.newPostId != null
                      ? 'Repost created successfully'
                      : 'Action completed successfully'),
                  type: ToastificationType.success,
                  style: ToastificationStyle.fillColored,
                  autoCloseDuration: const Duration(seconds: 3),
                );
                if (state.newPostId != null) {
                  // CHANGED: GetFeedEvent -> RefreshFeedsEvent
                  context.read<FeedBloc>().add(const RefreshFeedsEvent());
                }
              }
            } else if (state is FeedActionError) {
              if (mounted) {
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
            }
          },
          child: Scaffold(
            backgroundColor: Colors.grey[100],
            appBar: AppBar(
              backgroundColor: Colors.white,
              leading: const BackButton(color: Colors.black),
              title: Text(
                meta.name ?? '',
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.w600),
              ),
              elevation: 0,
            ),
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          meta.profileImage != null
                              ? CircleAvatar(
                                  radius: 20,
                                  backgroundImage:
                                      NetworkImage(meta.profileImage!),
                                )
                              : const CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.grey,
                                  child: Icon(Icons.person, color: Colors.black54),
                                ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                meta.name ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              Text(
                                '@${meta.username ?? ''}',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.more_horiz,
                                color: Colors.black54),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),

                    // Video or Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: FutureBuilder<void>(
                        future: _initFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.done) {
                            return AspectRatio(
                              aspectRatio: _controller.value.aspectRatio,
                              child: Stack(
                                children: [
                                  VideoPlayer(_controller),
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: IconButton(
                                      icon: Icon(
                                        _controller.value.isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                        color: Colors.white,
                                        size: 40,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _controller.value.isPlaying
                                              ? _controller.pause()
                                              : _controller.play();
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else if (snapshot.hasError) {
                            return Image.network(
                              meta.thumbnail ?? '',
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 200,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: Icon(Icons.videocam_off, size: 60),
                                ),
                              ),
                            );
                          } else {
                            return Container(
                              height: 200,
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.black54),
                              ),
                            );
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Actions
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Row(
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  _flagLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: _flagLiked ? Colors.red : Colors.black,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _flagLiked = !_flagLiked;
                                    _likes = _flagLiked ? _likes + 1 : _likes - 1;
                                  });
                                  providerContext
                                      .read<FeedBloc>()
                                      .add(LikeDislikePostEvent(postId: meta.id));
                                },
                              ),
                              Text('$_likes Likes', style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.repeat, color: Colors.green),
                                onPressed: () async {
                                  final TextEditingController titleController =
                                      TextEditingController(text: '${meta.name ?? 'Repost'} (Repost)');
                                  final TextEditingController captionController =
                                      TextEditingController(text: meta.description);

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
                                    providerContext.read<FeedBloc>().add(
                                      RepostEvent(
                                        postId: meta.id,
                                        title: result['title']!,
                                        caption: result['caption']!,
                                      ),
                                    );
                                  }
                                },
                              ),
                              Text('$_reposts Reposts', style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.send, color: Colors.black),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                ),
                                builder: (context) => ShareScreen(
                                  mediaFile: meta.mediaFile,
                                  mediaType: meta.mediaType,
                                  caption: meta.description,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Description
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text(
                        meta.description ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, color: Colors.black),
                      ),
                    ),

                    // Timestamp
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
                      child: Text(
                        meta.created ?? '',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
