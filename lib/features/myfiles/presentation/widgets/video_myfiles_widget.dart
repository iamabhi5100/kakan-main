import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:kakan/config/theme.dart';
import 'package:kakan/features/myfiles/domain/entities/download_entity.dart';
import 'package:kakan/features/myfiles/presentation/bloc/delete_download/delete_download_bloc.dart';
import 'package:kakan/features/myfiles/presentation/bloc/delete_download/delete_download_event.dart';
import 'package:kakan/features/myfiles/presentation/bloc/delete_download/delete_download_state.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_bloc.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_event.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_state.dart';
// import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
// import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:go_router/go_router.dart';
import 'package:toastification/toastification.dart';

enum VideoMenuOption { delete, makeTune, exportAudio }

class ApiService {
  final Dio _dio = Dio();
  Future<dynamic> post(String url, FormData data, {bool includeAuth = false}) async {
    try {
      final options = Options(
        headers: includeAuth
            ? {
                'Authorization':
                    'Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ0b2tlbl90eXBlIjoiYWNjZXNzIiwiZXhwIjoxNzUwMjQ2MzU5LCJpYXQiOjE3NDc2NTQzNTksImp0aSI6ImM2OWJlMThjZGQ5MDRmOGM4MDhiYzljZDA4ZThmYmFlIiwidXNlcl9pZCI6ImZkMGVlODcwLThhMmYtNDg5OC1hZGY4LWJhM2Q0NWQ0MTg1NiJ9.w-6mTQSOoMvMIUAinyiVkn6EW-tCw8C52wRkVuOBQXU'
              }
            : null,
      );
      final response = await _dio.post(url, data: data, options: options);
      if (kDebugMode) {
        print('Upload response: ${response.data}');
      }
      return response.data;
    } catch (e) {
      throw ServerException('Failed to upload: $e');
    }
  }
}

class ServerException implements Exception {
  final String message;
  ServerException(this.message);
}

class ConstantApi {
  static const String downloads = 'https://kakan.backend.xade.in/v1/downloads/';
}

class VideoMyfilesWidget extends StatelessWidget {
  const VideoMyfilesWidget({super.key});

  Future<File?> _downloadFile(String url, String fileName) async {
    try {
      final dio = Dio(BaseOptions(receiveTimeout: const Duration(seconds: 30)));
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';
      await dio.download(url, filePath, onReceiveProgress: (received, total) {
        if (kDebugMode && total != -1) {
          print('Download progress: ${(received / total * 100).toStringAsFixed(2)}%');
        }
      });
      final file = File(filePath);
      if (await file.exists()) {
        if (kDebugMode) {
          print('File downloaded successfully: $filePath');
        }
        return file;
      }
      if (kDebugMode) {
        print('Downloaded file does not exist: $filePath');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error downloading file: $e');
      }
      return null;
    }
  }

