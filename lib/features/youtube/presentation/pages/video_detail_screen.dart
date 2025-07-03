import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import 'package:kakan/core/utils/app_permissions.dart';
import 'package:kakan/features/youtube/domain/entities/video_entity.dart';
import 'package:kakan/features/youtube/presentation/bloc/youtube_bloc.dart';
import 'package:kakan/features/youtube/presentation/bloc/youtube_event.dart';
import 'package:kakan/features/youtube/presentation/bloc/youtube_state.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';

class VideoDetailScreen extends StatefulWidget {
  final VideoEntity video;

  const VideoDetailScreen({Key? key, required this.video}) : super(key: key);

  @override
  _VideoDetailScreenState createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends State<VideoDetailScreen> {
  late WebViewController _webViewController;
  bool _isWebViewLoaded = false;

  @override
  void initState() {
    super.initState();
    print('VideoDetailScreen: Initializing for video ID: ${widget.video.id}');
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            setState(() {
              _isWebViewLoaded = true;
            });
            print('VideoDetailScreen: WebView loaded for $url');
          },
          onWebResourceError: (error) {
            print('VideoDetailScreen: WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.youtube.com/watch?v=${widget.video.id}'));
  }

  @override
  void dispose() {
    print('VideoDetailScreen: Disposing');
    super.dispose();
  }

  String _formatViews(int views) {
    if (views >= 1000000000) return "${(views / 1000000000).toStringAsFixed(1)}B views";
    if (views >= 1000000) return "${(views / 1000000).toStringAsFixed(1)}M views";
    if (views >= 1000) return "${(views / 1000).toStringAsFixed(1)}K views";
    return "$views views";
  }

