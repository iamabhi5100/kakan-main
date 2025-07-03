import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:http/http.dart' as http;
import 'package:kakan/config/theme.dart';
import 'package:kakan/features/myfiles/domain/entities/download_entity.dart';
import 'package:kakan/features/myfiles/presentation/bloc/delete_download/delete_download_bloc.dart';
import 'package:kakan/features/myfiles/presentation/bloc/delete_download/delete_download_event.dart';
import 'package:kakan/features/myfiles/presentation/bloc/delete_download/delete_download_state.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_bloc.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_event.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_state.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ringtone_set_plus/ringtone_set_plus.dart';
import 'package:toastification/toastification.dart';
import 'package:kakan/injection_container.dart' as di;

enum AudioMenuOption { delete, makeTune, setRingtone }

class AudioMyfilesWidget extends StatefulWidget {
  final ValueChanged<bool>? onOperationStateChanged;

  const AudioMyfilesWidget({super.key, this.onOperationStateChanged});

  @override
  State<AudioMyfilesWidget> createState() => _AudioMyfilesWidgetState();
}

class _AudioMyfilesWidgetState extends State<AudioMyfilesWidget>
    with WidgetsBindingObserver {
  bool _isSettingRingtone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (kDebugMode) {
      print('AudioMyfilesWidget: Disposed');
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (kDebugMode) {
        print('App resumed');
      }
    }
  }

  Future<bool> requestPermissions() async {
    bool manageStorageGranted = false;

    // Request MANAGE_EXTERNAL_STORAGE (Android 11+)
    try {
      var status = await Permission.manageExternalStorage.status;
      debugPrint('MANAGE_EXTERNAL_STORAGE status: $status');
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
        debugPrint('MANAGE_EXTERNAL_STORAGE after request: $status');
        if (status.isDenied || status.isPermanentlyDenied) {
          if (mounted) {
            // Show dialog to guide user to settings
            final shouldOpenSettings = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Storage Permission Required'),
                    content: const Text(
                      'Please enable "All files access" in app settings to set ringtones.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Open Settings'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
            );
            if (shouldOpenSettings == true) {
              await openAppSettings();
              // Wait briefly to ensure settings change is registered
              await Future.delayed(const Duration(seconds: 2));
              // Re-check permission
              status = await Permission.manageExternalStorage.status;
              debugPrint('MANAGE_EXTERNAL_STORAGE after settings: $status');
            } else {
              return false;
            }
          }
        }
      }
      manageStorageGranted = status.isGranted;
    } catch (e) {
      debugPrint('Error requesting MANAGE_EXTERNAL_STORAGE: $e');
    }

    if (!manageStorageGranted && mounted) {
      toastification.show(
        context: context,
        title: const Text('Please grant storage permission to set ringtones'),
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        autoCloseDuration: const Duration(seconds: 3),
        backgroundColor: Colors.white,
      );
    }

    return manageStorageGranted;
  }

  Future<String> downloadAndSaveAudio(String url, String fileName) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to download audio: ${response.statusCode}');
      }

      // Save to public Ringtones directory
      final directory = Directory('/storage/emulated/0/Ringtones');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final filePath = '/storage/emulated/0/Ringtones/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      debugPrint('Audio saved to: $filePath');

      return filePath;
    } catch (e) {
      throw Exception('Error downloading audio: $e');
    }
  }

  Future<void> _setAsRingtone(
    BuildContext context,
    DownloadEntity download,
  ) async {
    if (_isSettingRingtone) return;
    setState(() {
      _isSettingRingtone = true;
      widget.onOperationStateChanged?.call(true);
    });

    try {
      if (download.mediaFile == null) {
        if (!mounted) return;
        toastification.show(
          context: context,
          title: const Text('No media file available to set as ringtone'),
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          autoCloseDuration: const Duration(seconds: 3),
          backgroundColor: Colors.white,
        );
        return;
      }

      // Request storage permission
      final hasPermissions = await requestPermissions();
      debugPrint('Storage permission granted: $hasPermissions');
      if (!hasPermissions) {
        return;
      }

      // Download and save audio
      final fileName = '${download.title ?? download.id}.mp3';
      final filePath = await Future.microtask(
        () => downloadAndSaveAudio(download.mediaFile!, fileName),
      );

      // Set default ringtone
      final file = File(filePath);
      final result = await RingtoneSet.setRingtoneFromFile(file);
      if (!mounted) return;
      if (result) {
        toastification.show(
          context: context,
          title: const Text(
            'Ringtone set successfully',
            style: TextStyle(color: Colors.white),
          ),
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          showProgressBar: true,
          autoCloseDuration: const Duration(seconds: 3),
          backgroundColor: Colors.white,
        );
      } else {
        throw Exception('Failed to set ringtone');
      }
    } catch (e) {
      if (!mounted) return;
      toastification.show(
        context: context,
        title: Text('Error setting ringtone: $e'),
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        autoCloseDuration: const Duration(seconds: 3),
        backgroundColor: Colors.white,
      );
      debugPrint('Set ringtone error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSettingRingtone = false;
          widget.onOperationStateChanged?.call(false);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSettingRingtone,
      child: Stack(
        children: [
          BlocProvider(
            create: (_) => di.sl<DeleteDownloadBloc>(),
            child: BlocListener<DeleteDownloadBloc, DeleteDownloadState>(
              listener: (context, state) {
                if (state is DeleteDownloadSuccess) {
                  if (!mounted) return;
                  toastification.show(
                    context: context,
                    title: const Text('Song deleted successfully'),
                    type: ToastificationType.success,
                    style: ToastificationStyle.fillColored,
                    autoCloseDuration: const Duration(seconds: 3),
                    backgroundColor: Colors.white,
                  );
                  context.read<DownloadsBloc>().add(
                    GetDownloadsEvent(mediaType: 'audio'),
                  );
                } else if (state is DeleteDownloadError) {
                  if (!mounted) return;
                  toastification.show(
                    context: context,
                    title: Text('Failed to delete song: ${state.message}'),
                    type: ToastificationType.error,
                    style: ToastificationStyle.fillColored,
                    autoCloseDuration: const Duration(seconds: 3),
                    backgroundColor: Colors.white,
                  );
                }
              },
              child: BlocBuilder<DownloadsBloc, DownloadsState>(
                builder: (context, state) {
                  if (kDebugMode) {
                    print('AudioMyfilesWidget: Current state: $state');
                  }
                  if (state is DownloadsInitial || state is DownloadsLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is DownloadsError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Failed to load songs: ${state.message}'),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () {
                              context.read<DownloadsBloc>().add(
                                GetDownloadsEvent(mediaType: 'audio'),
                              );
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  if (state is DownloadsLoaded) {
                    if (state.downloads.isEmpty) {
                      return const Center(child: Text('No songs found'));
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
                                child: Image.asset(
                                  'assets/images/youtubeicon.png',
                                ),
                              ),
                              const Gap(10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      download.title ?? 'Untitled Song',
                                      style: appTheme.textTheme.titleSmall,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      download.created,
                                      style: appTheme.textTheme.titleSmall
                                          ?.copyWith(color: Colors.grey),
                                    ),
                                    Text(
                                      download.duration ?? 'Unknown duration',
                                      style: appTheme.textTheme.titleSmall
                                          ?.copyWith(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<AudioMenuOption>(
                                icon: const Icon(Icons.more_horiz_rounded),
                                enabled: !_isSettingRingtone,
                                onSelected: (option) async {
                                  switch (option) {
                                    case AudioMenuOption.delete:
                                      context.read<DeleteDownloadBloc>().add(
                                        DeleteDownloadEvent(
                                          mediaId: download.id,
                                        ),
                                      );
                                      break;
                                    case AudioMenuOption.makeTune:
                                      if (!mounted) return;
                                      toastification.show(
                                        context: context,
                                        title: const Text(
                                          'Make a tune not implemented',
                                        ),
                                        type: ToastificationType.info,
                                        style: ToastificationStyle.fillColored,
                                        autoCloseDuration: const Duration(
                                          seconds: 3,
                                        ),
                                        backgroundColor: Colors.grey,
                                      );
                                      break;
                                    case AudioMenuOption.setRingtone:
                                      await _setAsRingtone(context, download);
                                      break;
                                  }
                                },
                                itemBuilder:
                                    (context) => [
                                      const PopupMenuItem(
                                        value: AudioMenuOption.delete,
                                        child: Text('Delete'),
                                      ),
                                      const PopupMenuItem(
                                        value: AudioMenuOption.makeTune,
                                        enabled: false,
                                        child: Text('Make a tune'),
                                      ),
                                      const PopupMenuItem(
                                        value: AudioMenuOption.setRingtone,
                                        child: Text('Set as ringtone'),
                                      ),
                                    ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }
                  return const Center(child: Text('Loading songs...'));
                },
              ),
            ),
          ),
          if (_isSettingRingtone)
            Container(
              color: Colors.transparent,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
