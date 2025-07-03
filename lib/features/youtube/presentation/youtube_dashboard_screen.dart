import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/features/youtube/domain/entities/video_entity.dart';
import 'package:kakan/features/youtube/presentation/bloc/youtube_bloc.dart';
import 'package:kakan/features/youtube/presentation/bloc/youtube_event.dart';
import 'package:kakan/features/youtube/presentation/bloc/youtube_state.dart';
import 'package:go_router/go_router.dart';

class YoutubeDashboardScreen extends StatefulWidget {
  const YoutubeDashboardScreen({Key? key}) : super(key: key);

  @override
  State<YoutubeDashboardScreen> createState() => _YoutubeDashboardScreenState();
}

class _YoutubeDashboardScreenState extends State<YoutubeDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<YoutubeBloc>().add(FetchHomeVideosEvent());
  }

  void _onSearch(String query) {
    if (query.isNotEmpty) {
      context.read<YoutubeBloc>().add(SearchVideosEvent(query));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            Icon(Icons.play_circle_filled, color: Colors.red, size: 30),
            const SizedBox(width: 8),
            Text(
              'YouTube',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: -1.5,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: CircleAvatar(
              radius: 16,
              backgroundImage: AssetImage(
                'assets/images/avatar1.png',
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
            child: _YoutubeSearchBar(
              controller: _searchController,
              onSearch: _onSearch,
            ),
          ),
          Expanded(
            child: BlocBuilder<YoutubeBloc, YoutubeState>(
              builder: (context, state) {
                if (state is YoutubeLoading) {
                  // Show loading when loading
                  return const Center(child: CircularProgressIndicator());
                } else if (state is YoutubeLoaded) {
                  // Show videos if loaded
                  if (state.videos.isEmpty) {
                    return const Center(child: Text('No videos found'));
                  }
                  return ListView.separated(
                    itemCount: state.videos.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 0, color: Colors.transparent),
                    itemBuilder: (context, index) {
                      final video = state.videos[index];
                      return YoutubeFeedItem(
                        video: video,
                        onTap: () {
                          context.push(
                            '/video-detail',
                            extra: video,
                          );
                        },
                      );
                    },
                  );
                } else if (state is YoutubeError) {
                  return Center(child: Text(state.message));
                }
                // Show loading by default (on initial state)
                return const Center(child: CircularProgressIndicator());
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- Modern YouTube-style search bar ---
class _YoutubeSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String) onSearch;

  const _YoutubeSearchBar({
    Key? key,
    required this.controller,
    required this.onSearch,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(28),
      child: TextField(
        controller: controller,
        onSubmitted: onSearch,
        style: TextStyle(
          fontSize: 16,
          color: isDark ? Colors.white : Colors.black,
        ),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: "Search YouTube",
          hintStyle: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[700],
          ),
          filled: true,
          fillColor: isDark ? Colors.grey[900] : Colors.grey[200],
          prefixIcon: Icon(
            Icons.search,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  onPressed: () {
                    controller.clear();
                  },
                )
              : null,
        ),
      ),
    );
  }
}

class YoutubeFeedItem extends StatelessWidget {
  final VideoEntity video;
  final VoidCallback onTap;

  const YoutubeFeedItem({super.key, required this.video, required this.onTap});

  Widget _buildAvatar(BuildContext context) {
    final theme = Theme.of(context);
    return CircleAvatar(
      backgroundColor: theme.colorScheme.secondary.withOpacity(0.2),
      radius: 22,
      child: Text(
        (video.channelTitle.isNotEmpty
            ? video.channelTitle[0].toUpperCase()
            : "?"),
        style: TextStyle(
          color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
    );
  }

  String _formatViews(int views) {
    if (views >= 1000000000)
      return "${(views / 1000000000).toStringAsFixed(1)}B views";
    if (views >= 1000000)
      return "${(views / 1000000).toStringAsFixed(1)}M views";
    if (views >= 1000) return "${(views / 1000).toStringAsFixed(1)}K views";
    return "$views views";
  }

  String _publishedAgo(String? publishedDate) {
    if (publishedDate == null || publishedDate.isEmpty) return "";
    try {
      final dt = DateTime.parse(publishedDate);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays >= 365) {
        final years = (diff.inDays / 365).floor();
        return "$years year${years > 1 ? 's' : ''} ago";
      } else if (diff.inDays >= 30) {
        final months = (diff.inDays / 30).floor();
        return "$months month${months > 1 ? 's' : ''} ago";
      } else if (diff.inDays >= 1) {
        return "${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago";
      } else if (diff.inHours >= 1) {
        return "${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago";
      } else if (diff.inMinutes >= 1) {
        return "${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago";
      } else {
        return "Just now";
      }
    } catch (_) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: video.thumbnailUrl != null && video.thumbnailUrl!.isNotEmpty
                    ? Image.network(
                        video.thumbnailUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[300],
                          child: Icon(
                            Icons.broken_image,
                            size: 60,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey[300],
                        child: Icon(
                          Icons.video_library,
                          size: 60,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvatar(context),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                video.channelTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[800],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text('•', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 5),
                            Text(
                              _formatViews(video.viewCount),
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[800],
                                fontSize: 13,
                              ),
                            ),
                            if (video.publishedDate != null &&
                                video.publishedDate!.isNotEmpty) ...[
                              const SizedBox(width: 5),
                              const Text('•', style: TextStyle(fontSize: 13)),
                              const SizedBox(width: 5),
                              Text(
                                _publishedAgo(video.publishedDate),
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[800],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.more_vert,
                      color: isDark ? Colors.white : Colors.black54,
                      size: 22,
                    ),
                    onPressed: () {},
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
