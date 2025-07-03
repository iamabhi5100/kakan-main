import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:kakan/config/theme.dart';
import 'package:kakan/features/myfiles/domain/entities/download_entity.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_bloc.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_event.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_state.dart';

class MainPostScreen extends StatefulWidget {
  const MainPostScreen({super.key});

  @override
  State<MainPostScreen> createState() => _MainPostScreenState();
}

class _MainPostScreenState extends State<MainPostScreen> {
  final ImagePicker _picker = ImagePicker();

  // Show bottom modal sheet with options: From Gallery or From Library
  void _showMediaSourceModal(BuildContext context, String mediaType) {
    print('DEBUG: Showing media source modal for mediaType: $mediaType');
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('From Gallery'),
              onTap: () {
                print('DEBUG: User selected "From Gallery" for $mediaType');
                Navigator.pop(context);
                _pickFromGallery(mediaType);
              },
            ),
            ListTile(
              leading: const Icon(Icons.library_music),
              title: const Text('From Library'),
              onTap: () {
                print('DEBUG: User selected "From Library" for $mediaType');
                Navigator.pop(context);
                _showLibraryModal(context, mediaType);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Pick media from gallery using image_picker
  Future<void> _pickFromGallery(String mediaType) async {
    print('DEBUG: Picking $mediaType from gallery');
    try {
      if (mediaType == 'video') {
        final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
        if (file != null && mounted) {
          final filePath = file.path;
          print('DEBUG: Video selected from gallery, filePath: $filePath');
          context.push('/video-post', extra: {'filePath': filePath});
        } else {
          print('DEBUG: No video selected from gallery');
        }
      } else {
        final result = await FilePicker.platform.pickFiles(type: FileType.audio);
        if (result != null && result.files.single.path != null && mounted) {
          final filePath = result.files.single.path!;
          print('DEBUG: Audio selected from gallery, filePath: $filePath');
          context.push('/audio-post', extra: {'filePath': filePath});
        } else {
          print('DEBUG: No audio selected from gallery');
        }
      }
    } catch (e) {
      print('DEBUG: Error picking $mediaType from gallery: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking $mediaType: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show library modal with media list fetched from API
  void _showLibraryModal(BuildContext context, String mediaType) {
    print('DEBUG: Showing library modal for mediaType: $mediaType');
    try {
      context.read<DownloadsBloc>().add(GetDownloadsEvent(mediaType: mediaType));
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (modalContext) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) => Scaffold(
            appBar: AppBar(
              title: Text('${mediaType == 'video' ? 'Videos' : 'Audios'} Library'),
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.black),
                onPressed: () {
                  print('DEBUG: Closing library modal');
                  Navigator.pop(modalContext);
                },
              ),
            ),
            body: BlocBuilder<DownloadsBloc, DownloadsState>(
              builder: (context, state) {
                if (state is DownloadsInitial || state is DownloadsLoading) {
                  print('DEBUG: Downloads state: Loading for $mediaType');
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is DownloadsError) {
                  print('DEBUG: Downloads state: Error for $mediaType - ${state.message}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Failed to load $mediaType: ${state.message}'),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () {
                            print('DEBUG: Retrying downloads for $mediaType');
                            context
                                .read<DownloadsBloc>()
                                .add(GetDownloadsEvent(mediaType: mediaType));
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                if (state is DownloadsLoaded) {
                  print('DEBUG: Downloads state: Loaded ${state.downloads.length} items for $mediaType');
                  if (state.downloads.isEmpty) {
                    print('DEBUG: No $mediaType found in library');
                    return Center(child: Text('No $mediaType found'));
                  }
                  return ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.all(16.0),
                    itemCount: state.downloads.length,
                    itemBuilder: (context, index) {
                      final download = state.downloads[index];
                      print('DEBUG: Rendering download item $index: ${download.title}, id: ${download.id}');
                      return ListTile(
                        leading: SizedBox(
                          width: 60,
                          height: 60,
                          child: mediaType == 'video' &&
                                  download.thumbnail != null &&
                                  download.thumbnail!.isNotEmpty
                              ? Image.network(
                                  download.thumbnail!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    print('DEBUG: Error loading thumbnail for ${download.title}: $error');
                                    return Image.asset('assets/images/youtubeicon.png');
                                  },
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    print('DEBUG: Loading thumbnail for ${download.title}');
                                    return const Center(child: CircularProgressIndicator());
                                  },
                                )
                              : Image.asset('assets/images/youtubeicon.png'),
                        ),
                        title: Text(
                          download.title ?? 'Untitled ${mediaType == 'video' ? 'Video' : 'Audio'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          download.duration ?? 'Unknown duration',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        onTap: () {
                          if (download.mediaFile != null) {
                            print(
                                'DEBUG: Selected library item: ${download.title}, filePath: ${download.mediaFile}, mediaId: ${download.id}');
                            context.push(
                              mediaType == 'video' ? '/video-post' : '/audio-post',
                              extra: {
                                'filePath': download.mediaFile,
                                'mediaId': download.id,
                              },
                            );
                            Navigator.pop(modalContext);
                          } else {
                            print('DEBUG: No media file available for ${download.title}');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No media file available'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                      );
                    },
                  );
                }
                print('DEBUG: Downloads state: Unknown state for $mediaType');
                return const Center(child: Text('Loading...'));
              },
            ),
          ),
        ),
      );
    } catch (e) {
      print('DEBUG: Error accessing DownloadsBloc in _showLibraryModal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: Unable to load library ($e)'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('DEBUG: Building MainPostScreen');
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Post My Feed',
          style: appTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: () {
                  print('DEBUG: Video Post button pressed');
                  _showMediaSourceModal(context, 'video');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: appTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Video Post',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Audio Post button (uncomment if needed)
            /*
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: () {
                  print('DEBUG: Audio Post button pressed');
                  _showMediaSourceModal(context, 'audio');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: appTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Audio Post',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
            */
          ],
        ),
      ),
    );
  }
}