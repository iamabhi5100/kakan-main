import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:kakan/config/theme.dart';
import 'dart:developer' as developer;

class VideoPlayerWidget extends StatefulWidget {
  final String url;
  final VoidCallback pauseAll;
  final Function(GlobalKey<VideoPlayerWidgetState>) onKeyRemoved;

  const VideoPlayerWidget({
    Key? key,
    required this.url,
    required this.pauseAll,
    required this.onKeyRemoved,
  }) : super(key: key);

  @override
  VideoPlayerWidgetState createState() => VideoPlayerWidgetState();
}

// Add this widget at the end of the file
class FullScreenVideoPage extends StatelessWidget {
  final VideoPlayerController controller;

  const FullScreenVideoPage({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}

class VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isMuted = false;
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    developer.log('Initializing VideoPlayerWidget with URL: ${widget.url}');
    _initializeController();
  }

  void _initializeController() {
    _controller = VideoPlayerController.network(widget.url)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _duration = _controller.value.duration;
            developer.log('Video initialized successfully. Duration: $_duration');
          });
        }
      }).catchError((error) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load video: $error';
            developer.log('Video initialization failed: $error');
          });
        }
      });
    _controller.addListener(() {
      if (mounted) {
        setState(() {
          _position = _controller.value.position;
        });
      }
    });
  }

  @override
  void dispose() {
    developer.log('Disposing VideoPlayerWidget for URL: ${widget.url}');
    _controller.dispose();
    widget.onKeyRemoved(widget.key as GlobalKey<VideoPlayerWidgetState>);
    super.dispose();
  }

  void play() {
    widget.pauseAll();
    _controller.play().catchError((error) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to play video: $error';
          developer.log('Video playback failed: $error');
        });
      }
    });
  }

  void pause() {
    _controller.pause();
  }

  void toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0 : 1);
      developer.log('Mute toggled: $_isMuted');
    });
  }

  void enterFullScreen() {
    if (_isInitialized) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FullScreenVideoPage(controller: _controller),
          fullscreenDialog: true,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot enter fullscreen: Video not loaded')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: _isInitialized ? _controller.value.aspectRatio : 16 / 9,
          child: Stack(
            children: [
              if (_errorMessage != null)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 50),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _errorMessage = null;
                            _isInitialized = false;
                          });
                          _initializeController();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else if (!_isInitialized)
                const Center(child: CircularProgressIndicator())
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: VideoPlayer(_controller),
                ),
              if (_isInitialized && !_controller.value.isPlaying)
                Positioned.fill(
                  child: Center(
                    child: IconButton(
                      icon: const Icon(Icons.play_arrow, size: 50, color: Colors.white70),
                      onPressed: play,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_isInitialized)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: appTheme.primaryColor,
                  ),
                  onPressed: _controller.value.isPlaying ? pause : play,
                ),
                Expanded(
                  child: Slider(
                    value: _position.inSeconds.toDouble(),
                    max: (_duration.inSeconds.toDouble() > 0
                        ? _duration.inSeconds.toDouble()
                        : 1.0),
                    onChanged: (v) => _controller.seekTo(Duration(seconds: v.toInt())),
                  ),
                ),
                IconButton(
                  icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
                  onPressed: toggleMute,
                ),
                IconButton(
                  icon: const Icon(Icons.fullscreen),
                  onPressed: enterFullScreen,
                ),
              ],
            ),
          ),
      ],
    );
  }
}