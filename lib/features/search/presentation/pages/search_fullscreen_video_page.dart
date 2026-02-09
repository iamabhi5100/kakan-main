// Fullscreen video page with full media controls (play/pause, timeline, mute, close).
// Pass [controller] to reuse the same player (no double audio); otherwise [videoUrl] to create a new one.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakan/features/search/presentation/widgets/search_video_player_controls.dart';
import 'package:video_player/video_player.dart';

class SearchFullscreenVideoPage extends StatefulWidget {
  /// If provided, this controller is used and not disposed (single player, no double audio).
  final VideoPlayerController? controller;
  /// Used only when [controller] is null to create a new controller (disposed on pop).
  final String? videoUrl;

  const SearchFullscreenVideoPage({
    super.key,
    this.controller,
    this.videoUrl,
  });

  @override
  State<SearchFullscreenVideoPage> createState() => _SearchFullscreenVideoPageState();
}

class _SearchFullscreenVideoPageState extends State<SearchFullscreenVideoPage> {
  VideoPlayerController? _controller;
  bool _ownController = false; // true if we created it and must dispose
  bool _initialized = false;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (widget.controller != null) {
      _controller = widget.controller;
      _ownController = false;
      _initialized = _controller!.value.isInitialized;
      // Defer play() to avoid controller notifying during build (setState during build error)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller != null && !_controller!.value.isPlaying) {
          _controller!.play();
          setState(() {});
        }
      });
    } else if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
      _ownController = true;
      _initVideo();
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    if (_ownController) _controller?.dispose();
    super.dispose();
  }

  Future<void> _initVideo() async {
    final url = widget.videoUrl ?? '';
    if (url.isEmpty) return;
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = c;
    try {
      await c.initialize();
      c.setLooping(true);
      c.play();
      if (mounted) setState(() => _initialized = true);
    } catch (_) {
      if (mounted) setState(() => _initialized = false);
    }
  }

  void _toggleMute() {
    _controller?.setVolume(_muted ? 1 : 0);
    setState(() => _muted = !_muted);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.bottomCenter,
          children: [
            if (_initialized && _controller != null)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white70),
              ),
            // Top bar: close only
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom controls: play/pause, timeline, time, mute
            if (_initialized && _controller != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SearchVideoPlayerControls(
                  controller: _controller!,
                  muted: _muted,
                  onMute: _toggleMute,
                  onFullscreen: null,
                  showFullscreen: false,
                  showRotate: false,
                  compact: false,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
