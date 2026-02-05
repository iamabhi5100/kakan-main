import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:kakan/injection_container.dart' as di;
import 'package:kakan/features/postmyfeed/presentation/bloc/post_bloc/post_bloc.dart';
import 'package:kakan/features/postmyfeed/presentation/bloc/post_bloc/post_event.dart';
import 'package:kakan/features/postmyfeed/presentation/bloc/post_bloc/post_state.dart';

class ImagePostScreen extends StatefulWidget {
  final String filePath;
  final String? mediaId;
  final String? title;

  const ImagePostScreen({
    super.key,
    required this.filePath,
    this.mediaId,
    this.title,
  });

  @override
  State<ImagePostScreen> createState() => _ImagePostScreenState();
}

class _ImagePostScreenState extends State<ImagePostScreen> {
  static const Color _bg = Color(0xFF0F1115);
  static const Color _card = Color(0xFF171A20);
  static const Color _muted = Color(0xFF9AA4B2);
  static const Color _text = Color(0xFFE6EAF2);
  static const Color _accent = Color(0xFF00E5A8);
  static const Color _fieldBg = Color(0xFF141821);
  static const Color _border = Color(0xFF2A3242);
  static const Color _overlay = Color(0x88000000);

  late final TextEditingController _title;
  final TextEditingController _caption = TextEditingController();
  String _shareTo = 'all';

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.title ?? '');
  }

  @override
  void dispose() {
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
        side: const BorderSide(color: _border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            mediaType: 'image',
            title: _title.text.trim(),
            caption: _caption.text.trim().isEmpty ? null : _caption.text.trim(),
            mediaFilePath: widget.filePath,
            mediaId: widget.mediaId,
            shareTo: _shareTo,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.filePath);
    final imageExists = file.existsSync();

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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to post: ${state.message}')),
              );
            }
          },
          child: Scaffold(
            appBar: AppBar(title: const Text('New Post')),
            body: BlocBuilder<PostBloc, PostState>(
              builder: (context, state) {
                final isLoading = state is PostLoading;
                return Stack(
                  children: [
                    ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        // Image Preview
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
                            aspectRatio: 1,
                            child: imageExists
                                ? Image.file(file, fit: BoxFit.cover)
                                : const Center(
                                    child: Icon(Icons.broken_image, color: _muted, size: 48),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _title,
                          maxLength: 50,
                          style: const TextStyle(color: _text, fontWeight: FontWeight.w600),
                          decoration: const InputDecoration(
                            labelText: 'Title*',
                            hintText: 'Give your photo a short title',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _caption,
                          maxLength: 500,
                          maxLines: 5,
                          style: const TextStyle(color: _text),
                          decoration: const InputDecoration(
                            labelText: 'Caption (Optional)',
                            hintText: 'Describe your post…',
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Visibility',
                          style: TextStyle(color: _muted, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Public'),
                              selected: _shareTo == 'all',
                              onSelected: (_) => setState(() => _shareTo = 'all'),
                              side: BorderSide(
                                color: _shareTo == 'all' ? _accent : _border,
                                width: _shareTo == 'all' ? 1.4 : 1.0,
                              ),
                            ),
                            ChoiceChip(
                              label: const Text('Followers'),
                              selected: _shareTo == 'followers',
                              onSelected: (_) => setState(() => _shareTo = 'followers'),
                              side: BorderSide(
                                color: _shareTo == 'followers' ? _accent : _border,
                                width: _shareTo == 'followers' ? 1.4 : 1.0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _canShare(state) ? () => _onSharePressed(context) : null,
                          icon: const Icon(Icons.send_rounded),
                          label: isLoading ? const Text('Posting…') : const Text('Share'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _canShare(state) ? _accent : const Color(0xFF2D3444),
                            foregroundColor: _bg,
                          ),
                        ),
                      ],
                    ),
                    if (isLoading)
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: ColoredBox(color: _overlay),
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
