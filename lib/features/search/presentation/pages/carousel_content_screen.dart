// lib/features/search/presentation/pages/carousel_content_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/features/home/model/entities/feed_entity.dart';
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

class CarouselContentScreen extends StatefulWidget {
  final SearchResult result;
  const CarouselContentScreen({super.key, required this.result});

  @override
  State<CarouselContentScreen> createState() => _CarouselContentScreenState();
}

class _CarouselContentScreenState extends State<CarouselContentScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  late bool _flagLiked;
  late int _likes;
  late int _reposts;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _flagLiked = widget.result.flagLiked ?? false;
    _likes = widget.result.likesCount ?? 0;
    _reposts = widget.result.repostCount ?? 0;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  static const double _carouselHeight = 320;

  @override
  Widget build(BuildContext context) {
    final meta = widget.result;
    final items = meta.mediaItems ?? [];
    if (items.isEmpty) {
      return Scaffold(
        backgroundColor: SearchTheme.surfaceBg,
        appBar: AppBar(
          backgroundColor: SearchTheme.cardBg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: SearchTheme.textPrimary,
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(meta.name ?? '', style: SearchTheme.titleAppBar),
          centerTitle: false,
        ),
        body: Center(
          child: Text('No media', style: SearchTheme.emptyTitle),
        ),
      );
    }

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
              title: Text(meta.name ?? '', style: SearchTheme.titleAppBar, overflow: TextOverflow.ellipsis),
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
                      const SizedBox(height: SearchTheme.spacingSm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(SearchTheme.radiusMd),
                        child: SizedBox(
                        height: _carouselHeight,
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) =>
                              setState(() => _currentPage = index),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final isCurrent = index == _currentPage;
                            if (item.type == 'image') {
                              return Image.network(
                                item.mediaFile,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: _carouselHeight,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return SizedBox(
                                    height: _carouselHeight,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                (loadingProgress
                                                        .expectedTotalBytes ??
                                                    1)
                                            : null,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (_, __, ___) => Container(
                                  height: _carouselHeight,
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: Icon(Icons.broken_image_outlined,
                                        size: 48, color: Colors.grey),
                                  ),
                                ),
                              );
                            }
                            if (item.type == 'video') {
                              return _CarouselVideoTile(
                                videoUrl: item.mediaFile,
                                thumbnailUrl: item.thumbnail,
                                height: _carouselHeight,
                                isCurrentPage: isCurrent,
                              );
                            }
                            // audio or other
                            return Container(
                              height: _carouselHeight,
                              color: Colors.grey[800],
                              child: const Center(
                                child: Icon(Icons.play_circle_outline,
                                    size: 64, color: Colors.white70),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (items.length > 1) ...[
                      const SizedBox(height: SearchTheme.spacingSm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          items.length,
                          (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentPage == index
                                  ? SearchTheme.primary
                                  : SearchTheme.chipUnselectedBg,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: SearchTheme.spacingMd),
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
                        final feedMediaItems = meta.mediaItems
                            ?.map((m) => FeedMediaItem(type: m.type, mediaFile: m.mediaFile, thumbnail: m.thumbnail))
                            .toList();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(SearchTheme.radiusXl)),
                          ),
                          builder: (context) => ShareScreen(
                            mediaFile: meta.mediaFile,
                            mediaType: 'carousel',
                            title: meta.name,
                            caption: meta.description,
                            postId: meta.id,
                            mediaItems: feedMediaItems,
                          ),
                        );
                      },
                    ),
                    if (meta.description != null && meta.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: SearchTheme.spacingSm),
                        child: Text(meta.description!, maxLines: 3, overflow: TextOverflow.ellipsis, style: SearchTheme.subtitle),
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

class _CarouselVideoTile extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final double height;
  final bool isCurrentPage;

  const _CarouselVideoTile({
    required this.videoUrl,
    this.thumbnailUrl,
    required this.height,
    required this.isCurrentPage,
  });

  @override
  State<_CarouselVideoTile> createState() => _CarouselVideoTileState();
}

