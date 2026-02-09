import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import 'package:kakan/config/theme.dart';
import 'package:kakan/features/myfiles/domain/entities/download_entity.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_bloc.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_event.dart';
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

  Future<void> _addFromCamera() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Capture with camera',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Record a video or take a photo',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF5856D6),
                  child: Icon(Icons.videocam_rounded, color: Colors.white),
                ),
                title: const Text('Record video'),
                subtitle: const Text('Capture a new video'),
                onTap: () => Navigator.pop(ctx, 'video'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF5856D6),
                  child: Icon(Icons.camera_alt_rounded, color: Colors.white),
                ),
                title: const Text('Take photo'),
                subtitle: const Text('Capture a new photo'),
                onTap: () => Navigator.pop(ctx, 'photo'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    try {
      final picker = ImagePicker();
      if (choice == 'video') {
        final xFile = await picker.pickVideo(source: ImageSource.camera);
        if (xFile != null && mounted) {
          setState(() => _items.add(SelectedMediaItem(
                path: xFile.path,
                type: 'video',
                name: 'Camera video',
              )));
        }
      } else {
        final xFile = await picker.pickImage(source: ImageSource.camera);
        if (xFile != null && mounted) {
          setState(() => _items.add(SelectedMediaItem(
                path: xFile.path,
                type: 'image',
                name: 'Camera photo',
              )));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  void _openLibrary() {
    // Trigger API fetch so library list shows downloads (videos for carousel)
    context.read<DownloadsBloc>().add(GetDownloadsEvent(mediaType: 'video'));
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
    final primary = appTheme.primaryColor;
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
          color: Colors.black87,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected Items',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    fontSize: 20,
                    letterSpacing: -0.3,
                  ),
            ),
            if (_items.isNotEmpty)
              Text(
                '${_items.length} ${_items.length == 1 ? 'item' : 'items'} • Drag to reorder',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
              ),
          ],
        ),
        titleSpacing: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _items.isEmpty ? _buildEmptyState(primary) : _buildList(primary),
          ),
          _buildBottomSection(primary),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color primary) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.photo_library_outlined,
                size: 48,
                color: primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No items yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    fontSize: 22,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add photos or videos from your gallery,\nlibrary, or capture with camera.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _AddSourceCard(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    gradientColors: [
                      primary,
                      Color.lerp(primary, const Color(0xFF6B6BD6), 0.4)!,
                    ],
                    onTap: _addFromGallery,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _AddSourceCard(
                    icon: Icons.video_library_rounded,
                    label: 'Library',
                    gradientColors: [
                      const Color(0xFF5B6B8A),
                      const Color(0xFF3D4D6B),
                    ],
                    onTap: _openLibrary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _AddSourceCard(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    gradientColors: [
                      const Color(0xFF2E7D32),
                      const Color(0xFF1B5E20),
                    ],
                    onTap: _addFromCamera,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(Color primary) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
          primary: primary,
          onEdit: () => _onEdit(index),
          onRemove: () => _removeAt(index),
        );
      },
    );
  }

  Widget _buildBottomSection(Color primary) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _AddSourceCard(
                  icon: Icons.add_photo_alternate_rounded,
                  label: 'Gallery',
                  gradientColors: [
                    primary.withValues(alpha: 0.9),
                    Color.lerp(primary, const Color(0xFF6B6BD6), 0.5)!,
                  ],
                  onTap: _addFromGallery,
                  compact: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AddSourceCard(
                  icon: Icons.video_library_rounded,
                  label: 'Library',
                  gradientColors: [
                    const Color(0xFF5B6B8A),
                    const Color(0xFF3D4D6B),
                  ],
                  onTap: _openLibrary,
                  compact: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AddSourceCard(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  gradientColors: [
                    const Color(0xFF2E7D32),
                    const Color(0xFF1B5E20),
                  ],
                  onTap: _addFromCamera,
                  compact: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _items.isEmpty ? null : _onNext,
            style: FilledButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _items.isEmpty ? 'Add items to continue' : 'Next',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_items.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddSourceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> gradientColors;
  final VoidCallback onTap;
  final bool compact;

  const _AddSourceCard({
    required this.icon,
    required this.label,
    required this.gradientColors,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 14 : 18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 14 : 18),
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withValues(alpha: 0.35),
                blurRadius: compact ? 8 : 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 20,
              vertical: compact ? 12 : 16,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: compact ? 22 : 26),
                SizedBox(width: compact ? 8 : 12),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 14 : 16,
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

class _SelectedItemTile extends StatelessWidget {
  final int index;
  final SelectedMediaItem item;
  final Color primary;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _SelectedItemTile({
    super.key,
    required this.index,
    required this.item,
    required this.primary,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.drag_handle_rounded, color: Colors.grey.shade600, size: 22),
                  ),
                ),
                _Thumbnail(path: item.path, isVideo: item.isVideo),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (item.isVideo ? Colors.amber : Colors.blue).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.isVideo ? 'Video' : 'Photo',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: item.isVideo ? Colors.amber.shade800 : Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ActionButton(
                      icon: Icons.edit_rounded,
                      label: 'Edit',
                      color: primary,
                      onTap: onEdit,
                    ),
                    const SizedBox(height: 6),
                    _ActionButton(
                      icon: Icons.delete_outline_rounded,
                      label: 'Remove',
                      color: Colors.red.shade400,
                      onTap: onRemove,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
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
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: isVideo
                ? _VideoThumb(path: path)
                : (path.startsWith('http')
                    ? Image.network(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder())
                    : Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder())),
          ),
          if (isVideo)
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
              ),
              child: const Icon(Icons.play_circle_filled_rounded, color: Colors.white, size: 32),
            ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade200,
      child: Icon(isVideo ? Icons.videocam_rounded : Icons.image_rounded, color: Colors.grey.shade500, size: 28),
    );
  }
}

class _VideoThumb extends StatelessWidget {
  final String path;

  const _VideoThumb({required this.path});

  @override
  Widget build(BuildContext context) {
    if (path.startsWith('http')) {
      return Image.network(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.videocam_rounded, size: 28));
    }
    return Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.videocam_rounded, size: 28));
  }
}