  String _publishedAgo(String? publishedDate) {
    if (publishedDate == null || publishedDate.isEmpty) return "";
    try {
      final dt = DateTime.parse(publishedDate);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays >= 365) {
        final years = (diff.inDays / 365).floor();
        return "$years year${years > 1 ? 's' : ''} ago";
      } else if (diff.inDays >= 30) {
        final months = (diff.inDays / 30).floor();
        return "$months month${months > 1 ? 's' : ''} ago";
      } else if (diff.inDays >= 1) {
        return "${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago";
      } else if (diff.inHours >= 1) {
        return "${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago";
      } else if (diff.inMinutes >= 1) {
        return "${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago";
      } else {
        return "Just now";
      }
    } catch (_) {
      return "";
    }
  }

  Future<bool> _checkAndRequestPermissions() async {
    final deviceInfo = DeviceInfoPlugin();
    List<Permission> permissions = [];

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 33) {
        permissions = [Permission.videos, Permission.audio];
      } else if (sdkInt >= 30) {
        permissions = [Permission.storage, Permission.manageExternalStorage];
      } else {
        permissions = [Permission.storage];
      }
    } else if (Platform.isIOS) {
      permissions = [Permission.photos, Permission.videos, Permission.audio];
    }

    final statuses = await Future.wait(permissions.map((p) => p.status));
    bool allGranted = statuses.every((status) => status.isGranted);

    if (allGranted) {
      print('VideoDetailScreen: All permissions granted');
      return true;
    }

    final results = await permissions.request();
    bool grantedNow = results.values.every((status) => status.isGranted);

    if (!grantedNow) {
      print('VideoDetailScreen: Permissions denied: $results');
      _showSnackBar('Please grant all permissions to download. Go to app settings to allow.');
      await openAppSettings();
      return false;
    }

    print('VideoDetailScreen: Permissions granted after request');
    return true;
  }

  void _showSnackBar(String message) {
    if (mounted) {
      String displayMessage = message;
      if (message.contains('Video unavailable') ||
          message.contains('restricted') ||
          message.contains('403') ||
          message.contains('No available video streams')) {
        displayMessage = 'This video is restricted or unavailable for download. Try another video or download audio instead.';
      } else if (message.contains('Rate limit exceeded')) {
        displayMessage = 'Rate limit reached. Please wait a few minutes and try again.';
      } else if (message.contains('Request Entity Too Large')) {
        displayMessage = 'Video file is too large. Try a smaller video or contact support.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(displayMessage, style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
          action: message.contains('Video unavailable') ||
                  message.contains('restricted') ||
                  message.contains('403') ||
                  message.contains('No available video streams')
              ? SnackBarAction(
                  label: 'Download Audio',
                  onPressed: () {
                    context.read<YoutubeBloc>().add(
                          DownloadVideoEvent(
                            videoId: widget.video.id,
                            title: widget.video.title,
                            isAudioOnly: true,
                            preferredQuality: 'Medium',
                          ),
                        );
                  },
                )
              : null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark ? Colors.cyanAccent : Colors.blue[300]!;
    final cardColor = isDark ? Colors.grey[850]! : Colors.white;

    return WillPopScope(
      onWillPop: () async {
        final state = context.read<YoutubeBloc>().state;
        if (state is YoutubeDownloading) {
          print('VideoDetailScreen: Back button ignored during download');
          _showSnackBar('Please wait, download in progress');
          return false;
        }
        print('VideoDetailScreen: Back button pressed');
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: isDark ? Colors.black : Colors.white,
          title: Text(
            widget.video.title,
            style: TextStyle(
              fontFamily: 'Product Sans',
              fontSize: 20,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              final state = context.read<YoutubeBloc>().state;
              if (state is YoutubeDownloading) {
                print('VideoDetailScreen: AppBar back button ignored during download');
                _showSnackBar('Please wait, download in progress');
                return;
              }
              print('VideoDetailScreen: AppBar back button pressed');
              context.pop();
            },
          ),
        ),
        body: BlocConsumer<YoutubeBloc, YoutubeState>(
          listener: (context, state) {
            print('VideoDetailScreen: BlocConsumer received state: $state');
            if (state is YoutubeDownloaded) {
              print('VideoDetailScreen: YoutubeDownloaded state received, isAudioOnly: ${state.isAudioOnly}, filePath: ${state.filePath}');
              if (mounted) {
                final file = File(state.filePath);
                file.exists().then((exists) {
                  if (!exists) {
                    print('VideoDetailScreen: File does not exist: ${state.filePath}');
                    _showSnackBar('Downloaded file not found');
                    return;
                  }
                  print('VideoDetailScreen: File exists: ${state.filePath}');
                  final route = state.isAudioOnly ? '/audio-editor' : '/video-editor';
                  print('VideoDetailScreen: Navigating to $route');
                  context.push(
                    route,
                    extra: {
                      'filePath': state.filePath,
                      'videoId': state.videoId,
                      'title': state.title,
                    },
                  ).then((_) {
                    print('VideoDetailScreen: Navigation to $route completed');
                  }).catchError((e) {
                    print('VideoDetailScreen: Navigation to $route failed: $e');
                    _showSnackBar('Navigation failed: $e');
                  });
                });
              } else {
                print('VideoDetailScreen: Navigation skipped, widget not mounted');
              }
            } else if (state is YoutubeError) {
              print('VideoDetailScreen: YoutubeError state received: ${state.message}');
              _showSnackBar(state.message);
            }
          },
          builder: (context, state) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: cardColor,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: _isWebViewLoaded
                            ? WebViewWidget(controller: _webViewController)
                            : const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.video.title,
                          style: TextStyle(
                            fontFamily: 'Product Sans',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              _formatViews(widget.video.viewCount),
                              style: TextStyle(
                                fontFamily: 'Product Sans',
                                fontSize: 14,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '• ${widget.video.channelTitle}',
                              style: TextStyle(
                                fontFamily: 'Product Sans',
                                fontSize: 14,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                            if (widget.video.publishedDate != null && widget.video.publishedDate!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                '• ${_publishedAgo(widget.video.publishedDate)}',
                                style: TextStyle(
                                  fontFamily: 'Product Sans',
                                  fontSize: 14,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        if (state is YoutubeDownloading)
                          Column(
                            children: [
                              const SizedBox(height: 16),
                              LinearProgressIndicator(
                                value: state.progress == 0.0 ? null : state.progress,
                                minHeight: 6,
                                color: accentColor,
                                backgroundColor: Colors.grey.withOpacity(0.2),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Downloading... ${(state.progress * 100).toStringAsFixed(0)}%",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.download_rounded),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                                ),
                                onPressed: () async {
                                  print('VideoDetailScreen: Download Video button pressed');
                                  if (await _checkAndRequestPermissions()) {
                                    context.read<YoutubeBloc>().add(
                                          DownloadVideoEvent(
                                            videoId: widget.video.id,
                                            title: widget.video.title,
                                            isAudioOnly: false,
                                            preferredQuality: 'Medium',
                                          ),
                                        );
                                  }
                                },
                                label: const Text(
                                  'Download Video (Video + Audio)',
                                  style: TextStyle(
                                    fontFamily: 'Product Sans',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.music_note_rounded),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? Colors.deepPurpleAccent : Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                                ),
                                onPressed: () async {
                                  print('VideoDetailScreen: Download Audio button pressed');
                                  if (await _checkAndRequestPermissions()) {
                                    context.read<YoutubeBloc>().add(
                                          DownloadVideoEvent(
                                            videoId: widget.video.id,
                                            title: widget.video.title,
                                            isAudioOnly: true,
                                            preferredQuality: 'Medium',
                                          ),
                                        );
                                  }
                                },
                                label: const Text(
                                  'Download Audio (MP3)',
                                  style: TextStyle(
                                    fontFamily: 'Product Sans',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}