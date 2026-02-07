import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:kakan/config/theme.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_bloc.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_event.dart';
import 'package:kakan/features/postmyfeed/data/datasources/post_remote_data_source.dart';
import 'package:kakan/features/postmyfeed/data/models/selected_media_item.dart';
import 'package:kakan/features/postmyfeed/presentation/widgets/library_picker_sheet.dart';
import 'package:kakan/injection_container.dart' as di;

class MainPostScreen extends StatefulWidget {
  const MainPostScreen({super.key});

  @override
  State<MainPostScreen> createState() => _MainPostScreenState();
}

class _MainPostScreenState extends State<MainPostScreen> {
  final PostRemoteDataSource _postRemoteDataSource = di.sl<PostRemoteDataSource>();

  static const List<String> _galleryImageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'];
  static const List<String> _galleryVideoExtensions = ['mp4', 'mov', 'm4v'];
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
        // From Gallery: allow both photos and videos, multiple selection → Selected Items page
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: [..._galleryImageExtensions, ..._galleryVideoExtensions],
          allowMultiple: true,
        );
        if (result != null && result.files.isNotEmpty && mounted) {
          final items = <SelectedMediaItem>[];
          for (final f in result.files) {
            final path = f.path;
            if (path == null) continue;
            final ext = p.extension(path).toLowerCase().replaceFirst('.', '');
            final isVideo = _galleryVideoExtensions.contains(ext);
            final isImage = _galleryImageExtensions.contains(ext);
            if (!isVideo && !isImage) continue;
            items.add(SelectedMediaItem(
              path: path,
              type: isVideo ? 'video' : 'image',
              name: f.name,
            ));
          }
          _hideLoading();
          if (items.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please select one or more photos or videos.')),
            );
            return;
          }
          context.push('/selected-items', extra: items).then((_) => _hideLoading());
          return;
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
        builder: (_, controller) => LibraryPickerSheet(
          mediaType: mediaType,
          scrollController: controller,
          onMediaSelected: (download) async {
            final mediaFile = download.mediaFile;
            if (mediaFile == null || mediaFile.isEmpty || !mounted) return;

            // Close modal first so loading overlay is visible on the screen behind
            Navigator.pop(modalContext);
            await Future<void>.delayed(const Duration(milliseconds: 50));

            if (!mounted) return;
            await _showLoading();

            String localPath = mediaFile;
            if (mediaFile.startsWith('http')) {
              final downloaded = await _downloadMediaFile(mediaFile);
              if (downloaded == null) {
                _hideLoading();
                return;
              }
              localPath = downloaded;
            }
            if (!mounted) return;

            if (mediaType == 'video') {
              final items = [
                SelectedMediaItem(
                  path: localPath,
                  type: 'video',
                  name: download.title ?? 'Video',
                  mediaId: download.id,
                ),
              ];
              context.push('/selected-items', extra: items).then((_) => _hideLoading());
            } else {
              final postData = <String, String?>{
                'filePath': localPath,
                'mediaId': download.id,
                'title': download.title ?? '',
              };
              context.push('/post-audio-editor', extra: postData).then((_) => _hideLoading());
            }
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
    final primary = appTheme.primaryColor;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Choose Source',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      letterSpacing: -0.3,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pick where to get your ${mediaType == 'video' ? 'photos or videos' : 'audio'} from',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
              ),
              const SizedBox(height: 24),
              _SourceOptionCard(
                icon: Icons.photo_library_rounded,
                title: 'From Gallery',
                subtitle: 'Choose from your device photos & videos',
                gradientColors: [
                  primary,
                  Color.lerp(primary, const Color(0xFF6B6BD6), 0.4)!,
                ],
                onTap: onGalleryTap,
              ),
              const SizedBox(height: 14),
              _SourceOptionCard(
                icon: Icons.video_library_rounded,
                title: 'From My Library',
                subtitle: 'Use videos you’ve already downloaded',
                gradientColors: [
                  const Color(0xFF5B6B8A),
                  const Color(0xFF3D4D6B),
                ],
                onTap: onLibraryTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _SourceOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.9), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

