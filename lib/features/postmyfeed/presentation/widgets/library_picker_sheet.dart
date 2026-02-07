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
/// Fetches downloads when opened so API data is shown.
class LibraryPickerSheet extends StatefulWidget {
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
  State<LibraryPickerSheet> createState() => _LibraryPickerSheetState();
}

class _LibraryPickerSheetState extends State<LibraryPickerSheet> {
  @override
  void initState() {
    super.initState();
    // Ensure API is called when sheet opens so library list shows data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DownloadsBloc>().add(GetDownloadsEvent(mediaType: widget.mediaType));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.mediaType == 'video' ? 'Videos' : 'Audios';
    final primary = appTheme.primaryColor;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        widget.mediaType == 'video' ? Icons.video_library_rounded : Icons.audiotrack_rounded,
                        color: primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$title Library',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                  letterSpacing: -0.3,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Select a ${widget.mediaType == 'video' ? 'video' : 'track'} to post',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(Icons.close_rounded, color: Colors.grey.shade700, size: 26),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: BlocBuilder<DownloadsBloc, DownloadsState>(
              buildWhen: (prev, curr) {
                // Rebuild when we have loaded data (any mediaType) or error
                return curr is DownloadsLoaded || curr is DownloadsError || curr is DownloadsLoading || curr is DownloadsInitial;
              },
              builder: (context, state) {
                if (state is DownloadsInitial || state is DownloadsLoading) {
                  return _buildShimmerEffect();
                }
                if (state is DownloadsError) {
                  return _buildErrorState(context, state.message);
                }
                if (state is DownloadsLoaded) {
                  if (state.downloads.isEmpty) return _buildEmptyState(context);
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
    final primary = appTheme.primaryColor;
    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: downloads.length,
      itemBuilder: (context, index) {
        final download = downloads[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => widget.onMediaSelected(download),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildThumb(download),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                download.title ?? 'Untitled',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: Colors.black87,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.schedule_rounded, size: 14, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    download.duration ?? '—',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.play_circle_outline_rounded, size: 18, color: primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Tap to use',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: primary,
                                    ),
                                  ),
                                ],
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
          ),
        );
      },
    );
  }

  Widget _buildThumb(DownloadEntity d) {
    const double thumbWidth = 120;
    const double thumbHeight = 80;
    return Stack(
      children: [
        Container(
          width: thumbWidth,
          height: thumbHeight,
          color: Colors.grey.shade200,
          child: widget.mediaType == 'video' && d.thumbnail != null
              ? Image.network(
                  d.thumbnail!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                )
              : _thumbPlaceholder(),
        ),
        if (widget.mediaType == 'video')
          Positioned(
            bottom: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                d.duration ?? '—',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _thumbPlaceholder() {
    return Center(
      child: Icon(
        widget.mediaType == 'video' ? Icons.videocam_rounded : Icons.music_note_rounded,
        size: 36,
        color: Colors.grey.shade400,
      ),
    );
  }

  Widget _buildShimmerEffect() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: 6,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
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
    final primary = appTheme.primaryColor;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_off_rounded, size: 40, color: Colors.red.shade400),
            ),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.read<DownloadsBloc>().add(GetDownloadsEvent(mediaType: widget.mediaType)),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final primary = appTheme.primaryColor;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.mediaType == 'video' ? Icons.video_library_rounded : Icons.audiotrack_rounded,
                size: 44,
                color: primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Library is empty',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'You haven’t downloaded any ${widget.mediaType == 'video' ? 'videos' : 'audio'} yet.\nDownload some first to use them here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
