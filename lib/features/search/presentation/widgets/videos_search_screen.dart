import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/features/search/presentation/bloc/combined_search/combined_search_bloc.dart';
import 'package:kakan/features/search/presentation/bloc/combined_search/combined_search_state.dart';
import 'package:kakan/features/search/presentation/theme/search_theme.dart';
import 'package:kakan/features/search/presentation/pages/carousel_content_screen.dart';
import 'package:kakan/features/search/presentation/pages/image_content_screen.dart';
import 'package:kakan/features/search/presentation/pages/video_content_screen.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class VideosSearchScreen extends StatelessWidget {
  const VideosSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CombinedSearchBloc, CombinedSearchState>(
      builder: (context, state) {
        if (state is SearchLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(SearchTheme.spacingXXl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: SearchTheme.primary,
                    ),
                  ),
                  SizedBox(height: SearchTheme.spacingLg),
                  Text('Searching…', style: SearchTheme.emptySubtitle),
                ],
              ),
            ),
          );
        }
        if (state is SearchLoaded) {
          final videos = state.videos;
          if (videos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(SearchTheme.spacingXXl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam_off_rounded, size: 64, color: SearchTheme.textMuted),
                    const SizedBox(height: SearchTheme.spacingLg),
                    Text('No videos found', style: SearchTheme.emptyTitle),
                    const SizedBox(height: SearchTheme.spacingSm),
                    Text(
                      'Try a different search term',
                      style: SearchTheme.emptySubtitle,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: SearchTheme.spacingLg,
              vertical: SearchTheme.spacingSm,
            ),
            itemCount: videos.length,
            separatorBuilder: (_, __) => const SizedBox(height: SearchTheme.spacingSm),
            itemBuilder: (ctx, index) {
              final r = videos[index];
              return _MediaTile(
                result: r,
                onTap: () {
                  final isCarousel = r.mediaItems != null && r.mediaItems!.length > 1;
                  final isImage = r.mediaType == 'image';
                  Widget screen;
                  if (isCarousel) {
                    screen = CarouselContentScreen(result: r);
                  } else if (isImage) {
                    screen = ImageContentScreen(result: r);
                  } else {
                    screen = VideoContentScreen(video: r);
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => screen),
                  );
                },
              );
            },
          );
        }
        if (state is SearchError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(SearchTheme.spacingXXl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded, size: 48, color: SearchTheme.likeRed),
                  const SizedBox(height: SearchTheme.spacingLg),
                  Text(state.message, style: SearchTheme.errorText, textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(SearchTheme.spacingXXl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam_outlined, size: 64, color: SearchTheme.textMuted),
                const SizedBox(height: SearchTheme.spacingLg),
                Text('Search videos', style: SearchTheme.emptyTitle),
                const SizedBox(height: SearchTheme.spacingSm),
                Text(
                  'Results will appear here',
                  style: SearchTheme.emptySubtitle,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MediaTile extends StatelessWidget {
  final dynamic result;
  final VoidCallback onTap;

  const _MediaTile({required this.result, required this.onTap});

  /// Thumbnail for list: use API thumbnail, or image mediaFile, or first image/carousel frame.
  String? get _effectiveThumbnailUrl {
    if (result.thumbnail != null && result.thumbnail!.isNotEmpty) return result.thumbnail;
    if (result.mediaType == 'image' && result.mediaFile != null && result.mediaFile!.isNotEmpty) {
      return result.mediaFile;
    }
    final items = result.mediaItems;
    if (items != null && items.isNotEmpty) {
      for (final m in items) {
        if (m.type == 'image' && m.mediaFile.isNotEmpty) return m.mediaFile;
      }
      final first = items.first;
      if (first.thumbnail != null && first.thumbnail!.isNotEmpty) return first.thumbnail;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isCarousel = result.mediaItems != null && result.mediaItems!.length > 1;
    final isImage = result.mediaType == 'image';
    IconData typeIcon = Icons.videocam_rounded;
    String typeLabel = 'Video';
    if (isCarousel) {
      typeIcon = Icons.collections_rounded;
      typeLabel = 'Carousel';
    } else if (isImage) {
      typeIcon = Icons.image_rounded;
      typeLabel = 'Image';
    }

    final thumbUrl = _effectiveThumbnailUrl;
    final isVideo = result.mediaType == 'video';
    final videoUrl = result.mediaFile != null && result.mediaFile!.isNotEmpty ? result.mediaFile! : null;

    return Material(
      color: SearchTheme.cardBg,
      borderRadius: BorderRadius.circular(SearchTheme.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(SearchTheme.spacingSm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(SearchTheme.radiusMd),
                child: thumbUrl != null && thumbUrl.isNotEmpty
                    ? Image.network(
                        thumbUrl,
                        width: SearchTheme.listThumbSize,
                        height: SearchTheme.listThumbSize,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return SizedBox(
                            width: SearchTheme.listThumbSize,
                            height: SearchTheme.listThumbSize,
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded / (progress.expectedTotalBytes ?? 1)
                                      : null,
                                ),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => _placeholder(typeIcon),
                      )
                    : isVideo && videoUrl != null
                        ? _VideoThumbnailImage(
                            videoUrl: videoUrl,
                            size: SearchTheme.listThumbSize,
                            placeholder: _placeholder(typeIcon),
                          )
                        : _placeholder(typeIcon),
              ),
              const SizedBox(width: SearchTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      result.name ?? 'Untitled',
                      style: SearchTheme.titleCard,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: SearchTheme.spacingXs),
                    Text(
                      result.description ?? '',
                      style: SearchTheme.caption.copyWith(color: SearchTheme.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: SearchTheme.spacingXs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: SearchTheme.searchBarFill,
                        borderRadius: BorderRadius.circular(SearchTheme.radiusSm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(typeIcon, size: 12, color: SearchTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            typeLabel,
                            style: SearchTheme.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: SearchTheme.textMuted, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(IconData icon) {
    return Container(
      width: SearchTheme.listThumbSize,
      height: SearchTheme.listThumbSize,
      color: SearchTheme.divider,
      child: Icon(icon, color: SearchTheme.textMuted, size: 32),
    );
  }
}

/// In-memory cache for generated video thumbnails (URL -> image bytes).
final Map<String, Uint8List?> _videoThumbCache = {};
final Set<String> _videoThumbFailed = {};

class _VideoThumbnailImage extends StatefulWidget {
  final String videoUrl;
  final double size;
  final Widget placeholder;

  const _VideoThumbnailImage({
    required this.videoUrl,
    required this.size,
    required this.placeholder,
  });

  @override
  State<_VideoThumbnailImage> createState() => _VideoThumbnailImageState();
}

class _VideoThumbnailImageState extends State<_VideoThumbnailImage> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(covariant _VideoThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    final url = widget.videoUrl;
    if (_videoThumbCache.containsKey(url)) {
      if (mounted) {
        setState(() {
          _bytes = _videoThumbCache[url];
          _loading = false;
          _failed = _bytes == null;
        });
      }
      return;
    }
    if (_videoThumbFailed.contains(url)) {
      if (mounted) setState(() { _loading = false; _failed = true; });
      return;
    }
    try {
      final data = await VideoThumbnail.thumbnailData(
        video: url,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 256,
        quality: 60,
        timeMs: 0,
      );
      if (url == widget.videoUrl) {
        _videoThumbCache[url] = data;
        if (data == null) _videoThumbFailed.add(url);
        if (mounted) {
          setState(() {
            _bytes = data;
            _loading = false;
            _failed = data == null;
          });
        }
      }
    } catch (_) {
      if (url == widget.videoUrl) _videoThumbFailed.add(url);
      if (mounted) setState(() { _loading = false; _failed = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: SearchTheme.primary),
          ),
        ),
      );
    }
    if (_failed || _bytes == null || _bytes!.isEmpty) {
      return widget.placeholder;
    }
    return Image.memory(
      _bytes!,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.cover,
    );
  }
}
