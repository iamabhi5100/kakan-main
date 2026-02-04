// lib/features/home/presentation/widgets/feed_data_list.dart

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:kakan/config/theme.dart'; // exposes `appTheme`
import 'package:kakan/core/utils/media_manager.dart';
import 'package:kakan/core/utils/session_manager.dart';
import 'package:kakan/features/home/model/entities/feed_entity.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_bloc.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_event.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_state.dart';
import 'package:kakan/features/home/presentation/widgets/comments_screen.dart';
import 'package:kakan/features/home/presentation/widgets/share_screen.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:toastification/toastification.dart';
import 'package:video_player/video_player.dart';

/// ---- Date helpers (single definition) ----
DateTime? _tryParseWithPatterns(String raw) {
  try {
    return DateTime.parse(raw).toLocal();
  } catch (_) {}
  const patterns = <String>[
    'dd/MM/yyyy, hh:mm a',
    'dd/MM/yyyy, HH:mm',
    'dd/MM/yyyy HH:mm',
    'dd-MM-yyyy HH:mm',
    'yyyy-MM-dd HH:mm:ss',
    'yyyy-MM-dd HH:mm',
    "yyyy-MM-dd'T'HH:mm:ss'Z'",
    "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
    "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
  ];
  for (final p in patterns) {
    try {
      return DateFormat(p).parseLoose(raw).toLocal();
    } catch (_) {}
  }
  return null;
}

String _formatDisplayDate(String raw) {
  final dt = _tryParseWithPatterns(raw);
  if (dt == null) return raw;
  return DateFormat('d MMM yyyy, h:mm a').format(dt);
}

class FeedDataList extends StatefulWidget {
  const FeedDataList({super.key});
  @override
  State<FeedDataList> createState() => _FeedDataListState();
}

class _FeedDataListState extends State<FeedDataList> {
  final _scrollController = ScrollController();
  final _listKey = GlobalKey(); // for viewport rect
  final Map<String, GlobalKey> _itemKeys = {}; // feedId -> key

  @override
  void initState() {
    super.initState();
    // initial fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<FeedBloc>().add(const FetchFeedsEvent());
      }
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final bloc = context.read<FeedBloc>();
    final state = bloc.state;
    if (state is FeedActionState) {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          state.hasMore &&
          !bloc.isLoadingMore) {
        bloc.add(const FetchMoreFeedsEvent());
      }
    }
  }

  /// Called during scrolling to pause media if the playing item is fully out of view.
  void _maybePauseIfOutOfView() {
    final playingId = MediaManager().currentOwnerId;
    if (playingId == null) return;

    final itemKey = _itemKeys[playingId];
    final listCtx = _listKey.currentContext;
    final itemCtx = itemKey?.currentContext;

    if (listCtx == null || itemCtx == null) return;

    final RenderBox listBox = listCtx.findRenderObject() as RenderBox;
    final RenderBox itemBox = itemCtx.findRenderObject() as RenderBox;

    final Offset listTopLeft = listBox.localToGlobal(Offset.zero);
    final Rect viewport = Rect.fromLTWH(
      listTopLeft.dx,
      listTopLeft.dy,
      listBox.size.width,
      listBox.size.height,
    );

    final Offset itemTopLeft = itemBox.localToGlobal(Offset.zero);
    final Rect itemRect = Rect.fromLTWH(
      itemTopLeft.dx,
      itemTopLeft.dy,
      itemBox.size.width,
      itemBox.size.height,
    );

    if (!viewport.overlaps(itemRect)) {
      MediaManager().pauseAll();
    }
  }

  Future<void> _onRefresh() async {
    MediaManager().pauseAll();
    context.read<FeedBloc>().add(const RefreshFeedsEvent());
  }

  GlobalKey _keyFor(String id) {
    return _itemKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'feed_$id'));
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    MediaManager().disposeMedia();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollUpdateNotification || n is ScrollEndNotification) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _maybePauseIfOutOfView());
        }
        return false;
      },
      child: BlocConsumer<FeedBloc, FeedState>(
        listener: (context, state) {
          if (state is FeedActionError) {
            toastification.show(
              context: context,
              title: Text(state.message),
              type: ToastificationType.error,
              style: ToastificationStyle.fillColored,
              autoCloseDuration: const Duration(seconds: 3),
            );
          } else if (state is FeedActionSuccess) {
            if (state.actionType == 'repost') {
              toastification.show(
                context: context,
                title: const Text('Repost created successfully'),
                type: ToastificationType.success,
                style: ToastificationStyle.fillColored,
                autoCloseDuration: const Duration(seconds: 3),
              );
            } else if (state.actionType != 'comment') {
              toastification.show(
                context: context,
                title: const Text('Action completed successfully'),
                type: ToastificationType.success,
                style: ToastificationStyle.fillColored,
                autoCloseDuration: const Duration(seconds: 3),
              );
            }
          }
        },
        buildWhen: (previous, current) {
          return current is FeedInitial ||
              current is FeedLoading ||
              current is FeedActionState ||
              current is FeedError;
        },
        builder: (context, state) {
          if (state is FeedLoading && state.feeds.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is FeedError) {
            return Center(child: Text(state.message));
          }

          if (state is FeedActionState) {
            final feeds = state.feeds;
            if (feeds.isEmpty) {
              return RefreshIndicator(
                onRefresh: _onRefresh,
                child: ListView(
                  key: _listKey,
                  controller: _scrollController,
                  children: const [
                    SizedBox(height: 120),
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No feeds yet. Be the first to post!'),
                      ),
                    ),
                  ],
                ),
              );
            }

            final showLoadingTail = state.hasMore;

            return RefreshIndicator(
              onRefresh: _onRefresh,
              child: ListView.builder(
                key: _listKey,
                controller: _scrollController,
                itemCount: feeds.length + (showLoadingTail ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == feeds.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final feed = feeds[index];
                  final cellKey = _keyFor(feed.id);
                  return FeedItemWidget(
                    key: PageStorageKey('feed-item-${feed.id}'),
                    itemKey: cellKey,
                    feed: feed,
                  );
                },
              ),
            );
          }

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

