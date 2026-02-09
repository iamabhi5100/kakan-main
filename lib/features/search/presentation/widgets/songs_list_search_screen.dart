import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/features/search/domain/entities/search_result.dart';
import 'package:kakan/features/search/presentation/bloc/combined_search/combined_search_bloc.dart';
import 'package:kakan/features/search/presentation/bloc/combined_search/combined_search_state.dart';
import 'package:kakan/features/search/presentation/theme/search_theme.dart';
import 'package:kakan/features/search/presentation/pages/song_content_screen.dart';

class SongsListSearchScreen extends StatelessWidget {
  const SongsListSearchScreen({super.key});

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
          final songs = state.songs;
          if (songs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(SearchTheme.spacingXXl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.music_off_rounded, size: 64, color: SearchTheme.textMuted),
                    const SizedBox(height: SearchTheme.spacingLg),
                    Text('No songs found', style: SearchTheme.emptyTitle),
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
            itemCount: songs.length,
            separatorBuilder: (_, __) => const SizedBox(height: SearchTheme.spacingSm),
            itemBuilder: (ctx, index) {
              final r = songs[index];
              return _SongTile(song: r);
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
                Icon(Icons.music_note_rounded, size: 64, color: SearchTheme.textMuted),
                const SizedBox(height: SearchTheme.spacingLg),
                Text('Search songs', style: SearchTheme.emptyTitle),
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

class _SongTile extends StatelessWidget {
  final SearchResult song;

  const _SongTile({required this.song});

  /// Thumbnail for list: use API thumbnail, or creator profile image as fallback.
  String? get _effectiveThumbnailUrl {
    if (song.thumbnail != null && song.thumbnail!.isNotEmpty) return song.thumbnail;
    if (song.profileImage != null && song.profileImage!.isNotEmpty) return song.profileImage;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final thumbUrl = _effectiveThumbnailUrl;

    return Material(
      color: SearchTheme.cardBg,
      borderRadius: BorderRadius.circular(SearchTheme.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SongContentScreen(song: song),
            ),
          );
        },
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
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
              const SizedBox(width: SearchTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      song.name ?? 'Untitled',
                      style: SearchTheme.titleCard,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: SearchTheme.spacingXs),
                    Text(
                      song.description ?? '',
                      style: SearchTheme.caption.copyWith(color: SearchTheme.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.play_circle_outline_rounded, color: SearchTheme.primary, size: 36),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: SearchTheme.listThumbSize,
      height: SearchTheme.listThumbSize,
      color: SearchTheme.divider,
      child: Icon(Icons.music_note_rounded, color: SearchTheme.textMuted, size: 32),
    );
  }
}
