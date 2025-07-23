// lib/features/youtube/presentation/pages/youtube_player_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:kakan/features/youtube/domain/entities/video_entity.dart';

class YoutubePlayerScreen extends StatefulWidget {
  final VideoEntity video;
  const YoutubePlayerScreen({Key? key, required this.video}) : super(key: key);

  @override
  _YoutubePlayerScreenState createState() => _YoutubePlayerScreenState();
}

class _YoutubePlayerScreenState extends State<YoutubePlayerScreen> {
  late final YoutubePlayerController _ytController;

  @override
  void initState() {
    super.initState();
    // Use the ID (either the URL or the raw id)
    final id = YoutubePlayer.convertUrlToId(widget.video.id) ?? widget.video.id;

    _ytController = YoutubePlayerController(
      initialVideoId: id,
      flags: const YoutubePlayerFlags(
        autoPlay: false,            // <-- DON'T autoplay
        controlsVisibleAtStart: true,
        enableCaption: true,
      ),
    );
  }

  @override
  void dispose() {
    _ytController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.video.title,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: YoutubePlayerBuilder(
        player: YoutubePlayer(
          controller: _ytController,
          showVideoProgressIndicator: true,
          progressIndicatorColor: accent,
        ),
        builder: (context, player) => Column(
          children: [
            // The YouTube player
            player,

            // Video info + download button
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.video.title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_formatViews(widget.video.viewCount)} • ${widget.video.channelTitle}',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Download button – pauses video first
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Pause the player before navigating away
                          _ytController.pause();
                          context.push(
                            '/video-detail',
                            extra: widget.video,
                          );
                        },
                        icon: const Icon(
                          Icons.download_rounded,
                          color: Colors.white,
                        ),
                        label: Text(
                          'Download Video',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatViews(int views) {
    if (views >= 1000000000) {
      return "${(views / 1e9).toStringAsFixed(1)}B views";
    }
    if (views >= 1000000) {
      return "${(views / 1e6).toStringAsFixed(1)}M views";
    }
    if (views >= 1000) {
      return "${(views / 1e3).toStringAsFixed(1)}K views";
    }
    return "$views views";
  }
}
