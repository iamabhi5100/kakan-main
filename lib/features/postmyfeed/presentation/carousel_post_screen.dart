import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import 'package:kakan/features/postmyfeed/data/models/selected_media_item.dart';
import 'package:kakan/features/postmyfeed/domain/entities/carousel_media_item_entity.dart';
import 'package:kakan/features/postmyfeed/presentation/bloc/post_bloc/post_bloc.dart';
import 'package:kakan/features/postmyfeed/presentation/bloc/post_bloc/post_event.dart';
import 'package:kakan/features/postmyfeed/presentation/bloc/post_bloc/post_state.dart';

class CarouselPostScreen extends StatefulWidget {
  final List<SelectedMediaItem> items;

  const CarouselPostScreen({super.key, required this.items});

  @override
  State<CarouselPostScreen> createState() => _CarouselPostScreenState();
}

class _CarouselPostScreenState extends State<CarouselPostScreen> {
  static const Color _bg = Color(0xFF0D0E12);
  static const Color _card = Color(0xFF16181D);
  static const Color _muted = Color(0xFF8B92A0);
  static const Color _text = Color(0xFFE8EAEF);
  static const Color _accent = Color(0xFF00D9A5);
  static const Color _fieldBg = Color(0xFF1C1F26);
  static const Color _border = Color(0xFF2C3142);
  static const Color _surface = Color(0xFF22262E);

