import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

// ---- your DI + bloc contracts (from old code) ----
import 'package:kakan/injection_container.dart' as di;
import 'package:kakan/features/postmyfeed/presentation/bloc/post_bloc/post_bloc.dart';
import 'package:kakan/features/postmyfeed/presentation/bloc/post_bloc/post_event.dart';
import 'package:kakan/features/postmyfeed/presentation/bloc/post_bloc/post_state.dart';

class VideoPostScreen extends StatefulWidget {
  final String filePath;      // safe transcoded path (required)
  final String? mediaId;      // optional
  final String? title;        // optional (prefill)

  const VideoPostScreen({
    super.key,
    required this.filePath,
    this.mediaId,
    this.title,
  });

  @override
  State<VideoPostScreen> createState() => _VideoPostScreenState();
}

class _VideoPostScreenState extends State<VideoPostScreen> {
  // --- Dark theme palette (matches your editor screen vibes) ---
  static const Color _bg       = Color(0xFF0F1115);
  static const Color _card     = Color(0xFF171A20);
  static const Color _muted    = Color(0xFF9AA4B2);
  static const Color _text     = Color(0xFFE6EAF2);
  static const Color _accent   = Color(0xFF00E5A8);
  static const Color _accent2  = Color(0xFF4C82FB);
  static const Color _fieldBg  = Color(0xFF141821);
  static const Color _border   = Color(0xFF2A3242);
  static const Color _overlay  = Color(0x88000000);

  late final TextEditingController _title;
  final TextEditingController _caption = TextEditingController();
  late final VideoPlayerController _vp;