class FeedItemWidget extends StatefulWidget {
  final FeedEntity feed;
  final GlobalKey itemKey;
  const FeedItemWidget({super.key, required this.feed, required this.itemKey});
  @override
  State<FeedItemWidget> createState() => _FeedItemWidgetState();
}

class _FeedItemWidgetState extends State<FeedItemWidget>
    with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _controller;
  AudioPlayer? _audioPlayer;

  bool _isExpanded = false;

  // Separate mute flags
  bool _videoMuted = false; // NEW: video mute state
  bool _audioMuted = false;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  String? _audioError;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  final SessionManager _sessionManager = di.sl<SessionManager>();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeMedia();
  }

  // -------------------------
  // AUDIO HELPERS / FALLBACKS
  // -------------------------
  String _normalizeUrl(String url) {
    try {
      final u = Uri.parse(url);
      if (u.host == 'localhost' || u.host == '127.0.0.1') {
        return u.replace(host: '10.0.2.2').toString(); // Android emulator host
      }
      return url;
    } catch (_) {
      return url;
    }
  }

  Future<bool> _tryStreamWithHeaders(String url, Map<String, String> headers) async {
    try {
      final src = AudioSource.uri(Uri.parse(url), headers: headers);
      await _audioPlayer!.setAudioSource(src);
      return true;
    } catch (e) {
      if (kDebugMode) print('Audio stream (with headers) failed: $e');
      return false;
    }
  }

  Future<bool> _tryStreamWithoutHeaders(String url) async {
    try {
      await _audioPlayer!.setUrl(url);
      return true;
    } catch (e) {
      if (kDebugMode) print('Audio stream (no headers) failed: $e');
      return false;
    }
  }

  Future<File> _downloadToCache(String url, Map<String, String> headers) async {
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url));
      req.headers.addAll(headers);
      final resp = await client.send(req);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('HTTP ${resp.statusCode} while downloading');
      }
      final dir = await getTemporaryDirectory();
      final safeName = widget.feed.id.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final file = File('${dir.path}/aud_$safeName.dat');
      final sink = file.openWrite();
      await resp.stream.pipe(sink);
      await sink.close();
      return file;
    } finally {
      client.close();
    }
  }

  Future<void> _initAudio() async {
    if (_retryCount >= _maxRetries) {
      setState(() => _audioError = 'Failed to load audio after $_maxRetries attempts');
      return;
    }

    try {
      final token = await _sessionManager.getAccessToken();
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final normalizedUrl = _normalizeUrl(widget.feed.mediaFile);

      bool ok = await _tryStreamWithHeaders(normalizedUrl, headers);
      if (!ok) ok = await _tryStreamWithoutHeaders(normalizedUrl);
      if (!ok) {
        final file = await _downloadToCache(normalizedUrl, headers);
        await _audioPlayer!.setFilePath(file.path);
      }

      if (!mounted) return;
      setState(() {
        _audioError = null;
        _retryCount = 0;
      });

      _audioPlayer!.setVolume(_audioMuted ? 0 : 1);

      _audioPlayer!.durationStream.listen((d) {
        if (!mounted) return;
        setState(() => _duration = d ?? Duration.zero);
      });
      _audioPlayer!.positionStream.listen((p) {
        if (!mounted) return;
        setState(() => _position = p);
      });
    } catch (e) {
      if (kDebugMode) print('Init audio error: $e');
      if (!mounted) return;
      setState(() {
        _audioError = 'Failed to load audio. Tap to retry.';
        _retryCount++;
      });
      await Future.delayed(const Duration(seconds: 2));
      await _initAudio();
    }
  }

  Future<void> _initializeMedia() async {
    if (widget.feed.mediaType == 'video' && widget.feed.mediaFile.isNotEmpty) {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.feed.mediaFile),
      );
      await _controller!.initialize();
      // Ensure initial volume respects mute state
      await _controller!.setVolume(_videoMuted ? 0.0 : 1.0); // NEW
      if (mounted) setState(() {});
    } else if (widget.feed.mediaType == 'audio' &&
        widget.feed.mediaFile.isNotEmpty) {
      _audioPlayer = AudioPlayer();
      await _initAudio();
    }
  }

  @override
  void dispose() {
    if (widget.feed.mediaType == 'video') {
      MediaManager().clearIfOwnerDisposed(widget.feed.id, isVideo: true);
      _controller?.dispose();
    } else if (widget.feed.mediaType == 'audio') {
      MediaManager().clearIfOwnerDisposed(widget.feed.id, isVideo: false);
      _audioPlayer?.dispose();
    }
    super.dispose();
  }

  String _truncateCaption(String caption) {
    if (caption.length > 50 && !_isExpanded) {
      return '${caption.substring(0, 50)}...';
    }
    return caption;
  }

  void _toggleLike() {
    context.read<FeedBloc>().add(LikeDislikePostEvent(postId: widget.feed.id));
  }

  void _toggleRepost() async {
    final TextEditingController titleController =
        TextEditingController(text: '${widget.feed.title ?? 'Repost'} (Repost)');
    final TextEditingController captionController =
        TextEditingController(text: widget.feed.caption);
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
                    'caption': captionController.text
                  }),
              child: const Text('Repost')),
        ],
      ),
    );
    if (result != null && mounted) {
      context.read<FeedBloc>().add(RepostEvent(
          postId: widget.feed.id,
          title: result['title']!,
          caption: result['caption']!));
    }
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bottomSheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              if (widget.feed.flagOwnPost)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _confirmDelete(context);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.report, color: Colors.grey),
                title: const Text('Report'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report functionality not implemented')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      context.read<FeedBloc>().add(DeleteFeedEvent(feedId: widget.feed.id));
      MediaManager().pauseIfOwner(widget.feed.id);
    }
  }

  void _retryAudio() {
    setState(() {
      _audioError = null;
      _retryCount = 0;
    });
    _initAudio();
  }

  void _toggleVideoPlayPause() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    MediaManager().toggleVideo(widget.feed.id, c);
    setState(() {});
  }

  Future<void> _toggleAudioPlayPause() async {
    final p = _audioPlayer;
    if (p == null || _audioError != null) return;
    await MediaManager().toggleAudio(widget.feed.id, p);
    setState(() {});
  }

  // NEW: Toggle video mute
  Future<void> _toggleVideoMute() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final newMuted = !_videoMuted;
    await c.setVolume(newMuted ? 0.0 : 1.0);
    if (mounted) {
      setState(() {
        _videoMuted = newMuted;
      });
    }
  }

  // Existing: toggle audio mute
  void _toggleAudioMute() {
    final p = _audioPlayer;
    if (p == null || _audioError != null) return;
    setState(() {
      _audioMuted = !_audioMuted;
      p.setVolume(_audioMuted ? 0 : 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Container(
      key: widget.itemKey,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => context.push('/user/${widget.feed.userProfileDetails.id}'),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: appTheme.primaryColor, width: 2),
                      image: DecorationImage(
                        image: widget.feed.userProfileDetails.profileImage != null &&
                                widget.feed.userProfileDetails.profileImage!.isNotEmpty
                            ? NetworkImage(widget.feed.userProfileDetails.profileImage!)
                            : const AssetImage('assets/images/avataruser.png') as ImageProvider,
                        fit: BoxFit.cover,
                      ),
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.feed.userProfileDetails.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('@${widget.feed.userProfileDetails.username}',
                            style: const TextStyle(color: Colors.grey, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // media
          if (widget.feed.mediaType == 'video' &&
              _controller != null &&
              _controller!.value.isInitialized)
            GestureDetector(
              onTap: _toggleVideoPlayPause,
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller!),

                    // Play icon overlay when paused
                    if (!_controller!.value.isPlaying)
                      const Icon(Icons.play_arrow, color: Colors.white, size: 48),

                    // NEW: Mute/unmute button (top-right)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: IconButton(
                          tooltip: _videoMuted ? 'Unmute' : 'Mute',
                          icon: Icon(
                            _videoMuted ? Icons.volume_off : Icons.volume_up,
                            color: Colors.white,
                          ),
                          onPressed: _toggleVideoMute,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (widget.feed.mediaType == 'audio' && _audioPlayer != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: _audioError != null
                  ? GestureDetector(
                      onTap: _retryAudio,
                      child: Container(
                        height: 100,
                        color: Colors.grey[200],
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_audioError!, style: const TextStyle(color: Colors.black54), textAlign: TextAlign.center),
                              const SizedBox(height: 8),
                              const Text('Tap to retry', style: TextStyle(color: Colors.blue)),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _audioPlayer!.playing ? Icons.pause : Icons.play_arrow,
                            color: Colors.blue,
                            size: 30,
                          ),
                          onPressed: _toggleAudioPlayPause,
                        ),
                        Expanded(
                          child: MiniWaveformBar(
                            position: _position,
                            duration: _duration,
                            enabled: _audioPlayer != null,
                            onSeek: (d) => _audioPlayer!.seek(d),
                            peaks: null,
                            seedKey: widget.feed.id,
                            height: 44,
                            padding: const EdgeInsets.only(right: 8),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _audioMuted ? Icons.volume_off : Icons.volume_up,
                            color: Colors.grey,
                            size: 24,
                          ),
                          onPressed: _toggleAudioMute,
                        ),
                      ],
                    ),
            )
          else
            Container(
              height: 200,
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            ),

          const SizedBox(height: 8),

          // actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: Image.asset(
                      widget.feed.flagLiked
                          ? 'assets/images/like_filled.png'
                          : 'assets/images/like_outline.png',
                      width: 30,
                      height: 30,
                    ),
                    onPressed: _toggleLike,
                  ),
                  Text('${widget.feed.likesCount}'),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: Image.asset('assets/images/comment.png', width: 24, height: 24),
                    onPressed: () => showCommentsBottomSheet(context, postId: widget.feed.id),
                  ),
                  Text('${widget.feed.commentsCount}'),
                  const SizedBox(width: 16),
                  if (!widget.feed.flagOwnPost)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Image.asset('assets/images/repost.png', width: 30, height: 30),
                          onPressed: _toggleRepost,
                        ),
                        Text('${widget.feed.repostCount}'),
                      ],
                    ),
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(width: 16),
                  IconButton(
                    icon: Image.asset('assets/images/send.png', width: 24, height: 24),
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => ShareScreen(
                        mediaFile: widget.feed.mediaFile,
                        mediaType: widget.feed.mediaType,
                        caption: widget.feed.caption,
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),

          // text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (widget.feed.title != null && widget.feed.title!.isNotEmpty)
                Text(widget.feed.title!,
                    style: const TextStyle(
                        color: Colors.black, fontSize: 14, fontWeight: FontWeight.w500)),
              if (widget.feed.caption.isNotEmpty)
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                          text: _truncateCaption(widget.feed.caption),
                          style: const TextStyle(color: Colors.black)),
                      if (widget.feed.caption.length > 50 && !_isExpanded) ...[
                        const TextSpan(text: ' '),
                        WidgetSpan(
                          child: GestureDetector(
                            onTap: () => setState(() => _isExpanded = true),
                            child: const Text('MORE',
                                style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Text(
              _formatDisplayDate(widget.feed.created),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// --------------------
/// Lightweight waveform
/// --------------------
class MiniWaveformBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration>? onSeek;
  final bool enabled;
  final double height;
  final EdgeInsetsGeometry padding;
  final List<double>? peaks;
  final String? seedKey;

  const MiniWaveformBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.enabled = true,
    this.height = 48,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    this.peaks,
    this.seedKey,
  });

  @override
  State<MiniWaveformBar> createState() => _MiniWaveformBarState();
}

class _MiniWaveformBarState extends State<MiniWaveformBar> {
  bool _dragging = false;
  double _dragProgress = 0; // 0..1

  List<double> _buildSyntheticPeaks(int bars, String seed) {
    // Deterministic pseudo random using seed hash
    int h = seed.hashCode;
    final rnd = math.Random(h);
    final base = List<double>.generate(bars, (i) {
      // Smooth-ish noise + gentle envelope so edges are smaller
      final noise = (rnd.nextDouble() * 0.7) + 0.3; // 0.3..1.0
      final t = i / (bars - 1).clamp(1, bars);
      final envelope = 0.75 + 0.25 * math.sin(t * math.pi);
      return (noise * envelope).clamp(0.08, 1.0);
    });

    // Light smoothing pass
    for (int i = 1; i < base.length - 1; i++) {
      base[i] = (base[i - 1] + base[i] + base[i + 1]) / 3.0;
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    // Explicit types to avoid num/double ambiguity
    final int durationMs = widget.duration.inMilliseconds.clamp(1, 1 << 31);
    final int posMs = widget.position.inMilliseconds.clamp(0, durationMs);
    final double progress = durationMs <= 1 ? 0.0 : posMs / durationMs;

    const int bars = 80; // responsive enough; increase if you like
    final List<double> peaks =
        widget.peaks ??
        _buildSyntheticPeaks(bars, widget.seedKey ?? 'default-seed');

    // Normalize provided peaks if any
    final List<double> normalized = List<double>.generate(bars, (i) {
      if (i < peaks.length) {
        final v = peaks[i];
        return v.isNaN ? 0.2 : v.clamp(0.05, 1.0);
      }
      return 0.2;
    });

    final double activeProgress = _dragging ? _dragProgress : progress;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: widget.enabled
          ? (_) => setState(() => _dragging = true)
          : null,
      onHorizontalDragUpdate: widget.enabled
          ? (details) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              final local = box.globalToLocal(details.globalPosition);
              final double p = (local.dx / box.size.width).clamp(0.0, 1.0);
              setState(() => _dragProgress = p);
            }
          : null,
      onHorizontalDragEnd: widget.enabled
          ? (_) {
              setState(() => _dragging = false);
              final int targetMs = (durationMs * _dragProgress).round();
              widget.onSeek?.call(Duration(milliseconds: targetMs));
            }
          : null,
      onTapDown: widget.enabled
          ? (d) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              final double p =
                  (d.localPosition.dx / box.size.width).clamp(0.0, 1.0);
              final int targetMs = (durationMs * p).round();
              widget.onSeek?.call(Duration(milliseconds: targetMs));
            }
          : null,
      child: Padding(
        padding: widget.padding,
        child: SizedBox(
          height: widget.height,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _WavePainter(
                peaks: normalized,
                progress: activeProgress,
                colorInactive: Theme.of(context).dividerColor,
                colorActive: appTheme.primaryColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final List<double> peaks; // 0..1
  final double progress; // 0..1
  final Color colorActive;
  final Color colorInactive;

  _WavePainter({
    required this.peaks,
    required this.progress,
    required this.colorActive,
    required this.colorInactive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty) return;

    final double barWidth = size.width / peaks.length;
    final double spacing = barWidth * 0.28; // slightly tighter gaps
    final double actualBar = barWidth - spacing;

    final double centerY = size.height / 2;
    final int activeBars =
        (peaks.length * progress).floor(); // avoid off-by-one at 0%

    final paintInactive = Paint()..color = colorInactive;
    final paintActive = Paint()..color = colorActive;

    for (int i = 0; i < peaks.length; i++) {
      final double h = (peaks[i].clamp(0.05, 1.0)) * size.height;
      final rect = RRect.fromLTRBR(
        i * barWidth + spacing / 2,
        centerY - h / 2,
        i * barWidth + spacing / 2 + actualBar,
        centerY + h / 2,
        const Radius.circular(3),
      );
      // Only fill as active if it's strictly before the active count.
      canvas.drawRRect(rect, i < activeBars ? paintActive : paintInactive);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.peaks != peaks ||
        oldDelegate.colorActive != colorActive ||
        oldDelegate.colorInactive != colorInactive;
  }
}
