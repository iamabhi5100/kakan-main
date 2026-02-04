import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:kakan/config/theme.dart';
import 'package:kakan/features/myfiles/domain/entities/download_entity.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_bloc.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_event.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_state.dart';
import 'package:kakan/features/postmyfeed/data/datasources/post_remote_data_source.dart';
import 'package:kakan/injection_container.dart' as di;

class MainPostScreen extends StatefulWidget {
  const MainPostScreen({super.key});

  @override
  State<MainPostScreen> createState() => _MainPostScreenState();
}

class _MainPostScreenState extends State<MainPostScreen> {
  final ImagePicker _picker = ImagePicker();
  final PostRemoteDataSource _postRemoteDataSource = di.sl<PostRemoteDataSource>();
  bool _isLoading = false;

  Future<void> _showLoading({int minMillis = 500}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await Future.delayed(Duration(milliseconds: minMillis));
  }

  void _hideLoading() {
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  void _showMediaSourceModal(BuildContext context, String mediaType) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MediaSourceSheet(
        mediaType: mediaType,
        onGalleryTap: () {
          Navigator.pop(ctx);
          _pickFromGallery(mediaType);
        },
        onLibraryTap: () {
          Navigator.pop(ctx);
          _showLibraryModal(context, mediaType);
        },
      ),
    );
  }

  Future<void> _pickFromGallery(String mediaType) async {
    try {
      await _showLoading();
      if (mediaType == 'video') {
        final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
        if (file != null) {
          if (!file.path.toLowerCase().endsWith('.mp4')) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Only MP4 videos are allowed.')),
              );
            }
            _hideLoading();
            return;
          }
          if (mounted) {
            final postData = <String, String?>{
              'filePath': file.path,
              'mediaId': null,
              'title': file.name,
            };
            // Push editor while loading overlay is still on
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              context.push('/post-video-editor', extra: postData).then((_) => _hideLoading());
            });
            return;
          }
        }
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['mp3'],
        );
        if (result != null && result.files.single.path != null && mounted) {
          final postData = <String, String?>{
            'filePath': result.files.single.path!,
            'mediaId': null,
            'title': result.files.single.name,
          };
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            context.push('/post-audio-editor', extra: postData).then((_) => _hideLoading());
          });
          return;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking $mediaType: $e')),
        );
      }
    } finally {
      // If we didn’t navigate, make sure to hide
      if (mounted) _hideLoading();
    }
  }

  Future<String?> _downloadMediaFile(String url) async {
    try {
      final localPath = await _postRemoteDataSource.downloadFile(url);
      return localPath;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download media: $e')),
        );
      }
      return null;
    }
  }

  void _showLibraryModal(BuildContext context, String mediaType) {
    context.read<DownloadsBloc>().add(GetDownloadsEvent(mediaType: mediaType));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, controller) => _LibrarySheet(
          mediaType: mediaType,
          scrollController: controller,
          onMediaSelected: (download) async {
            if (download.mediaFile == null || !mounted) return;

            // start overlay immediately and keep it until after navigation completes
            await _showLoading();

            String? localPath = download.mediaFile;
            if (download.mediaFile!.startsWith('http')) {
              localPath = await _downloadMediaFile(download.mediaFile!);
              if (localPath == null) {
                _hideLoading();
                Navigator.pop(modalContext);
                return;
              }
            }

            final postData = <String, String?>{
              'filePath': localPath,
              'mediaId': download.id,
              'title': download.title,
            };
            final route = mediaType == 'video' ? '/post-video-editor' : '/post-audio-editor';

            // Close modal, then navigate; keep loading visible until push() resolves
            Navigator.pop(modalContext);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              context.push(route, extra: postData).then((_) => _hideLoading());
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: appTheme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.white,
            title: Text(
              'Post My Feed',
              style: appTheme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          body: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.post_add_rounded,
                      size: 80,
                      color: appTheme.primaryColor,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Create a New Post',
                      style: appTheme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontSize: 26,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose video or audio to share with your audience',
                      style: appTheme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    _PostOptionCard(
                      title: 'Video Post',
                      subtitle: 'Share a video from your gallery or library',
                      iconData: Icons.videocam,
                      gradientColors: [appTheme.primaryColor, appTheme.primaryColor.withOpacity(0.7)],
                      onTap: () => _showMediaSourceModal(context, 'video'),
                    ),
                    const SizedBox(height: 20),
                    _PostOptionCard(
                      title: 'Audio Post',
                      subtitle: 'Share an audio clip from your files or library',
                      iconData: Icons.audiotrack,
                      gradientColors: const [Color(0xFF00B4DB), Color(0xFF0083B0)],
                      onTap: () => _showMediaSourceModal(context, 'audio'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_isLoading) const ModalBarrier(dismissible: false, color: Colors.black54),
        if (_isLoading) const Center(child: CircularProgressIndicator(color: Colors.white)),
      ],
    );
  }
}

