import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Simple image editor for carousel: shows image and "Use" button that pops with path.
/// (Cropping can be added later with image_cropper.)
class PostImageEditorScreen extends StatelessWidget {
  final String filePath;

  const PostImageEditorScreen({super.key, required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Image'),
        actions: [
          TextButton(
            onPressed: () => context.pop(filePath),
            child: const Text('Use'),
          ),
        ],
      ),
      body: Center(
        child: filePath.startsWith('http')
            ? Image.network(
                filePath,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 64),
              )
            : Image.file(
                File(filePath),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 64),
              ),
      ),
    );
  }
}
