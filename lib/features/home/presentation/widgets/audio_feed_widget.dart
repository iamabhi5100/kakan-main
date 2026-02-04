import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:intl/intl.dart'; // ⬅️ add
import 'package:kakan/config/theme.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_bloc.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_event.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_state.dart';
import 'package:kakan/features/home/presentation/widgets/comments_screen.dart';
import 'package:kakan/features/home/presentation/widgets/share_screen.dart';
import 'package:kakan/features/profile/domain/entities/profile_post_entity.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_post_delete/delete_post_bloc.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_post_delete/delete_post_event.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_post_delete/delete_post_state.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_post_list/profile_posts_bloc.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_post_list/profile_posts_event.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:toastification/toastification.dart';
import 'dart:math' as math;

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

  /// Optional: provide real peaks (0..1). If null, a stable synthetic shape is used.
  final List<double>? peaks;

  /// Stable seed to make a consistent synthetic waveform per post.
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

/// -------------------------------------------
/// Date helpers (robust parsing + required format)
/// -------------------------------------------
DateTime? _tryParseWithPatterns(String raw) {
  // Try ISO first (handles offsets/timezones)
  try {
    return DateTime.parse(raw).toLocal();
  } catch (_) {}

  // Common formats seen across the app/backends
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

String _formatDisplayDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 'Unknown time';
  final dt = _tryParseWithPatterns(raw);
  if (dt == null) return raw;
  // If you want to force English month names: DateFormat('d MMM yyyy, h:mm a', 'en').format(dt)
  return DateFormat('d MMM yyyy, h:mm a').format(dt);
}

/// -------------------------------------------
/// Your original widget with waveform dropped in
/// -------------------------------------------
class AudioFeedWidget extends StatefulWidget {
  final ProfilePostEntity? post;
  final String name;
  final String username;
  final String? profileImage;
  final String userId;
  const AudioFeedWidget({
    super.key,
    this.post,
    required this.name,
    required this.username,
    this.profileImage,
    required this.userId,
  });
  @override
  State<AudioFeedWidget> createState() => _AudioFeedWidgetState();
}

class _AudioFeedWidgetState extends State<AudioFeedWidget> {
  AudioPlayer? _audioPlayer;
  late int _likes;
  late int _reposts;
  late bool _flagLiked;
  bool _isMuted = false;
  bool _isDeleting = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _audioError;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  // Optional: if you later pipe in real peaks
  List<double>? _realPeaks; // values 0..1

