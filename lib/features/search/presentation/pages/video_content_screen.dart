// lib/features/search/presentation/pages/video_content_screen.dart
// Fresh layout: video only (no overlay) + dedicated player control bar below.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_bloc.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_event.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_state.dart';
import 'package:kakan/features/home/presentation/widgets/share_screen.dart';
import 'package:kakan/features/search/domain/entities/search_result.dart';
import 'package:kakan/features/search/presentation/pages/search_fullscreen_video_page.dart';
import 'package:kakan/features/search/presentation/theme/search_theme.dart';
import 'package:kakan/features/search/presentation/widgets/search_content_layout.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:toastification/toastification.dart';
import 'package:video_player/video_player.dart';

class VideoContentScreen extends StatefulWidget {
  final SearchResult video;
  const VideoContentScreen({super.key, required this.video});

  @override
  State<VideoContentScreen> createState() => _VideoContentScreenState();
}

class _VideoContentScreenState extends State<VideoContentScreen> {
  late final VideoPlayerController _controller;
  late final Future<void> _initFuture;
  bool _initialized = false;
  bool _flagLiked = false;
  int _likes = 0;
  int _reposts = 0;
  bool _muted = false;

  void _onControllerUpdate() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _flagLiked = widget.video.flagLiked ?? false;
    _likes = widget.video.likesCount ?? 0;
    _reposts = widget.video.repostCount ?? 0;
    final url = widget.video.mediaFile ?? '';
    _controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller.addListener(_onControllerUpdate);
    _initFuture = _controller.initialize().then((_) {
      if (!mounted) return;
      _controller.play();
      _controller.setLooping(true);
      setState(() => _initialized = true);
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (!_controller.value.isInitialized) return;
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
      _controller.setVolume(_muted ? 0 : 1);
    });
  }

  void _openFullscreen() {
    if (!_controller.value.isInitialized) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => SearchFullscreenVideoPage(controller: _controller),
      ),
    );
  }

  static String _formatTime(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final meta = widget.video;

    return BlocProvider(
      create: (_) => di.sl<FeedBloc>(),
      child: Builder(
        builder: (providerContext) => BlocListener<FeedBloc, FeedState>(
          listener: (context, state) {
            if (state is FeedActionSuccess && mounted) {
              toastification.show(
                context: context,
                title: Text(state.newPostId != null ? 'Repost created successfully' : 'Action completed successfully'),
                type: ToastificationType.success,
                style: ToastificationStyle.fillColored,
                autoCloseDuration: const Duration(seconds: 3),
              );
              if (state.newPostId != null) {
                context.read<FeedBloc>().add(const RefreshFeedsEvent());
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
          child: Scaffold(
            backgroundColor: SearchTheme.surfaceBg,
            appBar: AppBar(
              backgroundColor: SearchTheme.cardBg,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                color: SearchTheme.textPrimary,
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                meta.name ?? '',
                style: SearchTheme.titleAppBar,
                overflow: TextOverflow.ellipsis,
              ),
              centerTitle: false,
            ),
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: SearchTheme.spacingLg),
                child: searchContentCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SearchContentProfileRow(meta: meta),
                      const SizedBox(height: SearchTheme.spacingMd),
                      // 1) Video only – no overlay
                      _VideoOnlySection(
                        controller: _controller,
                        initFuture: _initFuture,
                        initialized: _initialized,
                        onTapVideo: _togglePlayPause,
                      ),
                      const SizedBox(height: 0),
                      // 2) Dedicated control bar below video (play, timeline, mute, fullscreen)
                      _PlayerControlBar(
                        controller: _controller,
                        muted: _muted,
                        formatTime: _formatTime,
                        onPlayPause: _togglePlayPause,
                        onMute: _toggleMute,
                        onFullscreen: _openFullscreen,
                      ),
                      const SizedBox(height: SearchTheme.spacingLg),
                      SearchContentActionRow(
                        flagLiked: _flagLiked,
                        likes: _likes,
                        reposts: _reposts,
                        onLike: () {
                          setState(() {
                            _flagLiked = !_flagLiked;
                            _likes = _flagLiked ? _likes + 1 : _likes - 1;
                          });
                          providerContext.read<FeedBloc>().add(LikeDislikePostEvent(postId: meta.id));
                        },
                        onRepost: () async {
                          final titleController = TextEditingController(text: '${meta.name ?? 'Repost'} (Repost)');
                          final captionController = TextEditingController(text: meta.description);
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
                                  onPressed: () => Navigator.pop(dialogContext, {'title': titleController.text, 'caption': captionController.text}),
                                  child: const Text('Repost'),
                                ),
                              ],
                            ),
                          );
                          if (result != null && context.mounted) {
                            providerContext.read<FeedBloc>().add(
                              RepostEvent(postId: meta.id, title: result['title']!, caption: result['caption']!),
                            );
                          }
                        },
                        onShare: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(SearchTheme.radiusXl)),
                            ),
                            builder: (context) => ShareScreen(
                              mediaFile: meta.mediaFile,
                              mediaType: meta.mediaType,
                              title: meta.name,
                              caption: meta.description,
                              postId: meta.id,
                            ),
                          );
                        },
                      ),
                      if (meta.description != null && meta.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: SearchTheme.spacingSm),
                          child: Text(
                            meta.description!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: SearchTheme.subtitle,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: SearchTheme.spacingMd),
                        child: Text(meta.created ?? '', style: SearchTheme.caption),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Video only – no controls on top. Tap toggles play/pause.
