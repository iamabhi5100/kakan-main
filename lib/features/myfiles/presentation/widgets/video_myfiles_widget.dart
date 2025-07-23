import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:kakan/config/theme.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/config/constant_api.dart';
import 'package:kakan/core/network/api_service.dart';
import 'package:kakan/core/utils/app_permissions.dart';
import 'package:kakan/features/myfiles/domain/entities/download_entity.dart';
import 'package:kakan/features/myfiles/presentation/bloc/delete_download/delete_download_bloc.dart';
import 'package:kakan/features/myfiles/presentation/bloc/delete_download/delete_download_event.dart';
import 'package:kakan/features/myfiles/presentation/bloc/delete_download/delete_download_state.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_bloc.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_event.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_state.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:go_router/go_router.dart';
import 'package:toastification/toastification.dart';

enum VideoMenuOption { delete, makeTune, exportAudio }

class VideoMyfilesWidget extends StatefulWidget {
  final VoidCallback? onSwitchToAudioTab;

  const VideoMyfilesWidget({super.key, this.onSwitchToAudioTab});

  @override
  _VideoMyfilesWidgetState createState() => _VideoMyfilesWidgetState();
}

class _VideoMyfilesWidgetState extends State<VideoMyfilesWidget> {
  Future<void> _exportToAudio(
    BuildContext context,
    DownloadEntity download,
  ) async {
    if (download.mediaFile == null) return;
    final hasPermissions = await AppPermissions.requestAllPermissions(context);
    if (!hasPermissions) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final fileName = 'temp_video_${download.id}.mp4';
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/$fileName';
    final dio = Dio();
    try {
      await dio.download(download.mediaFile!, filePath);
    } catch (e) {
      if (kDebugMode) print('Download failed: $e');
      if (context.mounted) Navigator.pop(context);
      return;
    }

    final outputPath =
        '${tempDir.path}/audio_${download.id}_${DateTime.now().millisecondsSinceEpoch}.mp3';
    final command = '-i "$filePath" -vn -c:a mp3 -y "$outputPath"';
    await FFmpegKit.executeAsync(command, (session) async {
      final returnCode = await session.getReturnCode();
      if (context.mounted) Navigator.pop(context);

      if (ReturnCode.isSuccess(returnCode)) {
        try {
          final apiService = di.sl<ApiService>();
          final formData = FormData.fromMap({
            'media_type': 'audio',
            'media_file': await MultipartFile.fromFile(
              outputPath,
              filename: 'audio.mp3',
            ),
            'title': download.title ?? 'Untitled Audio',
            'duration': download.duration ?? '00:00:00',
          });
          await apiService.post(
            ConstantApi.downloads,
            formData,
            includeAuth: true,
          );
          if (context.mounted) {
            toastification.show(
              context: context,
              title: const Text('Audio uploaded successfully!'),
              type: ToastificationType.success,
              style: ToastificationStyle.fillColored,
              autoCloseDuration: const Duration(seconds: 3),
              backgroundColor: Colors.white,
            );
            context.read<DownloadsBloc>().add(
              GetDownloadsEvent(mediaType: 'audio'),
            );
            widget.onSwitchToAudioTab?.call();
          }
        } catch (e) {
          if (kDebugMode) print('Upload failed: $e');
        }
      } else {
        if (kDebugMode) print('FFmpeg failed with code $returnCode');
      }
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
              title: const Text('Video deleted successfully'),
              type: ToastificationType.success,
              style: ToastificationStyle.fillColored,
              autoCloseDuration: const Duration(seconds: 3),
              backgroundColor: Colors.white,
            );
            context.read<DownloadsBloc>().add(
              GetDownloadsEvent(mediaType: 'video'),
            );
          } else if (state is DeleteDownloadError) {
            toastification.show(
              context: context,
              title: Text('Failed to delete video: ${state.message}'),
              type: ToastificationType.error,
              style: ToastificationStyle.fillColored,
              autoCloseDuration: const Duration(seconds: 3),
              backgroundColor: Colors.white,
            );
          }
        },
        child: BlocBuilder<DownloadsBloc, DownloadsState>(
          builder: (context, state) {
            if (state is DownloadsInitial || state is DownloadsLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is DownloadsError) {
              return Center(
                child: Text('Failed to load videos: ${state.message}'),
              );
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
                    child: Row(
                      children: [
                        SizedBox(
                          width: 120,
                          height: 80,
                          child: Image.asset('assets/images/youtubeicon.png'),
                        ),
                        const Gap(10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                download.title ?? 'Untitled Video',
                                style: appTheme.textTheme.titleSmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                download.created,
                                style: appTheme.textTheme.titleSmall?.copyWith(
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                download.duration ?? 'Unknown duration',
                                style: appTheme.textTheme.titleSmall?.copyWith(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<VideoMenuOption>(
                          icon: const Icon(Icons.more_horiz_rounded),
                          onSelected: (option) async {
                            switch (option) {
                              case VideoMenuOption.delete:
                                context.read<DeleteDownloadBloc>().add(
                                  DeleteDownloadEvent(mediaId: download.id),
                                );
                                break;
                              case VideoMenuOption.makeTune:
                                toastification.show(
                                  context: context,
                                  title: const Text(
                                    'Make a tune not implemented',
                                  ),
                                  type: ToastificationType.info,
                                  style: ToastificationStyle.fillColored,
                                  autoCloseDuration: const Duration(seconds: 3),
                                  backgroundColor: Colors.white,
                                );
                                break;
                              case VideoMenuOption.exportAudio:
                                await _exportToAudio(context, download);
                                break;
                            }
                          },
                          itemBuilder:
                              (context) => const [
                                PopupMenuItem(
                                  value: VideoMenuOption.delete,
                                  child: Text('Delete'),
                                ),
                                PopupMenuItem(
                                  value: VideoMenuOption.makeTune,
                                  enabled: false,
                                  child: Text('Make a tune'),
                                ),
                                PopupMenuItem(
                                  value: VideoMenuOption.exportAudio,
                                  child: Text('Export to audio'),
                                ),
                              ],
                        ),
                      ],
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
