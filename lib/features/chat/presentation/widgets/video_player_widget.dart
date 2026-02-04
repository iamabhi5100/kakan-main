import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

typedef VideoKeyRemoved = void Function(GlobalKey<VideoPlayerWidgetState>);

class VideoPlayerWidget extends StatefulWidget {
  final String url;
  final VoidCallback pauseAll;
  final VideoKeyRemoved onKeyRemoved;
  final String? previewImageUrl; // optional future use

  const VideoPlayerWidget({
    Key? key,
    required this.url,
    required this.pauseAll,
    required this.onKeyRemoved,
    this.previewImageUrl,
  }) : super(key: key);

  @override
  VideoPlayerWidgetState createState() => VideoPlayerWidgetState();
}

class VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _initializing = false;
  bool _initialized = false;
  bool _isPlaying = false;
  bool _isMuted = false;
  String? _error;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  Future<void> _initIfNeeded() async {
    if (_initialized || _initializing) return;
    setState(() {
      _initializing = true;
      _error = null;
    });
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await c.initialize();
      c.addListener(_tick);
      if (!mounted) return;
      setState(() {
        _controller = c;
        _initialized = true;
        _duration = c.value.duration;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load video';
      });
    } finally {
      if (mounted) {
        setState(() {
          _initializing = false;
        });
      }
    }
  }

  void _tick() {
    final v = _controller?.value;
    if (v == null || !mounted) return;
    setState(() {
      _position = v.position;
      _isPlaying = v.isPlaying;
    });
  }

  Future<void> _play() async {
    widget.pauseAll();
    await _initIfNeeded();
    if (_controller != null && _initialized) {
      await _controller!.play();
    }
  }

  /// Public pause so parent can call k.currentState?.pause()
  Future<void> pause() async {
    await _controller?.pause();
  }

  void _toggleMute() {
    if (_controller == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0 : 1);
    });
  }

  @override
  void dispose() {
    _controller?.removeListener(_tick);
    _controller?.dispose();
    widget.onKeyRemoved(widget.key as GlobalKey<VideoPlayerWidgetState>);
    super.dispose();
  }

  void _openFullscreen() {
    if (_controller == null || !_initialized) return;
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _FullscreenVideo(controller: _controller!),
    ));
  }

  Widget _buildPlaceholder() {
    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (_initializing)
          const CircularProgressIndicator()
        else
          IconButton(
            iconSize: 64,
            icon: const Icon(Icons.play_circle_fill, color: Colors.white70),
            onPressed: _play,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = _initialized && _controller != null;

    return AspectRatio(
      aspectRatio: ready ? _controller!.value.aspectRatio : 16 / 9,
      child: Stack(
        children: [
          if (_error != null)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 40),
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: _play, child: const Text('Retry')),
                ],
              ),
            )
          else if (!ready)
            _buildPlaceholder()
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: VideoPlayer(_controller!),
            ),

          if (ready && !_isPlaying)
            Positioned.fill(
              child: Center(
                child: IconButton(
                  iconSize: 56,
                  icon: const Icon(Icons.play_circle_fill, color: Colors.white70),
                  onPressed: _play,
                ),
              ),
            ),

          if (ready)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const BoxDecoration(
                  color: Color(0x80000000),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                      color: Colors.white,
                      onPressed: _isPlaying ? pause : _play,
                    ),
                    Expanded(
                      child: Slider(
                        value: _position.inSeconds
                            .toDouble()
                            .clamp(0, (_duration.inSeconds > 0 ? _duration.inSeconds : 1))
                            .toDouble(),
                        max: (_duration.inSeconds > 0 ? _duration.inSeconds : 1).toDouble(),
                        onChanged: (v) => _controller!.seekTo(Duration(seconds: v.toInt())),
                      ),
                    ),
                    IconButton(
                      icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
                      color: Colors.white,
                      onPressed: _toggleMute,
                    ),
                    IconButton(
                      icon: const Icon(Icons.fullscreen),
                      color: Colors.white,
                      onPressed: _openFullscreen,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FullscreenVideo extends StatelessWidget {
  final VideoPlayerController controller;
  const _FullscreenVideo({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: controller.value.isInitialized
            ? FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              )
            : const CircularProgressIndicator(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pop(context),
        child: const Icon(Icons.close),
      ),
    );
  }
}