class _VideoOnlySection extends StatelessWidget {
  final VideoPlayerController controller;
  final Future<void> initFuture;
  final bool initialized;
  final VoidCallback onTapVideo;

  const _VideoOnlySection({
    required this.controller,
    required this.initFuture,
    required this.initialized,
    required this.onTapVideo,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(SearchTheme.radiusMd)),
      child: FutureBuilder<void>(
        future: initFuture,
        builder: (context, snapshot) {
          final hasError = snapshot.hasError;
          final notReady = !initialized && snapshot.connectionState != ConnectionState.done;
          if (hasError || notReady) {
            return Container(
              height: 220,
              width: double.infinity,
              color: SearchTheme.divider,
              child: Center(
                child: hasError
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.videocam_off_rounded, size: 40, color: SearchTheme.textMuted),
                          const SizedBox(height: 8),
                          Text('Video failed to load', style: SearchTheme.caption),
                        ],
                      )
                    : SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(strokeWidth: 2, color: SearchTheme.primary),
                      ),
              ),
            );
          }
          if (!controller.value.isInitialized) {
            return Container(
              height: 220,
              width: double.infinity,
              color: SearchTheme.divider,
              child: Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2, color: SearchTheme.primary),
                ),
              ),
            );
          }
          final ar = controller.value.aspectRatio;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTapVideo,
            child: AspectRatio(
              aspectRatio: ar,
              child: Container(
                color: Colors.black,
                child: Center(child: VideoPlayer(controller)),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Clean control bar below video: single row – play | time | seek | time | mute | fullscreen.
class _PlayerControlBar extends StatelessWidget {
  final VideoPlayerController controller;
  final bool muted;
  final String Function(Duration) formatTime;
  final VoidCallback onPlayPause;
  final VoidCallback onMute;
  final VoidCallback onFullscreen;

  const _PlayerControlBar({
    required this.controller,
    required this.muted,
    required this.formatTime,
    required this.onPlayPause,
    required this.onMute,
    required this.onFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final position = controller.value.position;
    final duration = controller.value.duration;
    final totalMs = duration.inMilliseconds.toDouble();
    final posMs = totalMs > 0 ? position.inMilliseconds.toDouble().clamp(0.0, totalMs) : 0.0;
    final isPlaying = controller.value.isPlaying;
    final initialized = controller.value.isInitialized;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SearchTheme.spacingLg, vertical: SearchTheme.spacingMd),
      decoration: BoxDecoration(
        color: SearchTheme.searchBarFill,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(SearchTheme.radiusMd)),
        border: Border(top: BorderSide(color: SearchTheme.divider, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Play / Pause
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPlayPause,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: SearchTheme.primary,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: SearchTheme.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Current time (fixed width so "00:00" stays on one line)
            SizedBox(
              width: 44,
              child: Text(
                formatTime(position),
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: SearchTheme.caption.copyWith(
                  color: SearchTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Seek bar
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: SearchTheme.primary,
                  inactiveTrackColor: SearchTheme.divider,
                  thumbColor: SearchTheme.primary,
                ),
                child: Slider(
                  value: posMs,
                  max: totalMs > 0 ? totalMs : 1,
                  onChanged: initialized
                      ? (v) => controller.seekTo(Duration(milliseconds: v.round()))
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Duration (fixed width so "00:00" stays on one line)
            SizedBox(
              width: 44,
              child: Text(
                formatTime(duration),
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: SearchTheme.caption.copyWith(
                  color: SearchTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _ControlBtn(icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, onTap: onMute),
            const SizedBox(width: 4),
            _ControlBtn(icon: Icons.fullscreen_rounded, onTap: onFullscreen),
          ],
        ),
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ControlBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, color: SearchTheme.primary, size: 22),
      ),
    );
  }
}