  Future<void> _deleteTempFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
        if (kDebugMode) {
          print('Deleted temporary file: ${file.path}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting temporary file ${file.path}: $e');
      }
    }
  }

  // Future<void> _exportToAudio(BuildContext context, DownloadEntity download) async {
  //   if (download.mediaFile == null) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text('No media file available to export'),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //     if (kDebugMode) {
  //       print('Displayed SnackBar: No media file available');
  //     }
  //     return;
  //   }

  //   // Storage permission check for Android API < 29
  //   bool hasStoragePermission = true;
  //   if (Platform.isAndroid && (await _getAndroidSdkVersion() < 29)) {
  //     final storageStatus = await Permission.storage.request();
  //     hasStoragePermission = storageStatus.isGranted;
  //     if (!hasStoragePermission) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text('Storage permission denied'),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //       if (kDebugMode) {
  //         print('Displayed SnackBar: Storage permission denied');
  //       }
  //       return;
  //     }
  //   }

  //   // Download the video file
  //   final fileName = 'temp_video_${download.id}.mp4';
  //   final inputFile = await _downloadFile(download.mediaFile!, fileName);
  //   if (inputFile == null || !await inputFile.exists()) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text('Failed to download video file'),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //     if (kDebugMode) {
  //       print('Displayed SnackBar: Failed to download video file');
  //     }
  //     return;
  //   }

  //   final tempDir = await getTemporaryDirectory();
  //   final outputPath = '${tempDir.path}/audio_${download.id}_${DateTime.now().millisecondsSinceEpoch}.mp3';
  //   final outputFile = File(outputPath);

  //   try {
  //     // Extract audio with verbose logging and fallback to copy codec
  //     final command = '-i "${inputFile.path}" -vn -c:a mp3 -loglevel verbose -y "$outputPath"';
  //     if (kDebugMode) {
  //       print('Executing FFmpeg audio command: $command');
  //     }
  //     final session = await FFmpegKit.executeAsync(
  //       command,
  //       (session) async {
  //         final returnCode = await session.getReturnCode();
  //         final logs = await session.getAllLogsAsString();
  //         if (kDebugMode) {
  //           print('FFmpeg audio return code: $returnCode');
  //           print('FFmpeg audio logs:\n$logs');
  //         }

  //         if (ReturnCode.isSuccess(returnCode)) {
  //           if (!await outputFile.exists()) {
  //             ScaffoldMessenger.of(context).showSnackBar(
  //               const SnackBar(
  //                 content: Text('Audio file was not created'),
  //                 backgroundColor: Colors.red,
  //               ),
  //             );
  //             if (kDebugMode) {
  //               print('Displayed SnackBar: Audio file was not created');
  //             }
  //             await _deleteTempFile(inputFile);
  //             return;
  //           }

  //           // Upload to server
  //           try {
  //             final apiService = di.sl<ApiService>();
  //             final audioTitle = download.title ?? 'Untitled Audio';
  //             final duration = download.duration ?? '00:00:00';
  //             final formDataMap = {
  //               'media_type': 'audio',
  //               'media_file': await MultipartFile.fromFile(outputPath),
  //               'title': audioTitle,
  //               'duration': duration,
  //             };

  //             final formData = FormData.fromMap(formDataMap);
  //             if (kDebugMode) {
  //               print('Uploading audio to ${ConstantApi.downloads}');
  //               print('FormData fields: ${formData.fields}');
  //             }
  //             await apiService.post(
  //               ConstantApi.downloads,
  //               formData,
  //               includeAuth: true,
  //             );

  //             toastification.show(
  //               context: context,
  //               type: ToastificationType.success,
  //               style: ToastificationStyle.fillColored,
  //               title: const Text('Success'),
  //               description: const Text('Audio uploaded successfully!'),
  //               alignment: Alignment.topCenter,
  //               autoCloseDuration: const Duration(seconds: 3),
  //               icon: const Icon(Icons.check_circle),
  //               boxShadow: const [], // Replace with lowModeShadow if defined
  //               showProgressBar: true,
  //             );

  //             // Refresh the downloads list and navigate
  //             context.read<DownloadsBloc>().add(GetDownloadsEvent(mediaType: 'audio'));
  //             context.go('/home');
  //           } on ServerException catch (e) {
  //             if (kDebugMode) {
  //               print('Upload failed with ServerException: ${e.message}');
  //             }
  //             ScaffoldMessenger.of(context).showSnackBar(
  //               SnackBar(content: Text('Failed to upload audio: ${e.message}')),
  //             );
  //             if (kDebugMode) {
  //               print('Displayed SnackBar: Failed to upload audio');
  //             }
  //           } catch (e) {
  //             if (kDebugMode) {
  //               print('Upload failed with unexpected error: $e');
  //             }
  //             ScaffoldMessenger.of(context).showSnackBar(
  //               SnackBar(content: Text('Unexpected error during upload: $e')),
  //             );
  //             if (kDebugMode) {
  //               print('Displayed SnackBar: Unexpected error during upload');
  //             }
  //           } finally {
  //             // Clean up after upload
  //             await _deleteTempFile(inputFile);
  //             await _deleteTempFile(outputFile);
  //           }
  //         } else {
  //           // Check logs for specific error
  //           String errorMessage = 'Failed to extract audio';
  //           if (logs != null && logs.contains('No audio stream')) {
  //             errorMessage = 'No audio stream found in the video';
  //           } else if (logs != null && logs.contains('Invalid data')) {
  //             errorMessage = 'Invalid or corrupted video file';
  //           } else if (logs != null && logs.contains('codec not found')) {
  //             errorMessage = 'MP3 codec not supported by FFmpeg';
  //           }
  //           ScaffoldMessenger.of(context).showSnackBar(
  //             SnackBar(
  //               content: Text(errorMessage),
  //               backgroundColor: Colors.red,
  //             ),
  //           );
  //           if (kDebugMode) {
  //             print('Displayed SnackBar: $errorMessage');
  //           }
  //           await _deleteTempFile(inputFile);
  //           await _deleteTempFile(outputFile);
  //         }
  //       },
  //     );
  //   } catch (e, stackTrace) {
  //     if (kDebugMode) {
  //       print('Error exporting audio: $e');
  //       print('Stack trace: $stackTrace');
  //     }
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Error exporting audio: $e'),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //     if (kDebugMode) {
  //       print('Displayed SnackBar: Error exporting audio');
  //     }
  //     await _deleteTempFile(inputFile);
  //     await _deleteTempFile(outputFile);
  //   }
  // }

  Future<int> _getAndroidSdkVersion() async {
    if (Platform.isAndroid) {
      return 29; // Placeholder, use device_info_plus for accurate SDK version
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => di.sl<DeleteDownloadBloc>(),
      child: BlocListener<DeleteDownloadBloc, DeleteDownloadState>(
        listener: (context, state) {
          if (state is DeleteDownloadSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Video deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );
            context.read<DownloadsBloc>().add(GetDownloadsEvent(mediaType: 'video'));
          } else if (state is DeleteDownloadError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to delete video: ${state.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: BlocBuilder<DownloadsBloc, DownloadsState>(
          builder: (context, state) {
            if (kDebugMode) {
              print('VideoMyfilesWidget: Current state: $state');
            }
            if (state is DownloadsInitial || state is DownloadsLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is DownloadsError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Failed to load videos: ${state.message}'),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        context.read<DownloadsBloc>().add(GetDownloadsEvent(mediaType: 'video'));
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            if (state is DownloadsLoaded) {
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
                          child: download.thumbnail != null
                              ? Image.network(
                                  download.thumbnail!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Image.asset('assets/images/youtubeicon.png'),
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(child: CircularProgressIndicator());
                                  },
                                )
                              : Image.asset('assets/images/youtubeicon.png'),
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Make a tune not implemented'),
                                    backgroundColor: Colors.grey,
                                  ),
                                );
                                break;
                              case VideoMenuOption.exportAudio:
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => const Center(child: CircularProgressIndicator()),
                                );
                                // await _exportToAudio(context, download);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: VideoMenuOption.delete,
                              child: Text('Delete'),
                            ),
                            const PopupMenuItem(
                              value: VideoMenuOption.makeTune,
                              enabled: false,
                              child: Text('Make a tune'),
                            ),
                            const PopupMenuItem(
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