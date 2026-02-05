import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
  static const Color _bg = Color(0xFF0F1115);
  static const Color _card = Color(0xFF171A20);
  static const Color _muted = Color(0xFF9AA4B2);
  static const Color _text = Color(0xFFE6EAF2);
  static const Color _accent = Color(0xFF00E5A8);
  static const Color _fieldBg = Color(0xFF141821);
  static const Color _border = Color(0xFF2A3242);

  late final PageController _pageController;
  late final TextEditingController _titleController;
  final TextEditingController _captionController = TextEditingController();
  String _shareTo = 'all';

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _titleController = TextEditingController();
  }

  @override
  void dispose() {
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
          appBarTheme: const AppBarTheme(backgroundColor: _bg, foregroundColor: _text, elevation: 0),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: _fieldBg,
            labelStyle: const TextStyle(color: _muted),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: _border),
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: _accent),
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        child: Scaffold(
          appBar: AppBar(title: const Text('Carousel Post')),
          body: SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: 280,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: widget.items.length,
                    itemBuilder: (context, index) {
                      final item = widget.items[index];
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: item.isVideo
                              ? _VideoPlaceholder(path: item.path)
                              : (item.path.startsWith('http')
                                  ? Image.network(item.path, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 64))
                                  : Image.file(File(item.path), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 64))),
                        ),
                      );
                    },
                  ),
                ),
                if (widget.items.length > 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        widget.items.length,
                        (i) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _muted.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(labelText: 'Title'),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _captionController,
                          decoration: const InputDecoration(labelText: 'Caption (optional)'),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        const Text('Visibility', style: TextStyle(color: _muted, fontSize: 12)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Public'),
                              selected: _shareTo == 'all',
                              onSelected: (_) => setState(() => _shareTo = 'all'),
                            ),
                            const SizedBox(width: 12),
                            ChoiceChip(
                              label: const Text('Followers'),
                              selected: _shareTo == 'followers',
                              onSelected: (_) => setState(() => _shareTo = 'followers'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        BlocBuilder<PostBloc, PostState>(
                          builder: (context, state) {
                            final loading = state is PostLoading;
                            return FilledButton(
                              onPressed: loading ? null : _onShare,
                              child: loading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Share'),
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

class _VideoPlaceholder extends StatelessWidget {
  final String path;

  const _VideoPlaceholder({required this.path});

  @override
  Widget build(BuildContext context) {
    if (path.startsWith('http')) {
      return Image.network(path, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.videocam, size: 64));
    }
    return Image.file(File(path), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.videocam, size: 64));
  }
}
