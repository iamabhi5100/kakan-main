// Native Android video player for Mali-safe playback (avoids green diagonal glitch).
// Uses platform view with ExoPlayer + SurfaceView instead of texture rendering.

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

const String _viewType = 'native-video-view';
const String _channelName = 'kakan/native_video';
const String _defaultId = 'editor_preview';

/// Controller for NativeVideoView – play, pause, seek.
class NativeVideoController {
  NativeVideoController({String id = _defaultId}) : _id = id;

  final String _id;
  String get id => _id;
  static final _channel = MethodChannel(_channelName);

  Future<void> play() => _channel.invokeMethod('play', {'id': _id});
  Future<void> pause() => _channel.invokeMethod('pause', {'id': _id});
  Future<void> seekTo(Duration position) =>
      _channel.invokeMethod('seekTo', {'id': _id, 'position': position.inMilliseconds});
  Future<Duration> getPosition() async {
    final ms = await _channel.invokeMethod<int>('getPosition', {'id': _id});
    return Duration(milliseconds: ms ?? 0);
  }

  Future<Duration> getDuration() async {
    final ms = await _channel.invokeMethod<int>('getDuration', {'id': _id});
    return Duration(milliseconds: ms ?? 0);
  }
}

/// Native Android video view (ExoPlayer + SurfaceView).
/// Use on Android to avoid Mali GPU texture glitches.
class NativeVideoView extends StatelessWidget {
  const NativeVideoView({
    super.key,
    required this.controller,
    required this.filePath,
    this.autoPlay = false,
    this.loop = false,
  });

  final NativeVideoController controller;
  final String filePath;
  final bool autoPlay;
  final bool loop;

  @override
  Widget build(BuildContext context) {
    final creationParams = <String, dynamic>{
      'path': filePath,
      'id': controller.id,
    };

    // Use PlatformViewLink for Hybrid Composition (better SurfaceView support)
    return PlatformViewLink(
      viewType: _viewType,
      surfaceFactory: (context, platformViewController) {
        return AndroidViewSurface(
          controller: platformViewController as AndroidViewController,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          // Let taps pass through to Flutter so video area can handle play/pause.
          hitTestBehavior: PlatformViewHitTestBehavior.transparent,
        );
      },
      onCreatePlatformView: (params) {
        return PlatformViewsService.initSurfaceAndroidView(
          id: params.id,
          viewType: _viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create();
      },
    );
  }
}
