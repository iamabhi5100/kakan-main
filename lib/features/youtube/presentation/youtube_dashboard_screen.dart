  // lib/features/youtube/presentation/youtube_dashboard_screen.dart

  import 'package:flutter/material.dart';
  import 'package:flutter_bloc/flutter_bloc.dart';
  import 'package:go_router/go_router.dart';

  import 'package:kakan/features/youtube/domain/entities/video_entity.dart';
  import 'package:kakan/features/youtube/model/video.dart';
  import 'package:kakan/features/youtube/model/youtube_home_model.dart';
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
              const SizedBox(width: 8),
              // Constrain the logo to stay within AppBar height
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: kToolbarHeight * 0.8,
                  maxWidth: 56,
                ),
                child: Image.asset(
                  'assets/images/youtubelogo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'YouTube',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto',
                    fontSize: 22,
                    letterSpacing: -1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
              child: SearchbarYoutubeWidget(onSearch: _onSearch),
            ),
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
                    if (state.contents.isEmpty) {
                      return const Center(child: Text('No videos found'));
                    }
                    return ListView.separated(
                      key: const PageStorageKey('youtubeFeed'),
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: state.contents.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final content = state.contents[index];
                        if (content.type == 'video' && content.video != null) {
                          return _YoutubeFeedItem(
                            video: content.video!.toEntity(),
                            onTap: () {
                              context.push('/youtube-player', extra: {
                                'video': content.video!.toEntity(),
                                'isShort': false
                              });
                            },
                          );
                        } else if (content.type == 'shorts_listing' &&
                            content.shorts != null) {
                          return ShortsShelf(content: content);
                        }
                        return const SizedBox.shrink();
                      },
                    );
                  }
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
      final avatar = video.channelAvatarUrl;

      // Responsive sizes derived from screen width.
      final screenWidth = MediaQuery.of(context).size.width;
      final avatarRadius = (screenWidth * 0.045).clamp(16.0, 24.0); // responsive
      final spacing = (screenWidth * 0.025).clamp(8.0, 14.0);

      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing, vertical: spacing * 0.6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail: fully responsive using 16:9 aspect ratio.
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: (video.thumbnailUrl == null || video.thumbnailUrl!.isEmpty)
                      ? const ColoredBox(
                          color: Colors.grey,
                          child: Center(child: Icon(Icons.video_library)),
                        )
                      : Image.network(
                          video.thumbnailUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                            color: Colors.grey,
                            child: Center(child: Icon(Icons.broken_image)),
                          ),
                        ),
                ),
              ),
              SizedBox(height: spacing * 0.6),
              // Title & metadata
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar (responsive radius)
                  CircleAvatar(
                    radius: avatarRadius,
                    backgroundColor:
                        isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                    backgroundImage:
                        (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
                    child: (avatar == null || avatar.isEmpty)
                        ? Text(
                            video.channelTitle.isNotEmpty
                                ? video.channelTitle[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  SizedBox(width: spacing * 0.7),
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
                            fontSize: (screenWidth * 0.038).clamp(14.0, 17.0),
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
                            fontSize: (screenWidth * 0.032).clamp(12.0, 14.0),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.more_vert,
                      color: isDark ? Colors.white : Colors.black54,
                    ),
                    onPressed: () {},
                    splashRadius: avatarRadius + 2,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
  }

  class ShortsShelf extends StatelessWidget {
    final Content content;

    const ShortsShelf({super.key, required this.content});

    @override
    Widget build(BuildContext context) {
      final shorts = content.shorts ?? [];
      if (shorts.isEmpty) return const SizedBox.shrink();

      final isDark = Theme.of(context).brightness == Brightness.dark;

      return LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final horizontalPadding = (w * 0.03).clamp(12.0, 20.0);
          final gap = (w * 0.02).clamp(8.0, 16.0);

          // Each tile uses ~42% of available width (good for phones; still fine for tablets).
          final tileWidth = (w * 0.42).clamp(180.0, w * 0.5);
          // Shorts are 9:16. Keep a stable aspect instead of fixed height.
          const shortsAspect = 9 / 16;

          // Thumbnail height from aspect ratio
          final thumbHeight = tileWidth / shortsAspect;

          // Estimate room for texts (2 lines title + 1 line views) responsively
          final titleFs = (w * 0.032).clamp(12.0, 14.0);
          final viewsFs = (w * 0.03).clamp(11.5, 13.0);
          final textBlockHeight =
              // ~2 lines title + spacing + 1 line views + padding
              (titleFs * 2.6) + (viewsFs * 1.4) + (gap * 1.2);

          // Final list height = thumbnail + text + vertical paddings
          final listHeight = thumbHeight + textBlockHeight + (gap * 1.2);

          return Padding(
            padding: EdgeInsets.symmetric(vertical: gap),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Text(
                    content.title ?? 'Shorts',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: (w * 0.05).clamp(18.0, 22.0),
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                SizedBox(height: gap * 0.6),
                SizedBox(
                  height: listHeight,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    itemCount: shorts.length,
                    itemBuilder: (context, index) {
                      final short = shorts[index];
                      final thumb = short.thumbnail.firstWhere(
                        (t) => (t['width'] ?? 0) > 400,
                        orElse: () => short.thumbnail[0],
                      );
                      final thumbUrl = thumb['url'] as String?;

                      return Padding(
                        padding: EdgeInsets.only(
                          right: index == shorts.length - 1 ? 0 : gap,
                        ),
                        child: GestureDetector(
                          onTap: () {
                            final shortEntity = VideoEntity(
                              id: short.videoId,
                              title: short.title,
                              channelTitle: '',
                              viewCount: _parseViews(short.viewCountText),
                              thumbnailUrl: thumbUrl,
                              publishedDate: null,
                              channelAvatarUrl: null,
                            );
                            context.push('/youtube-player',
                                extra: {'video': shortEntity, 'isShort': true});
                          },
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: tileWidth,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: AspectRatio(
                                    aspectRatio: shortsAspect,
                                    child: (thumbUrl == null || thumbUrl.isEmpty)
                                        ? const ColoredBox(
                                            color: Colors.grey,
                                            child: Icon(Icons.broken_image),
                                          )
                                        : Image.network(
                                            thumbUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const ColoredBox(
                                              color: Colors.grey,
                                              child: Icon(Icons.broken_image),
                                            ),
                                          ),
                                  ),
                                ),
                                SizedBox(height: gap * 0.4),
                                // Title
                                Text(
                                  short.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: titleFs,
                                    color:
                                        isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                // Views
                                Text(
                                  short.viewCountText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: viewsFs,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    int _parseViews(String text) {
      var t = text.replaceAll(' views', '').toUpperCase().trim();
      double multiplier = 1.0;
      if (t.endsWith('K')) {
        multiplier = 1000;
        t = t.substring(0, t.length - 1);
      } else if (t.endsWith('M')) {
        multiplier = 1000000;
        t = t.substring(0, t.length - 1);
      } else if (t.endsWith('B')) {
        multiplier = 1000000000;
        t = t.substring(0, t.length - 1);
      }
      return ((double.tryParse(t) ?? 0) * multiplier).toInt();
    }
  }
