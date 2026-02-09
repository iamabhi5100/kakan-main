import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:kakan/config/constant_api.dart';
import 'package:kakan/config/theme.dart';
import 'package:kakan/features/myfiles/domain/entities/download_entity.dart';
import 'package:video_player/video_player.dart';

/// Standalone video post widget for My Files. Plays a single video with
/// play/pause, timeline/seek bar, and title. No feed blocs, like, comment, or share.
class VideoPost extends StatefulWidget {
  final DownloadEntity download;

  const VideoPost({super.key, required this.download});

  @override
  State<VideoPost> createState() => _VideoPostState();
}

class _VideoPostState extends State<VideoPost> {
  late VideoPlayerController _controller;

  static String _normalizeMediaUrl(String url) {
    if (url.isEmpty) return url;
    final t = url.trim();
    if (t.startsWith('http://') || t.startsWith('https://')) return t;
    if (t.startsWith('/') && !t.startsWith('//')) return '${ConstantApi.baseUrl}$t';
    return t;
  }

  static String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:$m:$s';
    }
    return '$m:$s';
  }

  @override
  void initState() {
    super.initState();
    if (widget.download.mediaFile != null && widget.download.mediaFile!.isNotEmpty) {
      final url = _normalizeMediaUrl(widget.download.mediaFile!);
      _controller = VideoPlayerController.networkUrl(Uri.parse(url))
        ..initialize().then((_) {
          if (mounted) {
            _controller.addListener(_onControllerUpdate);
            setState(() {});
          }
        }).catchError((error) {
          if (kDebugMode) {
            print('VideoPost: Error initializing video: $error');
          }
        });
    } else {
      _controller = VideoPlayerController.networkUrl(Uri.parse(''));
    }
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  void _seekTo(Duration position) {
    _controller.seekTo(position);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Video card with rounded corners and shadow
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_controller.value.isInitialized)
                  AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        GestureDetector(
                          onTap: _togglePlayPause,
                          child: VideoPlayer(_controller),
                        ),
                        // Center play button: only when paused (so it doesn't block view when playing)
                        if (!_controller.value.isPlaying)
                          Center(
                            child: Material(
                              color: Colors.white.withValues(alpha: 0.92),
                              shape: const CircleBorder(),
                              elevation: 4,
                              child: InkWell(
                                onTap: _togglePlayPause,
                                customBorder: const CircleBorder(),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Icon(
                                    Icons.play_arrow_rounded,
                                    color: appTheme.primaryColor,
                                    size: 48,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Bottom timeline bar (like audio page)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.7),
                                ],
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        _controller.value.isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                      onPressed: _togglePlayPause,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                    ),
                                    const Gap(8),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          SliderTheme(
                                            data: SliderTheme.of(context).copyWith(
                                              activeTrackColor: Colors.white,
                                              inactiveTrackColor: Colors.white.withValues(alpha: 0.4),
                                              thumbColor: Colors.white,
                                              overlayColor: Colors.white.withValues(alpha: 0.2),
                                              trackHeight: 3,
                                            ),
                                            child: Slider(
                                              value: _controller.value.duration.inMilliseconds > 0
                                                  ? (_controller.value.position.inMilliseconds /
                                                      _controller.value.duration.inMilliseconds)
                                                      .clamp(0.0, 1.0)
                                                  : 0,
                                              onChanged: (v) {
                                                final ms = (_controller.value.duration.inMilliseconds * v).round();
                                                _seekTo(Duration(milliseconds: ms));
                                              },
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(left: 12, right: 12),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  _formatDuration(_controller.value.position),
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                Text(
                                                  _formatDuration(_controller.value.duration),
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Gap(20),
          // Info card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: appTheme.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Video',
                        style: appTheme.textTheme.bodySmall?.copyWith(
                          color: appTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Gap(12),
                    if (widget.download.duration != null &&
                        widget.download.duration!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const Gap(4),
                          Text(
                            widget.download.duration!,
                            style: appTheme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const Gap(12),
                Text(
                  widget.download.title ?? 'Untitled Video',
                  style: appTheme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
