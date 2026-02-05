import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

import 'package:kakan/config/theme.dart';
import 'package:kakan/features/myfiles/domain/entities/download_entity.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_bloc.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_event.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_state.dart';

/// Reusable bottom sheet to pick a video or audio from My Library (downloads).
/// Requires [DownloadsBloc] in context (e.g. from root).
class LibraryPickerSheet extends StatelessWidget {
  final String mediaType;
  final ScrollController scrollController;
  final Function(DownloadEntity) onMediaSelected;

  const LibraryPickerSheet({
    super.key,
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
