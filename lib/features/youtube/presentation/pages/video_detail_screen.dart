// lib/features/youtube/presentation/pages/video_detail_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import 'package:kakan/features/youtube/domain/entities/video_entity.dart';
import 'package:kakan/features/youtube/presentation/bloc/youtube_bloc.dart';
import 'package:kakan/features/youtube/presentation/bloc/youtube_event.dart';
import 'package:kakan/features/youtube/presentation/bloc/youtube_state.dart';
import 'package:device_info_plus/device_info_plus.dart';

// Theming tokens (match video editor: neon green & blue)
const _bg = Color(0xFF0A0C10);
const _card = Color(0xFF12151C);
const _muted = Color(0xFF8B95A5);
const _text = Color(0xFFF0F3F8);
const _accent = Color(0xFF00E5A8);
const _accent2 = Color(0xFF00B4D8);
const _neonGreenGlow = Color(0x4000E5A8);
const _neonBlueGlow = Color(0x4000B4D8);

class VideoDetailScreen extends StatefulWidget {
  final VideoEntity video;

  const VideoDetailScreen({Key? key, required this.video}) : super(key: key);

  @override
  _VideoDetailScreenState createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends State<VideoDetailScreen> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  void _safeSnack(String message, {Color? bg}) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messenger = _scaffoldMessengerKey.currentState;
      if (messenger == null) return;
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.fixed,
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: bg ?? Colors.redAccent,
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    debugPrint('VideoDetailScreen: Initializing for video ID: ${widget.video.id}');
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
      debugPrint('VideoDetailScreen: All permissions granted');
      return true;
    }

    final results = await permissions.request();
    bool grantedNow = results.values.every((status) => status.isGranted);

    if (!grantedNow) {
      debugPrint('VideoDetailScreen: Permissions denied: $results');
      _safeSnack('Please grant all permissions to download. Go to app settings to allow.');
      await openAppSettings();
      return false;
    }

    debugPrint('VideoDetailScreen: Permissions granted after request');
    return true;
  }

  void _showSnackBar(String message) {
    String displayMessage = message;
    if (message.contains('Video unavailable') ||
        message.contains('restricted') ||
        message.contains('403') ||
        message.contains('No available video streams')) {
      displayMessage = 'This video is restricted or unavailable for download.';
    } else if (message.contains('Rate limit exceeded')) {
      displayMessage =
          'Rate limit reached. Please wait a few minutes and try again.';
    } else if (message.contains('Request Entity Too Large')) {
      displayMessage =
          'Video file is too large. Try a smaller video or contact support.';
    }
    _safeSnack(displayMessage);
  }

  String _formatViews(int views) {
    if (views >= 1000000000)
      return "${(views / 1000000000).toStringAsFixed(1)}B views";
    if (views >= 1000000)
      return "${(views / 1000000).toStringAsFixed(1)}M views";
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final state = context.read<YoutubeBloc>().state;
        if (state is YoutubeDownloading) {
          debugPrint('VideoDetailScreen: Back button ignored during download');
          _safeSnack('Please wait, download in progress');
          return false;
        }
        debugPrint('VideoDetailScreen: Back button pressed');
        return true;
      },
      child: ScaffoldMessenger(
        key: _scaffoldMessengerKey,
        child: Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _bg,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: _text),
              onPressed: () {
                final state = context.read<YoutubeBloc>().state;
                if (state is YoutubeDownloading) {
                  debugPrint('VideoDetailScreen: AppBar back button ignored during download');
                  _safeSnack('Please wait, download in progress');
                  return;
                }
                debugPrint('VideoDetailScreen: AppBar back button pressed');
                context.pop();
              },
            ),
            title: Text(
              widget.video.title,
              style: const TextStyle(
                color: _text,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            centerTitle: true,
          ),
          body: BlocConsumer<YoutubeBloc, YoutubeState>(
            listener: (context, state) {
              debugPrint('VideoDetailScreen: BlocConsumer received state: $state');
              if (state is YoutubeDownloaded) {
                debugPrint('VideoDetailScreen: YoutubeDownloaded, isAudioOnly: ${state.isAudioOnly}, filePath: ${state.filePath}');
                if (!mounted) return;
                final file = File(state.filePath);
                file.exists().then((exists) {
                  if (!exists) {
                    debugPrint('VideoDetailScreen: File does not exist: ${state.filePath}');
                    _safeSnack('Downloaded file not found');
                    return;
                  }
                  debugPrint('VideoDetailScreen: File exists: ${state.filePath}');
                  final isAudio = state.isAudioOnly;
                  final route = isAudio ? '/youtube-audio-editor' : '/youtube-video-editor';
                  debugPrint('VideoDetailScreen: Navigating to $route');
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    context.push(
                      route,
                      extra: {
                        'filePath': state.filePath,
                        'videoId': state.videoId,
                        'title': state.title,
                        if (isAudio) 'thumbnailUrl': widget.video.thumbnailUrl,
                      },
                    ).catchError((e) {
                      debugPrint('VideoDetailScreen: Navigation to $route failed: $e');
                      _safeSnack('Navigation failed: $e');
                      return null;
                    });
                  });
                });
              } else if (state is YoutubeError) {
                debugPrint('VideoDetailScreen: YoutubeError: ${state.message}');
                _showSnackBar(state.message);
              }
            },
            builder: (context, state) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _neonGreenGlow,
                              blurRadius: 12,
                              spreadRadius: 0,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.network(
                              widget.video.thumbnailUrl ??
                                  'https://via.placeholder.com/1280x720',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Center(
                                    child: Text(
                                      'Unable to load thumbnail',
                                      style: TextStyle(color: _muted),
                                    ),
                                  ),
                            ),
                          ),
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
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _text,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Text(
                                _formatViews(widget.video.viewCount),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _muted,
                                ),
                              ),
                              Text('•', style: TextStyle(color: _muted, fontSize: 13)),
                              Text(
                                widget.video.channelTitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _muted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.video.publishedDate != null &&
                                  widget.video.publishedDate!.isNotEmpty) ...[
                                Text('•', style: TextStyle(color: _muted, fontSize: 13)),
                                Text(
                                  _publishedAgo(widget.video.publishedDate!),
                                  style: TextStyle(fontSize: 13, color: _muted),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 20),
                          Divider(color: _muted.withOpacity(0.3), height: 1),
                          const SizedBox(height: 20),
                          if (state is YoutubeDownloading)
                            Center(
                              child: _CircularDownloadProgress(progress: state.progress),
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _ActionButton(
                                  label: 'Download Video',
                                  icon: Icons.download_rounded,
                                  accent: _accent,
                                  glowColor: _neonGreenGlow,
                                  onPressed: () async {
                                    debugPrint('VideoDetailScreen: Download Video button pressed');
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
                                ),
                                const SizedBox(height: 12),
                                _ActionButton(
                                  label: 'Download Audio (MP3)',
                                  icon: Icons.music_note_rounded,
                                  accent: _accent2,
                                  glowColor: _neonBlueGlow,
                                  onPressed: () async {
                                    debugPrint('VideoDetailScreen: Download Audio button pressed');
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
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Neon-styled action button for Download Video / Download Audio.
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final Color glowColor;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.accent,
    required this.glowColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withOpacity(0.35), width: 1),
            boxShadow: [
              BoxShadow(
                color: glowColor,
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: _text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular download progress with neon green ring and animated percentage.
class _CircularDownloadProgress extends StatefulWidget {
  final double progress;

  const _CircularDownloadProgress({required this.progress});

  @override
  State<_CircularDownloadProgress> createState() => _CircularDownloadProgressState();
}

class _CircularDownloadProgressState extends State<_CircularDownloadProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _animProgress;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animProgress = Tween<double>(begin: 0, end: widget.progress).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
    _animCtrl.forward();
  }

  @override
  void didUpdateWidget(covariant _CircularDownloadProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _animProgress = Tween<double>(begin: oldWidget.progress, end: widget.progress).animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
      );
      _animCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 128.0;
    const strokeWidth = 10.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Downloading',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _muted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: size,
              height: size,
              child: AnimatedBuilder(
                animation: _animProgress,
                builder: (context, _) {
                  return CustomPaint(
                    size: const Size(size, size),
                    painter: _CircularProgressPainter(
                      progress: _animProgress.value,
                      strokeWidth: strokeWidth,
                      backgroundColor: _card,
                      progressColor: _accent,
                      glowColor: _neonGreenGlow,
                      centerText: '${(_animProgress.value * 100).toStringAsFixed(0)}%',
                      textColor: _text,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please wait...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _muted.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color backgroundColor;
  final Color progressColor;
  final Color glowColor;
  final String centerText;
  final Color textColor;

  _CircularProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.progressColor,
    required this.glowColor,
    required this.centerText,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth / 2;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -1.5707963267948966;
    final sweepAngle = 2 * 3.141592653589793 * progress.clamp(0.0, 1.0);
    canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);

    if (progress > 0 && progress < 1) {
      final glowPaint = Paint()
        ..color = glowColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawArc(rect, startAngle, sweepAngle, false, glowPaint);
    }

    // Draw percentage text at exact geometric center
    final textPainter = TextPainter(
      text: TextSpan(
        text: centerText,
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: -0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: size.width);

    final textOffset = Offset(
      center.dx - textPainter.width / 2,
      center.dy - textPainter.height / 2,
    );
    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter old) =>
      old.progress != progress || old.centerText != centerText;
}
