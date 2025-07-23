// lib/features/youtube/presentation/youtube_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:kakan/features/youtube/domain/entities/video_entity.dart';
import 'package:kakan/features/youtube/presentation/bloc/youtube_bloc.dart';
import 'package:kakan/features/youtube/presentation/bloc/youtube_event.dart';
import 'package:kakan/features/youtube/presentation/bloc/youtube_state.dart';
import 'package:kakan/features/youtube/presentation/widgets/searchbar_youtube_widget.dart';

class YoutubeDashboardScreen extends StatefulWidget {
  const YoutubeDashboardScreen({Key? key}) : super(key: key);

  @override
  State<YoutubeDashboardScreen> createState() => _YoutubeDashboardScreenState();
}

class _YoutubeDashboardScreenState extends State<YoutubeDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Trigger initial load of "trending" videos
    context.read<YoutubeBloc>().add(FetchHomeVideosEvent());
  }

  void _onSearch(String query) {
    context.read<YoutubeBloc>().add(SearchVideosEvent(query));
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
            const Icon(Icons.play_circle_filled, color: Colors.red, size: 30),
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
              backgroundImage: const AssetImage('assets/images/avatar1.png'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
            child: SearchbarYoutubeWidget(onSearch: _onSearch),
          ),
          // Video list
          Expanded(
            child: BlocBuilder<YoutubeBloc, YoutubeState>(
              builder: (context, state) {
                if (state is YoutubeLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is YoutubeError) {
                  return Center(child: Text('Error: ${state.message}'));
                }
                if (state is YoutubeLoaded) {
                  if (state.videos.isEmpty) {
                    return const Center(child: Text('No videos found'));
                  }
                  return ListView.separated(
                    key: const PageStorageKey('youtubeFeed'),
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: state.videos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final video = state.videos[index];
                      return _YoutubeFeedItem(
                        video: video,
                        onTap: () {
                          context.push('/youtube-player', extra: video);
                        },
                      );
                    },
                  );
                }
                // Initial / fallback
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _YoutubeFeedItem extends StatelessWidget {
  final VideoEntity video;
  final VoidCallback onTap;
  const _YoutubeFeedItem({
    Key? key,
    required this.video,
    required this.onTap,
  }) : super(key: key);

  String _formatViews(int views) {
    if (views >= 1e9) return "${(views / 1e9).toStringAsFixed(1)}B views";
    if (views >= 1e6) return "${(views / 1e6).toStringAsFixed(1)}M views";
    if (views >= 1e3) return "${(views / 1e3).toStringAsFixed(1)}K views";
    return "$views views";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: video.thumbnailUrl != null
                    ? Image.network(
                        video.thumbnailUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Colors.grey,
                          child: Center(child: Icon(Icons.broken_image)),
                        ),
                      )
                    : const ColoredBox(
                        color: Colors.grey,
                        child: Center(child: Icon(Icons.video_library)),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            // Title & metadata
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar (first letter of channel)
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isDark
                      ? Colors.grey.shade800
                      : Colors.grey.shade300,
                  child: Text(
                    video.channelTitle.isNotEmpty
                        ? video.channelTitle[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Texts
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Video title
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
                      // Channel • views
                      Text(
                        '${video.channelTitle} • ${_formatViews(video.viewCount)}',
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // More button (no action)
                IconButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: isDark ? Colors.white : Colors.black54,
                  ),
                  onPressed: () {},
                  splashRadius: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
