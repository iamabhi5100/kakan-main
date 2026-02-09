import 'dart:io';
import 'package:dio/dio.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:kakan/config/theme.dart';
import 'package:kakan/config/constant_api.dart';
import 'package:kakan/core/network/api_service.dart';
import 'package:kakan/features/myfiles/domain/entities/download_entity.dart';
import 'package:kakan/features/myfiles/presentation/bloc/delete_download/delete_download_bloc.dart';
import 'package:kakan/features/myfiles/presentation/pages/myfiles_video_feed_page.dart';
import 'package:kakan/features/myfiles/presentation/bloc/delete_download/delete_download_event.dart';
import 'package:kakan/features/myfiles/presentation/bloc/delete_download/delete_download_state.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_bloc.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_event.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_state.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:toastification/toastification.dart';

enum VideoMenuOption { exportAudio, editVideo, delete }

class VideoMyfilesWidget extends StatefulWidget {
  final VoidCallback? onSwitchToAudioTab;

  const VideoMyfilesWidget({super.key, this.onSwitchToAudioTab});

  @override
  State<VideoMyfilesWidget> createState() => _VideoMyfilesWidgetState();
}

class _VideoMyfilesWidgetState extends State<VideoMyfilesWidget> {
  Future<void> _exportToAudio(BuildContext context, DownloadEntity download) async {
    if (download.mediaFile == null || download.mediaFile!.isEmpty) {
      toastification.show(
        context: context,
        title: const Text('No video URL to export'),
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
      );
      return;
    }

    // show spinner
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    final tempDir = await getTemporaryDirectory();
    final srcPath = '${tempDir.path}/temp_video_${download.id}.mp4';
    final outPath =
        '${tempDir.path}/audio_${download.id}_${DateTime.now().millisecondsSinceEpoch}.mp3';

    final dio = Dio();

    // 1) Download video to app cache (no runtime permission required)
    try {
      await dio.download(download.mediaFile!, srcPath);
    } catch (e) {
      if (kDebugMode) print('Download failed: $e');
      if (mounted) Navigator.of(context).pop(); // close spinner
      toastification.show(
        context: context,
        title: const Text('Failed to download video'),
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
      );
      return;
    }

    // 2) Convert to MP3 with FFmpeg (close spinner in callback)
    final cmd = '-i "$srcPath" -vn -c:a mp3 -y "$outPath"';
    await FFmpegKit.executeAsync(cmd, (session) async {
      // ensure spinner closed when we finish convert (success or fail)
      if (mounted) Navigator.of(context).pop();

      final rc = await session.getReturnCode();

      if (ReturnCode.isSuccess(rc)) {
        // 3) Upload the resulting mp3
        try {
          final apiService = di.sl<ApiService>();
          final formData = FormData.fromMap({
            'media_type': 'audio',
            'media_file': await MultipartFile.fromFile(outPath, filename: 'audio.mp3'),
            'title': download.title ?? 'Untitled Audio',
            'duration': download.duration ?? '00:00:00',
          });
          await apiService.post(
            ConstantApi.downloads,
            formData,
            includeAuth: true,
          );

          if (!mounted) return;
          toastification.show(
            context: context,
            title: const Text('Audio exported successfully!'),
            type: ToastificationType.success,
            style: ToastificationStyle.fillColored,
            autoCloseDuration: const Duration(seconds: 3),
          );
          widget.onSwitchToAudioTab?.call();
        } catch (e) {
          if (kDebugMode) print('Upload failed: $e');
          if (!mounted) return;
          toastification.show(
            context: context,
            title: const Text('Upload failed'),
            type: ToastificationType.error,
            style: ToastificationStyle.fillColored,
          );
        }
      } else {
        if (kDebugMode) print('FFmpeg failed with code $rc');
        if (!mounted) return;
        toastification.show(
          context: context,
          title: const Text('Could not convert to audio'),
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
        );
      }

      // 4) Cleanup temp files
      try {
        if (File(srcPath).existsSync()) File(srcPath).deleteSync();
      } catch (_) {}
      try {
        if (File(outPath).existsSync()) File(outPath).deleteSync();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => di.sl<DeleteDownloadBloc>(),
      child: BlocListener<DeleteDownloadBloc, DeleteDownloadState>(
        listener: (context, state) {
          if (state is DeleteDownloadSuccess) {
            toastification.show(
              context: context,
              title: const Text('Deleted'),
              type: ToastificationType.success,
              style: ToastificationStyle.fillColored,
              autoCloseDuration: const Duration(seconds: 2),
            );
            // ✅ FIX: use the event your bloc actually supports
            context.read<DownloadsBloc>().add(
                  GetDownloadsEvent(mediaType: 'video'),
                );
          } else if (state is DeleteDownloadError) {
            toastification.show(
              context: context,
              title: Text(state.message),
              type: ToastificationType.error,
              style: ToastificationStyle.fillColored,
            );
          }
        },
        child: BlocBuilder<DownloadsBloc, DownloadsState>(
          builder: (context, state) {
            if (state is DownloadsInitial || state is DownloadsLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is DownloadsError) {
              return Center(child: Text('Failed to load videos: ${state.message}'));
            } else if (state is DownloadsLoaded) {
              if (state.downloads.isEmpty) {
                return const Center(child: Text('No videos found'));
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.downloads.length,
                itemBuilder: (context, index) {
                  final download = state.downloads[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MyFilesVideoFeedPage(download: download),
                          ),
                        );
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 120,
                            height: 80,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: Image.network(
                                download.thumbnail ?? '',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Center(
                                  child: Image.asset('assets/images/youtubeicon.png'),
                                ),
                              ),
                            ),
                          ),
                          const Gap(12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  download.title ?? 'Untitled Video',
                                  style: appTheme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Gap(4),
                                Text(
                                  download.created,
                                  style: appTheme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const Gap(4),
                                Text(
                                  download.duration ?? '00:00',
                                  style: appTheme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<VideoMenuOption>(
                            icon: const Icon(Icons.more_horiz_rounded, color: Colors.grey),
                            onSelected: (option) {
                              switch (option) {
                                case VideoMenuOption.exportAudio:
                                  _exportToAudio(context, download);
                                  break;
                                case VideoMenuOption.editVideo:
                                  break;
                                case VideoMenuOption.delete:
                                  context
                                      .read<DeleteDownloadBloc>()
                                      .add(DeleteDownloadEvent(mediaId: download.id));
                                  break;
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: VideoMenuOption.exportAudio,
                                child: Text('Export Audio'),
                              ),
                              PopupMenuItem(
                                value: VideoMenuOption.editVideo,
                                enabled: false,
                                child: Text('Edit Video'),
                              ),
                              PopupMenuItem(
                                value: VideoMenuOption.delete,
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }

            return const Center(child: Text('Loading videos...'));
          },
        ),
      ),
    );
  }
}