  @override
  void initState() {
    super.initState();
    _likes = widget.post?.likesCount ?? 0;
    _reposts = widget.post?.repostCount ?? 0;
    _flagLiked = widget.post?.flagLiked ?? false;
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    if (widget.post == null ||
        widget.post!.mediaFile == null ||
        widget.post!.mediaFile!.isNotEmpty == false) {
      if (mounted) {
        setState(() {
          _audioError = 'No audio file available';
        });
      }
      return;
    }
    _audioPlayer = AudioPlayer();
    try {
      await _audioPlayer!.setUrl(widget.post!.mediaFile!);
      if (mounted) {
        setState(() {
          _audioError = null;
          _retryCount = 0;
        });
        _audioPlayer!.durationStream.listen((d) {
          if (mounted) setState(() => _duration = d ?? Duration.zero);
        });
        _audioPlayer!.positionStream.listen((p) {
          if (mounted) setState(() => _position = p);
        });
        _audioPlayer!.playerStateStream.listen((state) {
          if (mounted) setState(() {});
        });
      }
    } catch (e) {
      if (kDebugMode) print('AudioFeedWidget: Error initializing audio: $e');
      if (mounted) {
        setState(() {
          _audioError = 'Failed to load audio. Tap to retry.';
          _retryCount++;
        });
        if (_retryCount < _maxRetries) {
          await Future.delayed(const Duration(seconds: 2));
          await _initializeAudio();
        }
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_isDeleting || _audioError != null || _audioPlayer == null) return;
    if (_audioPlayer!.playing) {
      _audioPlayer!.pause();
    } else {
      _audioPlayer!.play();
    }
    setState(() {}); // nudge icons
  }

  void _toggleLike() {
    if (_isDeleting || widget.post == null) return;
    setState(() {
      _flagLiked = !_flagLiked;
      _likes = _flagLiked ? _likes + 1 : _likes - 1;
    });
    context.read<FeedBloc>().add(LikeDislikePostEvent(postId: widget.post!.id));
  }

  Future<void> _toggleMute() async {
    if (_audioPlayer == null) return;
    _isMuted = !_isMuted;
    await _audioPlayer!.setVolume(_isMuted ? 0 : 1);
    if (mounted) setState(() {});
  }

  void _toggleRepost() async {
    if (_isDeleting || widget.post == null) return;
    final TextEditingController titleController =
        TextEditingController(text: '${widget.post?.title ?? 'Repost'} (Repost)');
    final TextEditingController captionController =
        TextEditingController(text: widget.post?.caption);
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Repost'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
          TextField(controller: captionController, decoration: const InputDecoration(labelText: 'Caption')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, {'title': titleController.text, 'caption': captionController.text}), child: const Text('Repost')),
        ],
      ),
    );
    if (result != null && mounted) {
      context.read<FeedBloc>().add(RepostEvent(postId: widget.post!.id, title: result['title']!, caption: result['caption']!));
    }
  }

  void _toggleShare() {
    if (_isDeleting || widget.post == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareScreen(
        mediaFile: widget.post?.mediaFile,
        mediaType: widget.post?.mediaType,
        caption: widget.post?.caption,
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    if (_isDeleting) return;
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bottomSheetContext) {
        return SafeArea(
          child: Wrap(children: [
            ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('Delete'), onTap: () {
              Navigator.pop(bottomSheetContext);
              _confirmDelete(context);
            }),
            ListTile(leading: const Icon(Icons.report, color: Colors.grey), title: const Text('Report'), onTap: () {
              Navigator.pop(bottomSheetContext);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report functionality not implemented')));
            }),
          ]),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context) async {
    if (_isDeleting || widget.post == null) return;
    final deleteBloc = context.read<DeletePostBloc>();
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
      setState(() => _isDeleting = true);
      deleteBloc.add(DeletePostRequested(postId: widget.post!.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.post == null) {
      return const SizedBox.shrink();
    }
    return BlocProvider(
      create: (_) => di.sl<DeletePostBloc>(),
      child: Builder(
        builder: (providerContext) => BlocListener<DeletePostBloc, DeletePostState>(
          listener: (context, state) {
            if (state is DeletePostSuccess && mounted) {
              setState(() => _isDeleting = false);
              toastification.show(
                context: context,
                title: const Text('Post deleted successfully'),
                type: ToastificationType.success,
                style: ToastificationStyle.fillColored,
                autoCloseDuration: const Duration(seconds: 3),
              );
              context.read<ProfilePostsBloc>().add(GetProfilePostsEvent(mediaType: widget.post!.mediaType, userId: widget.userId));
            } else if (state is DeletePostError && mounted) {
              setState(() => _isDeleting = false);
              toastification.show(
                context: context,
                title: Text(state.message),
                type: ToastificationType.error,
                style: ToastificationStyle.fillColored,
                autoCloseDuration: const Duration(seconds: 3),
              );
            }
          },
          child: BlocListener<FeedBloc, FeedState>(
            listener: (context, state) {
              if (state is FeedActionSuccess && mounted) {
                if (state.actionType == 'repost') {
                  toastification.show(
                    context: context,
                    title: const Text('Repost created successfully'),
                    type: ToastificationType.success,
                    style: ToastificationStyle.fillColored,
                    autoCloseDuration: const Duration(seconds: 3),
                  );
                  context.read<ProfilePostsBloc>().add(GetProfilePostsEvent(
                    mediaType: widget.post!.mediaType,
                    userId: widget.userId,
                  ));
                } else if (state.actionType != 'comment') {
                  toastification.show(
                    context: context,
                    title: const Text('Action completed successfully'),
                    type: ToastificationType.success,
                    style: ToastificationStyle.fillColored,
                    autoCloseDuration: const Duration(seconds: 3),
                  );
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

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Header ---
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: appTheme.primaryColor, width: 2),
                        image: DecorationImage(
                          image: widget.profileImage != null && widget.profileImage!.isNotEmpty
                              ? NetworkImage(widget.profileImage!)
                              : const AssetImage('assets/images/avataruser.png') as ImageProvider,
                          fit: BoxFit.cover,
                        ),
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('@${widget.username}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                      ]),
                    ),
                    IconButton(icon: const Icon(Icons.more_horiz), onPressed: _isDeleting ? null : () => _showMoreOptions(context)),
                  ]),
                ),

                // --- Player / Error ---
                if (_audioError != null)
                  GestureDetector(
                    onTap: () {}, // keep for future retry UI if you want
                    child: Container(
                      height: 100,
                      color: Colors.grey[200],
                      child: Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(_audioError!, style: const TextStyle(color: Colors.black54), textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          const Icon(Icons.refresh, color: Colors.black54),
                        ]),
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      Row(children: [
                        IconButton(
                          icon: Icon(_audioPlayer?.playing ?? false ? Icons.pause : Icons.play_arrow, color: Colors.blue, size: 30),
                          onPressed: _togglePlayPause,
                        ),
                        Expanded(
                          child: MiniWaveformBar(
                            position: _position,
                            duration: _duration,
                            enabled: !_isDeleting && _audioPlayer != null,
                            onSeek: (d) => _audioPlayer?.seek(d),
                            peaks: _realPeaks,                 // leave null for synthetic now
                            seedKey: widget.post?.id ?? '',    // stable visual per post
                            height: 44,
                            padding: const EdgeInsets.only(right: 8),
                          ),
                        ),
                        IconButton(
                          icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.grey, size: 24),
                          onPressed: _toggleMute,
                        ),
                      ]),
                    ],
                  ),

                // --- Actions ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Image.asset(
                              _flagLiked ? 'assets/images/like_filled.png' : 'assets/images/like_outline.png',
                              width: 30,
                              height: 30,
                            ),
                            onPressed: _isDeleting ? null : _toggleLike,
                          ),
                          Text('$_likes'),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: Image.asset('assets/images/comment.png', width: 24, height: 24),
                            onPressed: () => showCommentsBottomSheet(context, postId: widget.post!.id),
                          ),
                          Text('${widget.post!.commentsCount}'),
                          const SizedBox(width: 16),
                          if (!widget.post!.flagOwnPost)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.repeat, color: Colors.green),
                                  onPressed: _isDeleting ? null : _toggleRepost,
                                ),
                                Text('$_reposts'),
                              ],
                            ),
                        ],
                      ),
                      IconButton(
                        icon: Image.asset('assets/images/send.png', width: 24, height: 24),
                        onPressed: _isDeleting ? null : _toggleShare,
                      ),
                    ],
                  ),
                ),

                // --- Texts ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    widget.post?.title ?? 'No title available',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                if (widget.post?.caption != null && widget.post!.caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: Text(widget.post!.caption, style: const TextStyle(fontSize: 14)),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Text(
                    _formatDisplayDate(widget.post?.created ?? ''),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
