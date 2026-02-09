// lib/features/search/presentation/pages/song_content_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_bloc.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_event.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_state.dart';
import 'package:kakan/features/home/presentation/widgets/share_screen.dart';
import 'package:kakan/features/search/domain/entities/search_result.dart';
import 'package:kakan/features/search/presentation/theme/search_theme.dart';
import 'package:kakan/features/search/presentation/widgets/search_content_layout.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:toastification/toastification.dart';

class SongContentScreen extends StatefulWidget {
  final SearchResult song;
  const SongContentScreen({super.key, required this.song});

  @override
  State<SongContentScreen> createState() => _SongContentScreenState();
}

class _SongContentScreenState extends State<SongContentScreen> {
  late AudioPlayer _player;
  late Stream<Duration> _positionStream;
  late Stream<Duration?> _durationStream;
  late bool _flagLiked;
  late int _likes;
  late int _reposts;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _flagLiked = widget.song.flagLiked ?? false;
    _likes = widget.song.likesCount ?? 0;
    _reposts = widget.song.repostCount ?? 0;
    final url = widget.song.mediaFile;
    assert(url != null, 'Audio URL is null');
    _player.setUrl(url!);
    _positionStream = _player.positionStream;
    _durationStream = _player.durationStream;
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta = widget.song;
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
                  // CHANGED: GetFeedEvent -> RefreshFeedsEvent
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
                      const SizedBox(height: SearchTheme.spacingLg),
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(SearchTheme.radiusLg),
                          child: meta.thumbnail != null
                            ? Image.network(
                                meta.thumbnail!,
                                width: 200,
                                height: 200,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 200,
                                  height: 200,
                                  color: SearchTheme.divider,
                                  child: Icon(Icons.music_note_rounded, color: SearchTheme.textMuted, size: 60),
                                ),
                              )
                            : Container(
                                width: 200,
                                height: 200,
                                color: SearchTheme.divider,
                                child: Icon(Icons.music_note_rounded, color: SearchTheme.textMuted, size: 60),
                              ),
                        ),
                      ),
                      const SizedBox(height: SearchTheme.spacingLg),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            StreamBuilder<bool>(
                              stream: _player.playingStream,
                              builder: (_, snap) {
                                final playing = snap.data ?? false;
                                return IconButton(
                                  icon: Icon(
                                    playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                                    size: 48,
                                    color: SearchTheme.primary,
                                  ),
                                  onPressed: () {
                                    playing ? _player.pause() : _player.play();
                                  },
                                );
                              },
                            ),
                            Expanded(
                              child: StreamBuilder<Duration?>(
                                stream: _durationStream,
                                builder: (_, dSnap) {
                                  final total = dSnap.data ?? Duration.zero;
                                  return StreamBuilder<Duration>(
                                    stream: _positionStream,
                                    builder: (_, pSnap) {
                                      var pos = pSnap.data ?? Duration.zero;
                                      if (pos > total) pos = total;
                                      return SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          activeTrackColor: SearchTheme.primary,
                                          inactiveTrackColor: SearchTheme.divider,
                                          thumbColor: SearchTheme.primary,
                                        ),
                                        child: Slider(
                                          min: 0,
                                          max: total.inMilliseconds.toDouble(),
                                          value: pos.inMilliseconds.toDouble(),
                                          onChanged: (ms) {
                                            _player.seek(Duration(milliseconds: ms.round()));
                                          },
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.volume_up_rounded, color: SearchTheme.textMuted),
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            StreamBuilder<Duration>(
                              stream: _positionStream,
                              builder: (_, snap) => Text(_formatDuration(snap.data ?? Duration.zero), style: SearchTheme.caption),
                            ),
                            StreamBuilder<Duration?>(
                              stream: _durationStream,
                              builder: (_, snap) => Text(_formatDuration(snap.data ?? Duration.zero), style: SearchTheme.caption),
                            ),
                          ],
                        ),
                      ),
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

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
