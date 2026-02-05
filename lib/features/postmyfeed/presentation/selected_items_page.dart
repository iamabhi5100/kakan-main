import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import 'package:kakan/config/theme.dart';
import 'package:kakan/features/myfiles/domain/entities/download_entity.dart';
import 'package:kakan/features/postmyfeed/data/datasources/post_remote_data_source.dart';
import 'package:kakan/features/postmyfeed/data/models/selected_media_item.dart';
import 'package:kakan/features/postmyfeed/presentation/widgets/library_picker_sheet.dart';
import 'package:kakan/injection_container.dart' as di;

class SelectedItemsPage extends StatefulWidget {
  final List<SelectedMediaItem> initialItems;

  const SelectedItemsPage({
    super.key,
    this.initialItems = const [],
  });

  @override
  State<SelectedItemsPage> createState() => _SelectedItemsPageState();
}

class _SelectedItemsPageState extends State<SelectedItemsPage> {
  late List<SelectedMediaItem> _items;
  final PostRemoteDataSource _postRemoteDataSource = di.sl<PostRemoteDataSource>();

  static const List<String> _imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'];
  static const List<String> _videoExtensions = ['mp4', 'mov', 'm4v', 'avi', 'mkv'];

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.initialItems);
  }

  void _removeAt(int index) {
    setState(() {
      _items.removeAt(index);
      if (_items.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.pop();
        });
      }
    });
  }

  void _replaceAt(int index, SelectedMediaItem newItem) {
    setState(() => _items[index] = newItem);
  }

  Future<void> _addFromGallery() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [..._imageExtensions, ..._videoExtensions],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final list = <SelectedMediaItem>[];
    for (final f in result.files) {
      final path = f.path;
      if (path == null) continue;
      final ext = p.extension(path).toLowerCase().replaceFirst('.', '');
      final type = _videoExtensions.contains(ext) ? 'video' : 'image';
      list.add(SelectedMediaItem(path: path, type: type, name: f.name));
    }
    setState(() => _items.addAll(list));
  }

  void _openLibrary() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, controller) => LibraryPickerSheet(
          mediaType: 'video',
          scrollController: controller,
          onMediaSelected: (DownloadEntity download) async {
            final mediaFile = download.mediaFile;
            if (mediaFile == null || mediaFile.isEmpty) return;
            String localPath = mediaFile;
            if (mediaFile.startsWith('http')) {
              final downloaded = await _postRemoteDataSource.downloadFile(mediaFile);
              if (!mounted) return;
              localPath = downloaded;
            }
            final item = SelectedMediaItem(
              path: localPath,
              type: 'video',
              name: download.title ?? 'Video',
              mediaId: download.id,
            );
            if (mounted) {
              setState(() => _items.add(item));
              Navigator.pop(ctx);
            }
          },
        ),
      ),
    );
  }

  Future<void> _onEdit(int index) async {
    final item = _items[index];
    if (item.isVideo) {
      final result = await context.push<Map<String, dynamic>>(
        '/post-video-editor',
        extra: {
          'filePath': item.path,
          'mediaId': item.mediaId,
          'title': item.name,
          'fromCarousel': true,
        },
      );
      if (result != null && result['filePath'] != null && mounted) {
        _replaceAt(index, item.copyWith(path: result['filePath'] as String));
      }
    } else {
      final result = await context.push<String?>(
        '/post-image-editor',
        extra: {'filePath': item.path},
      );
      if (result != null && mounted) {
        _replaceAt(index, item.copyWith(path: result));
      }
    }
  }

  void _onNext() {
    if (_items.isEmpty) return;
    context.push('/carousel-post', extra: _items);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'Selected Items',
          style: appTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Text(
                      'No items selected. Add from Gallery or Library.',
                      style: appTheme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _items.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = _items.removeAt(oldIndex);
                        _items.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _SelectedItemTile(
                        key: ValueKey('${item.path}_$index'),
                        index: index,
                        item: item,
                        onEdit: () => _onEdit(index),
                        onRemove: () => _removeAt(index),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addFromGallery,
                        icon: const Icon(Icons.photo_library_rounded),
                        label: const Text('Gallery'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openLibrary,
                        icon: const Icon(Icons.video_library_rounded),
                        label: const Text('Library'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _items.isEmpty ? null : _onNext,
                  child: const Text('Next'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedItemTile extends StatelessWidget {
  final int index;
  final SelectedMediaItem item;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _SelectedItemTile({
    super.key,
    required this.index,
    required this.item,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Icon(Icons.drag_handle, color: Colors.grey[600]),
            ),
            const SizedBox(width: 8),
            _Thumbnail(path: item.path, isVideo: item.isVideo),
          ],
        ),
        title: Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String path;
  final bool isVideo;

  const _Thumbnail({required this.path, required this.isVideo});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 56,
        height: 56,
        child: isVideo
            ? _VideoThumb(path: path)
            : (path.startsWith('http')
                ? Image.network(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image))
                : Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image))),
      ),
    );
  }
}

class _VideoThumb extends StatelessWidget {
  final String path;

  const _VideoThumb({required this.path});

  @override
  Widget build(BuildContext context) {
    if (path.startsWith('http')) {
      return Image.network(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.videocam));
    }
    return Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.videocam));
  }
}
