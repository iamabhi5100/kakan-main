import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

/// Coordinates media so only one (audio OR video) can play at a time.
/// Also lets the feed pause playback when the playing cell is completely
/// out of view.
class MediaManager {
  MediaManager._();
  static final MediaManager _i = MediaManager._();
  factory MediaManager() => _i;

  VideoPlayerController? _video;
  AudioPlayer? _audio;
  String? _ownerId; // feed id of the item currently "owning" playback

  String? get currentOwnerId => _ownerId;

  /// Ensure only this video plays (pause any audio/video first).
  void requestVideoPlay(String feedId, VideoPlayerController controller) {
    if (_video == controller && _ownerId == feedId) return;
    pauseAll();
    _video = controller;
    _audio = null;
    _ownerId = feedId;
    controller.play();
  }

  /// Ensure only this audio plays (pause any audio/video first).
  void requestAudioPlay(String feedId, AudioPlayer player) {
    if (_audio == player && _ownerId == feedId) return;
    pauseAll();
    _audio = player;
    _video = null;
    _ownerId = feedId;
    player.play();
  }

  /// Convenience toggles — if already owner, toggle play/pause; otherwise
  /// claim ownership and start.
  void toggleVideo(String feedId, VideoPlayerController controller) {
    if (_ownerId == feedId && _video == controller) {
      controller.value.isPlaying ? controller.pause() : controller.play();
    } else {
      requestVideoPlay(feedId, controller);
    }
  }

  Future<void> toggleAudio(String feedId, AudioPlayer player) async {
    if (_ownerId == feedId && _audio == player) {
      player.playing ? await player.pause() : await player.play();
    } else {
      requestAudioPlay(feedId, player);
    }
  }

  /// Pause whatever is playing.
  void pauseAll() {
    try { _video?.pause(); } catch (_) {}
    try { _audio?.pause(); } catch (_) {}
  }

  /// Pause if the owner matches (used when the owner scrolled off-screen).
  void pauseIfOwner(String feedId) {
    if (_ownerId == feedId) pauseAll();
  }

  /// Clear pointers when an owning widget is disposed.
  void clearIfOwnerDisposed(String feedId, {bool isVideo = false}) {
    if (_ownerId == feedId) {
      _ownerId = null;
      if (isVideo) _video = null; else _audio = null;
    }
  }

  /// App-wide cleanup (e.g., on logout).
  void disposeMedia() {
    try { _video?.dispose(); } catch (_) {}
    try { _audio?.dispose(); } catch (_) {}
    _video = null;
    _audio = null;
    _ownerId = null;
  }
}
