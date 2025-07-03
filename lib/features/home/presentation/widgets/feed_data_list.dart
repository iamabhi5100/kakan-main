import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/features/home/model/entities/feed_entity.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_bloc.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_event.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_state.dart';
import 'package:video_player/video_player.dart';
import 'package:kakan/core/utils/media_manager.dart';
import 'package:kakan/features/share/presentation/share_screen.dart'; // Import ShareScreen
import 'package:kakan/injection_container.dart' as di;

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
    return BlocBuilder<FeedBloc, FeedState>(
      builder: (context, state) {
        if (state is FeedLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is FeedLoaded) {
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.feeds.length,
            itemBuilder: (context, index) {
              final feed = state.feeds[index];
              return FeedItemWidget(feed: feed);
            },
          );
        } else if (state is FeedError) {
          return Center(child: Text(state.message));
        }
        return const SizedBox.shrink();
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
  bool _isExpanded = false;
  bool _isLiked = false;
  int _likeCount = 100; // Placeholder, should come from API
  int _repostCount = 5; // Placeholder, should come from API

  @override
  void initState() {
    super.initState();
    if (widget.feed.mediaType == 'video' && widget.feed.mediaFile.isNotEmpty) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.feed.mediaFile))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            MediaManager().setVideoController(_controller!);
          }
        });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _truncateCaption(String caption) {
    if (caption.length > 50 && !_isExpanded) {
      return '${caption.substring(0, 50)}...';
    }
    return caption;
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
                CircleAvatar(
                  radius: 20,
                  backgroundImage: widget.feed.userProfileDetails.profileImage != null
                      ? NetworkImage(widget.feed.userProfileDetails.profileImage!)
                      : null,
                  child: widget.feed.userProfileDetails.profileImage == null
                      ? Text(
                          widget.feed.userProfileDetails.username[0].toUpperCase(),
                          style: const TextStyle(fontSize: 20),
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
                  onPressed: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (widget.feed.mediaType == 'video' && _controller != null && _controller!.value.isInitialized)
            AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(_controller!),
                  IconButton(
                    icon: Icon(
                      _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
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
          else if (widget.feed.thumbnail != null)
            Image.network(
              widget.feed.thumbnail!,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? Colors.red : Colors.black,
                  ),
                  onPressed: () {
                    setState(() {
                      _isLiked = !_isLiked;
                      _likeCount += _isLiked ? 1 : -1;
                    });
                  },
                ),
                Text('$_likeCount Likes'),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.repeat),
                  onPressed: () {
                    setState(() {
                      _repostCount += 1;
                    });
                  },
                ),
                Text('$_repostCount Reposts'),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const ShareScreen(),
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
                          const TextSpan(
                            text: ' ',
                          ),
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
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
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