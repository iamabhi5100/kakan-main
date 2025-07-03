import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

class MediaManager {
  static final MediaManager _instance = MediaManager._internal();
  factory MediaManager() => _instance;
  MediaManager._internal();

  VideoPlayerController? _videoController;
  AudioPlayer? _audioPlayer;

  void setVideoController(VideoPlayerController controller) {
    // Pause any playing audio or video
    pauseMedia();
    _videoController = controller;
  }

  void setAudioPlayer(AudioPlayer player) {
    // Pause any playing audio or video
    pauseMedia();
    _audioPlayer = player;
  }

  void playMedia() {
    if (_videoController != null && !_videoController!.value.isPlaying) {
      _audioPlayer?.pause();
      _videoController!.play();
    } else if (_audioPlayer != null && !_audioPlayer!.playing) {
      _videoController?.pause();
      _audioPlayer!.play();
    }
  }

  void pauseMedia() {
    _videoController?.pause();
    _audioPlayer?.pause();
  }

  void disposeMedia() {
    _videoController?.dispose();
    _audioPlayer?.dispose();
    _videoController = null;
    _audioPlayer = null;
  }
}