  late final PageController _pageController;
  late final TextEditingController _titleController;
  final TextEditingController _captionController = TextEditingController();
  String _shareTo = 'all';
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _titleController = TextEditingController();
    _pageController.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    final page = _pageController.page;
    if (page != null) {
      final index = page.round();
      if (index != _currentPage && index >= 0 && index < widget.items.length) {
        setState(() => _currentPage = index);
      }
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    _titleController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  List<CarouselMediaItemEntity> _toEntities() {
    return widget.items
        .map((e) => CarouselMediaItemEntity(
              path: e.path,
              type: e.type,
              name: e.name,
              mediaId: e.mediaId,
            ))
        .toList();
  }

  void _onShare() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }
    context.read<PostBloc>().add(CreatePostCarouselEvent(
          title: title,
          caption: _captionController.text.trim().isEmpty ? null : _captionController.text.trim(),
          shareTo: _shareTo,
          items: _toEntities(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PostBloc, PostState>(
      listener: (context, state) {
        if (state is PostCreated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post shared successfully')),
          );
          context.go('/home');
        }
        if (state is PostError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      child: Theme(
        data: Theme.of(context).copyWith(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: _bg,
          colorScheme: const ColorScheme.dark(primary: _accent, surface: _card, background: _bg),
          textTheme: Theme.of(context).textTheme.apply(bodyColor: _text, displayColor: _text),
          appBarTheme: const AppBarTheme(backgroundColor: _bg, foregroundColor: _text, elevation: 0, centerTitle: true),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: _fieldBg,
            labelStyle: const TextStyle(color: _muted),
            hintStyle: const TextStyle(color: _muted),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: _border),
              borderRadius: BorderRadius.circular(14),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: _accent, width: 1.5),
              borderRadius: BorderRadius.circular(14),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        child: Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            title: const Text('New carousel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => context.pop(),
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                // —— Media carousel ——
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Container(
                    height: 320,
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: widget.items.length,
                        itemBuilder: (context, index) {
                          final item = widget.items[index];
                          return Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: item.isVideo
                                  ? _CarouselVideoPlayer(
                                      path: item.path,
                                      isActive: index == _currentPage,
                                    )
                                  : (item.path.startsWith('http')
                                      ? Image.network(
                                          item.path,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) => const _MediaErrorPlaceholder(isVideo: false),
                                        )
                                      : Image.file(
                                          File(item.path),
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) => const _MediaErrorPlaceholder(isVideo: false),
                                        )),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                // —— Page indicators ——
                if (widget.items.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        widget.items.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _currentPage ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: i == _currentPage ? _accent : _muted.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
                  ),
                // —— Form ——
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Details',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            hintText: 'Give your post a title',
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _captionController,
                          decoration: const InputDecoration(
                            labelText: 'Caption (optional)',
                            hintText: 'Add a caption...',
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Who can see this',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _VisibilityChip(
                                label: 'Public',
                                selected: _shareTo == 'all',
                                onTap: () => setState(() => _shareTo = 'all'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _VisibilityChip(
                                label: 'Followers',
                                selected: _shareTo == 'followers',
                                onTap: () => setState(() => _shareTo = 'followers'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        BlocBuilder<PostBloc, PostState>(
                          builder: (context, state) {
                            final loading = state is PostLoading;
                            return FilledButton(
                              onPressed: loading ? null : _onShare,
                              style: FilledButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: _bg,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: loading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: _bg),
                                    )
                                  : const Text('Share carousel', style: TextStyle(fontWeight: FontWeight.w600)),
                            );
                          },
                        ),
                      ],
                    ),
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

/// Real video player for one carousel slide. Only initializes when this page is active.
class _CarouselVideoPlayer extends StatefulWidget {
  final String path;
  final bool isActive;

  const _CarouselVideoPlayer({required this.path, required this.isActive});

  @override
  State<_CarouselVideoPlayer> createState() => _CarouselVideoPlayerState();
}

class _CarouselVideoPlayerState extends State<_CarouselVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _error = false;

  @override
  void didUpdateWidget(covariant _CarouselVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive) {
      _pauseAndDispose();
    } else if (!oldWidget.isActive && widget.isActive) {
      _initVideo();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _initVideo();
  }

  Future<void> _initVideo() async {
    if (_controller != null || widget.path.isEmpty) return;
    setState(() => _error = false);
    final VideoPlayerController c;
    if (widget.path.startsWith('http')) {
      c = VideoPlayerController.networkUrl(Uri.parse(widget.path));
    } else {
      c = VideoPlayerController.file(File(widget.path));
    }
    _controller = c;
    try {
      await c.initialize();
      if (!mounted) return;
      setState(() {
        _initialized = true;
        _error = false;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Carousel video init error: $e');
      if (!mounted) return;
      setState(() {
        _initialized = false;
        _error = true;
      });
    }
  }

  void _pauseAndDispose() {
    _controller?.pause();
    _controller?.dispose();
    _controller = null;
    _initialized = false;
  }

  @override
  void dispose() {
    _pauseAndDispose();
    super.dispose();
  }

  void _togglePlayPause() {
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return _VideoThumbnailPlaceholder(path: widget.path);
    }
    if (_error) {
      return Container(
        color: const Color(0xFF1C1F26),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFF8B92A0)),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _initVideo,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (!_initialized || _controller == null) {
      return Container(
        color: const Color(0xFF1C1F26),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF00D9A5)),
        ),
      );
    }
    final c = _controller!;
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: c.value.aspectRatio,
              child: VideoPlayer(c),
            ),
          ),
          if (!c.value.isPlaying)
            Icon(
              Icons.play_circle_fill_rounded,
              size: 72,
              color: Colors.white.withOpacity(0.9),
            ),
        ],
      ),
    );
  }
}

class _VideoThumbnailPlaceholder extends StatelessWidget {
  final String path;

  const _VideoThumbnailPlaceholder({required this.path});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1C1F26),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (path.startsWith('http'))
            Image.network(
              path,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.expand(),
            )
          else
            Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.expand(),
            ),
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: Icon(Icons.play_circle_filled_rounded, size: 64, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaErrorPlaceholder extends StatelessWidget {
  final bool isVideo;

  const _MediaErrorPlaceholder({required this.isVideo});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1C1F26),
      child: Center(
        child: Icon(
          isVideo ? Icons.videocam_off_rounded : Icons.broken_image_rounded,
          size: 56,
          color: const Color(0xFF8B92A0),
        ),
      ),
    );
  }
}

class _VisibilityChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _VisibilityChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF00D9A5);
    const border = Color(0xFF2C3142);
    const muted = Color(0xFF8B92A0);
    return Material(
      color: selected ? accent.withOpacity(0.15) : const Color(0xFF1C1F26),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accent : border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? accent : muted,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