class _PostOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData iconData;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _PostOptionCard({
    required this.title,
    required this.subtitle,
    required this.iconData,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              Icon(iconData, size: 40, color: Colors.white),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaSourceSheet extends StatelessWidget {
  final String mediaType;
  final VoidCallback onGalleryTap;
  final VoidCallback onLibraryTap;

  const _MediaSourceSheet({
    required this.mediaType,
    required this.onGalleryTap,
    required this.onLibraryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose Source', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: appTheme.primaryColor),
              title: const Text('From Gallery'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: onGalleryTap,
            ),
            ListTile(
              leading: Icon(Icons.video_library_rounded, color: appTheme.primaryColor),
              title: const Text('From My Library'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: onLibraryTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _LibrarySheet extends StatelessWidget {
  final String mediaType;
  final ScrollController scrollController;
  final Function(DownloadEntity) onMediaSelected;

  const _LibrarySheet({
    required this.mediaType,
    required this.scrollController,
    required this.onMediaSelected,
  });

  @override
  Widget build(BuildContext context) {
    final title = mediaType == 'video' ? 'Videos' : 'Audios';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$title Library',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: appTheme.primaryColor, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: BlocBuilder<DownloadsBloc, DownloadsState>(
              builder: (context, state) {
                if (state is DownloadsInitial || state is DownloadsLoading) {
                  return _buildShimmerEffect();
                }
                if (state is DownloadsError) {
                  return _buildErrorState(context, state.message);
                }
                if (state is DownloadsLoaded) {
                  if (state.downloads.isEmpty) return _buildEmptyState();
                  return _buildLibraryList(context, state.downloads);
                }
                return _buildShimmerEffect();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryList(BuildContext context, List<DownloadEntity> downloads) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      itemCount: downloads.length,
      itemBuilder: (context, index) {
        final download = downloads[index];
        return GestureDetector(
          onTap: () => onMediaSelected(download),
          child: Card(
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  _buildThumb(download),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          download.title ?? 'Untitled',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(download.duration ?? ''),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildThumb(DownloadEntity d) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        height: 80,
        color: Colors.grey.shade200,
        child: mediaType == 'video' && d.thumbnail != null
            ? Image.network(d.thumbnail!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.error))
            : Icon(mediaType == 'video' ? Icons.videocam : Icons.music_note),
      ),
    );
  }

  Widget _buildShimmerEffect() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        itemCount: 8,
        padding: const EdgeInsets.all(16.0),
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            children: [
              Container(width: 80, height: 80, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: double.infinity, height: 18.0, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(width: 140.0, height: 14.0, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 90, color: Colors.grey),
          const SizedBox(height: 20),
          const Text('Something Went Wrong'),
          Text(message),
          ElevatedButton(
            onPressed: () => context.read<DownloadsBloc>().add(GetDownloadsEvent(mediaType: mediaType)),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(mediaType == 'video' ? Icons.video_library : Icons.audiotrack, size: 90, color: Colors.grey),
          const SizedBox(height: 20),
          Text('Library is Empty'),
          Text('You have not downloaded any $mediaType yet.'),
        ],
      ),
    );
  }
}
