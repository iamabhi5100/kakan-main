// lib/features/search/presentation/song_content_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_bloc.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_event.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_state.dart';
import 'package:kakan/features/home/presentation/widgets/share_screen.dart';
import 'package:kakan/features/search/domain/entities/search_result.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:toastification/toastification.dart';

class SongContentScreen extends StatefulWidget {
  final SearchResult song;
  const SongContentScreen({Key? key, required this.song}) : super(key: key);

  @override
  _SongContentScreenState createState() => _SongContentScreenState();
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
            backgroundColor: Colors.grey[100],
            appBar: AppBar(
              backgroundColor: Colors.white,
              leading: const BackButton(color: Colors.black),
              title: Text(
                meta.name ?? '',
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.w600),
              ),
              elevation: 0,
            ),
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          meta.profileImage != null
                              ? CircleAvatar(
                                  radius: 20,
                                  backgroundImage:
                                      NetworkImage(meta.profileImage!),
                                )
                              : const CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.grey,
                                  child: Icon(Icons.person, color: Colors.black54),
                                ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                meta.name ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              Text(
                                '@${meta.username ?? ''}',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.more_horiz,
                                color: Colors.black54),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),

                    // Audio Thumbnail
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: meta.thumbnail != null
                            ? Image.network(
                                meta.thumbnail!,
                                width: 200,
                                height: 200,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  width: 200,
                                  height: 200,
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: Icon(Icons.music_note,
                                        color: Colors.black54, size: 60),
                                  ),
                                ),
                              )
                            : Container(
                                width: 200,
                                height: 200,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: Icon(Icons.music_note,
                                      color: Colors.black54, size: 60),
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Audio Controls
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Row(
                        children: [
                          StreamBuilder<bool>(
                            stream: _player.playingStream,
                            builder: (_, snap) {
                              final playing = snap.data ?? false;
                              return IconButton(
                                icon: Icon(
                                  playing
                                      ? Icons.pause_circle_filled
                                      : Icons.play_circle_filled,
                                  size: 40,
                                  color: Colors.black,
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
                                    return Slider(
                                      min: 0,
                                      max: total.inMilliseconds.toDouble(),
                                      value: pos.inMilliseconds.toDouble(),
                                      activeColor: Colors.black,
                                      inactiveColor: Colors.grey[400],
                                      onChanged: (ms) {
                                        _player.seek(Duration(milliseconds: ms.round()));
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.volume_up, color: Colors.black54),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),

                    // Time Indicators
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          StreamBuilder<Duration>(
                            stream: _positionStream,
                            builder: (_, snap) {
                              return Text(
                                _formatDuration(snap.data ?? Duration.zero),
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              );
                            },
                          ),
                          StreamBuilder<Duration?>(
                            stream: _durationStream,
                            builder: (_, snap) {
                              return Text(
                                _formatDuration(snap.data ?? Duration.zero),
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Actions
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Row(
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  _flagLiked ? Icons.favorite : Icons.favorite_border,
                                  color: _flagLiked ? Colors.red : Colors.black,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _flagLiked = !_flagLiked;
                                    _likes = _flagLiked ? _likes + 1 : _likes - 1;
                                  });
                                  providerContext
                                      .read<FeedBloc>()
                                      .add(LikeDislikePostEvent(postId: meta.id));
                                },
                              ),
                              Text('$_likes Likes', style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.repeat, color: Colors.green),
                                onPressed: () async {
                                  final TextEditingController titleController =
                                      TextEditingController(text: '${meta.name ?? 'Repost'} (Repost)');
                                  final TextEditingController captionController =
                                      TextEditingController(text: meta.description);

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
                                          onPressed: () => Navigator.pop(dialogContext, {
                                            'title': titleController.text,
                                            'caption': captionController.text,
                                          }),
                                          child: const Text('Repost'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (result != null && mounted) {
                                    providerContext.read<FeedBloc>().add(
                                      RepostEvent(
                                        postId: meta.id,
                                        title: result['title']!,
                                        caption: result['caption']!,
                                      ),
                                    );
                                  }
                                },
                              ),
                              Text('$_reposts Reposts', style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.send, color: Colors.black),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                ),
                                builder: (context) => ShareScreen(
                                  mediaFile: meta.mediaFile,
                                  mediaType: meta.mediaType,
                                  caption: meta.description,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Description
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text(
                        meta.description ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, color: Colors.black),
                      ),
                    ),

                    // Timestamp
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
                      child: Text(
                        meta.created ?? '',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
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
