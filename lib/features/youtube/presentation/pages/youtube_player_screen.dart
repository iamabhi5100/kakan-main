import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:kakan/features/youtube/domain/entities/video_entity.dart';
import 'package:kakan/core/utils/text_sanitizer.dart';

class YoutubePlayerScreen extends StatefulWidget {
  final VideoEntity video;
  final bool isShort;

  const YoutubePlayerScreen({Key? key, required this.video, this.isShort = false}) : super(key: key);

  @override
  _YoutubePlayerScreenState createState() => _YoutubePlayerScreenState();
}

class _YoutubePlayerScreenState extends State<YoutubePlayerScreen> {
  late final YoutubePlayerController _ytController;

  @override
  void initState() {
    super.initState();
    final id = YoutubePlayer.convertUrlToId(widget.video.id) ?? widget.video.id;
    _ytController = YoutubePlayerController(
      initialVideoId: id,
      flags: YoutubePlayerFlags(
        autoPlay: false,
        controlsVisibleAtStart: true,
        enableCaption: true,
        showLiveFullscreenButton: !widget.isShort,
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

    final safeTitle = TextSanitizer.safe(widget.video.title);
    final safeChannel = TextSanitizer.safe(widget.video.channelTitle);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          safeTitle,
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
        builder: (context, player) {
          final infoColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                safeTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_formatViews(widget.video.viewCount)} • $safeChannel',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton.icon(
                  onPressed: () {
                    _ytController.pause();
                    context.push('/video-detail', extra: widget.video);
                  },
                  icon: const Icon(Icons.download_rounded, color: Colors.white),
                  label: Text(
                    'Download Video',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          );

          if (widget.isShort) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  AspectRatio(aspectRatio: 9 / 16, child: player),
                  Padding(padding: const EdgeInsets.all(16), child: infoColumn),
                ],
              ),
            );
          } else {
            return Column(
              children: [
                AspectRatio(aspectRatio: 16 / 9, child: player),
                Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: infoColumn)),
              ],
            );
          }
        },
      ),
    );
  }

  String _formatViews(int views) {
    if (views >= 1000000000) return "${(views / 1e9).toStringAsFixed(1)}B views";
    if (views >= 1000000) return "${(views / 1e6).toStringAsFixed(1)}M views";
    if (views >= 1000) return "${(views / 1e3).toStringAsFixed(1)}K views";
    return "$views views";
  }
}