  bool _videoReady = false;
  String _shareTo = 'all'; // 'all' | 'followers'

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.title ?? '');
    _vp = VideoPlayerController.file(File(widget.filePath))
      ..setLooping(true)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _videoReady = true);
      });
  }

  @override
  void dispose() {
    _vp.dispose();
    _title.dispose();
    _caption.dispose();
    super.dispose();
  }

  ThemeData _theme(BuildContext context) {
    return Theme.of(context).copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _bg,
      colorScheme: const ColorScheme.dark(
        primary: _accent,
        secondary: _accent2,
        surface: _card,
        background: _bg,
      ),
      textTheme: Theme.of(context).textTheme.apply(
            bodyColor: _text,
            displayColor: _text,
          ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF232A36),
        contentTextStyle: TextStyle(color: _text),
        behavior: SnackBarBehavior.floating,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _bg,
        foregroundColor: _text,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _fieldBg,
        labelStyle: const TextStyle(color: _muted),
        hintStyle: const TextStyle(color: _muted),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _border),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _accent),
          borderRadius: BorderRadius.circular(12),
        ),
        counterStyle: const TextStyle(color: _muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: _bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
        ),
      ),
      chipTheme: ChipTheme.of(context).copyWith(
        backgroundColor: const Color(0xFF141821),
        selectedColor: const Color(0xFF1E2430),
        labelStyle: const TextStyle(color: _text, fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(color: _text),
        side: const BorderSide(color: _border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _accent,
      ),
    );
  }

  bool _canShare(PostState state) {
    final hasTitle = _title.text.trim().isNotEmpty;
    final hasShareTo = _shareTo == 'all' || _shareTo == 'followers';
    final fileExists = widget.filePath.isNotEmpty;
    final notLoading = state is! PostLoading;
    return hasTitle && hasShareTo && fileExists && notLoading;
  }

  void _onSharePressed(BuildContext context) {
    FocusScope.of(context).unfocus();
    context.read<PostBloc>().add(
          CreatePostEvent(
            mediaType: 'video',
            title: _title.text.trim(),
            caption:
                _caption.text.trim().isEmpty ? null : _caption.text.trim(),
            mediaFilePath: widget.filePath, // local file path
            mediaId: widget.mediaId,       // optional
            shareTo: _shareTo,             // 'all' | 'followers'
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _theme(context),
      child: BlocProvider(
        create: (_) => di.sl<PostBloc>(),
        child: BlocListener<PostBloc, PostState>(
          listener: (context, state) {
            if (state is PostCreated) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Posted successfully!')),
              );
              context.go('/home');
            } else if (state is PostError) {
              var msg = state.message;
              if (msg.contains('Media file is required')) {
                msg = 'Media file is required. Please select a valid video.';
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to post: $msg')),
              );
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('New Post'),
              actions: [
                IconButton(
                  onPressed: !_videoReady
                      ? null
                      : () => setState(() {
                            if (_vp.value.isPlaying) {
                              _vp.pause();
                            } else {
                              _vp.play();
                            }
                          }),
                  icon: Icon(_vp.value.isPlaying ? Icons.pause : Icons.play_arrow),
                  tooltip: _vp.value.isPlaying ? 'Pause' : 'Play',
                ),
                const SizedBox(width: 4),
              ],
            ),
            body: BlocBuilder<PostBloc, PostState>(
              builder: (context, state) {
                final isLoading = state is PostLoading;

                return Stack(
                  children: [
                    ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        // Video Preview Card
                        Container(
                          decoration: BoxDecoration(
                            color: _card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _border),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x55000000),
                                blurRadius: 14,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: AspectRatio(
                            aspectRatio: _videoReady
                                ? _vp.value.aspectRatio
                                : 16 / 9,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                _videoReady
                                    ? VideoPlayer(_vp)
                                    : const ColoredBox(color: Color(0x11000000)),
                                // Play/Pause Overlay
                                AnimatedOpacity(
                                  opacity: _videoReady && !_vp.value.isPlaying ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(.35),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      iconSize: 64,
                                      color: Colors.white,
                                      icon: const Icon(Icons.play_arrow_rounded),
                                      onPressed: () {
                                        setState(() => _vp.play());
                                      },
                                    ),
                                  ),
                                ),
                                if (!_videoReady)
                                  const Positioned.fill(
                                    child: ColoredBox(
                                      color: Color(0x33000000),
                                      child: Center(child: CircularProgressIndicator()),
                                    ),
                                  ),
                                if (isLoading)
                                  const Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: LinearProgressIndicator(minHeight: 4),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Title
                        TextField(
                          controller: _title,
                          maxLength: 50,
                          style: const TextStyle(color: _text, fontWeight: FontWeight.w600),
                          decoration: const InputDecoration(
                            labelText: 'Title*',
                            hintText: 'Give your video a short title',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),

                        const SizedBox(height: 12),

                        // Caption
                        TextField(
                          controller: _caption,
                          maxLength: 500,
                          maxLines: 5,
                          style: const TextStyle(color: _text),
                          decoration: const InputDecoration(
                            labelText: 'Caption (Optional)',
                            hintText: 'Describe your post, add tags or mentions…',
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Visibility (share to)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Visibility',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: _muted,
                                      fontWeight: FontWeight.w600,
                                    )),
                            Text(
                              _shareTo == 'all' ? 'Public' : 'Followers',
                              style: const TextStyle(color: _text, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('All'),
                              selected: _shareTo == 'all',
                              selectedColor: const Color(0xFF1E2430),
                              onSelected: (v) => setState(() => _shareTo = 'all'),
                              side: BorderSide(
                                color: _shareTo == 'all' ? _accent : _border,
                                width: _shareTo == 'all' ? 1.4 : 1.0,
                              ),
                            ),
                            ChoiceChip(
                              label: const Text('My Followers'),
                              selected: _shareTo == 'followers',
                              selectedColor: const Color(0xFF1E2430),
                              onSelected: (v) => setState(() => _shareTo = 'followers'),
                              side: BorderSide(
                                color: _shareTo == 'followers' ? _accent : _border,
                                width: _shareTo == 'followers' ? 1.4 : 1.0,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Share button
                        ElevatedButton.icon(
                          onPressed: _canShare(state) ? () => _onSharePressed(context) : null,
                          icon: const Icon(Icons.send_rounded),
                          label: isLoading
                              ? const Text('Posting…')
                              : const Text('Share'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _canShare(state) ? _accent : const Color(0xFF2D3444),
                            foregroundColor: _bg,
                          ),
                        ),
                      ],
                    ),

                    // Fullscreen overlay while loading but before progress appears
                    if (isLoading)
                      const Positioned.fill(
                        child: IgnorePointer(
                          ignoring: true,
                          child: ColoredBox(
                            color: _overlay,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