class _CarouselVideoTileState extends State<_CarouselVideoTile> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _error = false;
  bool _muted = false;

  @override
  void didUpdateWidget(covariant _CarouselVideoTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCurrentPage && !widget.isCurrentPage) {
      _pauseAndDispose();
    } else if (!oldWidget.isCurrentPage && widget.isCurrentPage) {
      _initVideo();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.isCurrentPage) _initVideo();
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initVideo() async {
    if (_controller != null || widget.videoUrl.isEmpty) return;
    setState(() => _error = false);
    final c =
        VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller = c;
    c.addListener(_onControllerUpdate);
    try {
      await c.initialize();
      if (!mounted) return;
      c.play();
      c.setLooping(true);
      setState(() {
        _initialized = true;
        _error = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Carousel video init error: $e');
      }
      if (!mounted) return;
      c.removeListener(_onControllerUpdate);
      setState(() {
        _initialized = false;
        _error = true;
      });
    }
  }

  void _pauseAndDispose() {
    final c = _controller;
    if (c != null) {
      c.removeListener(_onControllerUpdate);
      c.pause();
      c.dispose();
    }
    _controller = null;
    _initialized = false;
  }

  @override
  void dispose() {
    _pauseAndDispose();
    super.dispose();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _controller?.setVolume(_muted ? 0 : 1);
  }

  void _togglePlayPause() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
  }

  void _openFullscreen() {
    if (_controller == null || !_controller!.value.isInitialized) return;
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
    if (!widget.isCurrentPage) {
      return Container(
        height: widget.height,
        color: Colors.grey[800],
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.thumbnailUrl != null)
              Image.network(
                widget.thumbnailUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: widget.height,
                errorBuilder: (_, __, ___) => const SizedBox.expand(),
              ),
            const Center(
              child: Icon(Icons.play_circle_outline,
                  size: 64, color: Colors.white70),
            ),
          ],
        ),
      );
    }
    if (_error) {
      return Container(
        height: widget.height,
        color: Colors.grey[800],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: Colors.white70),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _initVideo,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (!_initialized || _controller == null) {
      return Container(
        height: widget.height,
        color: Colors.grey[800],
        child: const Center(
            child: CircularProgressIndicator(color: Colors.white70)),
      );
    }
    final c = _controller!;
    final ar = c.value.aspectRatio;
    return SizedBox(
      height: widget.height,
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(SearchTheme.radiusMd)),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _togglePlayPause,
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: ar,
                      child: VideoPlayer(c),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _CarouselVideoControlBar(
            controller: c,
            muted: _muted,
            formatTime: _formatTime,
            onPlayPause: _togglePlayPause,
            onMute: _toggleMute,
            onFullscreen: _openFullscreen,
          ),
        ],
      ),
    );
  }
}

/// Compact control bar for carousel video: play, time, seek, time, mute, fullscreen.
class _CarouselVideoControlBar extends StatelessWidget {
  final VideoPlayerController controller;
  final bool muted;
  final String Function(Duration) formatTime;
  final VoidCallback onPlayPause;
  final VoidCallback onMute;
  final VoidCallback onFullscreen;

  const _CarouselVideoControlBar({
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
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: SearchTheme.searchBarFill,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(SearchTheme.radiusMd)),
        border: Border(top: BorderSide(color: SearchTheme.divider, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPlayPause,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: SearchTheme.primary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              formatTime(position),
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: SearchTheme.caption.copyWith(
                color: SearchTheme.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2.5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
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
          const SizedBox(width: 4),
          SizedBox(
            width: 40,
            child: Text(
              formatTime(duration),
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: SearchTheme.caption.copyWith(
                color: SearchTheme.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onMute,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: SearchTheme.primary,
                size: 20,
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onFullscreen,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.fullscreen_rounded, color: SearchTheme.primary, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
