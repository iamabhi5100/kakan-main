import 'dart:io';
import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_full/stream_information.dart';
import 'package:kakan/services/ffcap.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class NormalizationResult {
  final String path;
  final bool transcoded;
  final int canvasWidth, canvasHeight, srcWidth, srcHeight;
  final double srcFps;
  final String srcCodec, srcPixFmt, srcCodecProfile;

  NormalizationResult({
    required this.path,
    required this.transcoded,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.srcWidth,
    required this.srcHeight,
    required this.srcFps,
    required this.srcCodec,
    required this.srcPixFmt,
    required this.srcCodecProfile,
  });
}

class VideoNormalizer {
  static Future<NormalizationResult> normalize(
    String inPath, {
    required bool preferShortsCanvas,
    int shortsCanvasW = 720,
    int shortsCanvasH = 1280,
    int standardCanvasW = 1280,
    int standardCanvasH = 720,
    bool alwaysTranscode = true,
    bool clampFpsTo30 = true,
  }) async {
    if (p.basename(inPath).contains('_safe') && !alwaysTranscode) {
      final pr = await _probe(inPath);
      return NormalizationResult(
        path: inPath,
        transcoded: false,
        canvasWidth: preferShortsCanvas ? shortsCanvasW : standardCanvasW,
        canvasHeight: preferShortsCanvas ? shortsCanvasH : standardCanvasH,
        srcWidth: pr.width,
        srcHeight: pr.height,
        srcFps: pr.fps,
        srcCodec: pr.codec,
        srcPixFmt: pr.pixFmt,
        srcCodecProfile: pr.profile,
      );
    }

    final pr = await _probe(inPath);
    final compat = await _shouldUseCompatCanvas(pr.width, pr.height);

    final canvasW = compat
        ? (preferShortsCanvas ? 360 : 640)
        : (preferShortsCanvas ? shortsCanvasW : standardCanvasW);
    final canvasH = compat
        ? (preferShortsCanvas ? 640 : 360)
        : (preferShortsCanvas ? shortsCanvasH : standardCanvasH);

    int _align16(int v) => max(16, (v ~/ 16) * 16);
    final scaleBy = min(1.0, min(canvasW / pr.width, canvasH / pr.height));
    int scaledW = _align16((pr.width * scaleBy).floor());
    int scaledH = _align16((pr.height * scaleBy).floor());

    if (scaledW > canvasW) scaledW = _align16(canvasW);
    if (scaledH > canvasH) scaledH = _align16(canvasH);

    final needPad = (scaledW < canvasW) || (scaledH < canvasH);
    final fpsFilter =
        compat ? 'fps=24' : (clampFpsTo30 && pr.fps > 30.2 ? 'fps=30' : null);

    final vf = <String>[
      if (fpsFilter != null) fpsFilter,
      'scale=$scaledW:$scaledH:flags=bicubic',
      'setsar=1',
      if (needPad) 'pad=$canvasW:$canvasH:(ow-iw)/2:(oh-ih)/2',
      'format=yuv420p'
    ].join(',');

    final outPath = await _buildOutPath(inPath,
        '${preferShortsCanvas ? 'shorts' : 'std'}_${DateTime.now().millisecondsSinceEpoch}_safe');

    final x264 = await FFCap.hasX264();

    final attempts = <List<String>>[
      [
        '-y', '-hide_banner', '-loglevel', 'info',
        '-hwaccel', 'none',
        '-i', inPath,
        '-vf', vf,
        if (x264) ...[
          '-c:v', 'libx264', '-preset', 'veryfast',
          '-profile:v', compat ? 'baseline' : 'high',
          '-level', compat ? '3.0' : '4.1',
          '-maxrate', compat ? '1200k' : '2500k',
          '-bufsize', compat ? '2400k' : '5000k',
          '-bf', '0', '-refs', '1',
          '-g', compat ? '48' : '60',
          if (compat) '-keyint_min', '48',
        ] else ...[
          '-c:v', 'mpeg4', '-qscale:v', '3'
        ],
        '-pix_fmt', 'yuv420p',
        '-threads', '2',
        '-c:a', 'aac', '-b:a', '96k', '-ac', '2', '-ar', '44100',
        '-movflags', '+faststart',
        outPath
      ],
      [
        '-y', '-hide_banner', '-loglevel', 'info',
        '-hwaccel', 'none',
        '-i', inPath,
        '-vf', vf,
        if (x264) ...[
          '-c:v', 'libx264', '-preset', 'ultrafast',
          '-profile:v', 'baseline', '-level', '3.0',
          '-b:v', '900k', '-maxrate', '900k', '-bufsize', '1800k',
          '-g', '48', '-keyint_min', '48',
          '-bf', '0', '-refs', '1',
        ] else ...[
          '-c:v', 'mpeg4', '-qscale:v', '4'
        ],
        '-pix_fmt', 'yuv420p',
        '-threads', '2',
        '-c:a', 'aac', '-b:a', '96k', '-ac', '2', '-ar', '44100',
        '-movflags', '+faststart',
        outPath
      ],
      if (!x264) [
        '-y', '-hide_banner', '-loglevel', 'info',
        '-hwaccel', 'none',
        '-i', inPath,
        '-vf', vf,
        '-c:v', 'mpeg4', '-qscale:v', '5',
        '-pix_fmt', 'yuv420p',
        '-threads', '2',
        '-c:a', 'aac', '-b:a', '96k', '-ac', '2', '-ar', '44100',
        '-movflags', '+faststart',
        outPath
      ]
    ];

    String? lastError;
    for (var i = 0; i < attempts.length; i++) {
      final session = await FFmpegKit.executeWithArguments(attempts[i]);
      final rc = await session.getReturnCode();
      if (ReturnCode.isSuccess(rc)) {
        return NormalizationResult(
          path: outPath,
          transcoded: true,
          canvasWidth: canvasW,
          canvasHeight: canvasH,
          srcWidth: pr.width,
          srcHeight: pr.height,
          srcFps: pr.fps,
          srcCodec: pr.codec,
          srcPixFmt: pr.pixFmt,
          srcCodecProfile: pr.profile,
        );
      }
      lastError = 'Attempt ${i + 1} failed (rc=${rc?.getValue()})';
    }
    throw Exception(lastError ?? 'Unknown FFmpeg failure');
  }

static Future<_ProbeInfo> _probe(String path) async {
  try {
    final sess = await FFprobeKit.getMediaInformation(path);
    final info = sess.getMediaInformation();
    if (info == null) {
      return _ProbeInfo(0, 0, 0, '', '', '');
    }

    final streams = info.getStreams() ?? [];
    if (streams.isEmpty) {
      return _ProbeInfo(0, 0, 0, '', '', '');
    }

    final v = streams.firstWhere(
      (s) => (s.getType() ?? '') == 'video',
      orElse: () => StreamInformation({}),
    );

    if (v.getWidth() == null || v.getHeight() == null) {
      return _ProbeInfo(0, 0, 0, '', '', '');
    }

    final props = v.getAllProperties() ?? {};
    final rfps = (props['r_frame_rate'] ?? '0/1').toString();
    final fpsParts = rfps.split('/');
    final fps = (fpsParts.length == 2 && double.tryParse(fpsParts[1]) != 0)
        ? (double.parse(fpsParts[0]) / double.parse(fpsParts[1]))
        : 0.0;

    return _ProbeInfo(
      v.getWidth() ?? 0,
      v.getHeight() ?? 0,
      fps,
      (v.getCodec() ?? '').toString(),
      (props['pix_fmt'] ?? '').toString(),
      (props['profile'] ?? '').toString(),
    );
  } catch (_) {
    return _ProbeInfo(0, 0, 0, '', '', '');
  }
}


  static Future<String> _buildOutPath(String inPath, String suffix) async {
    final dir = await getTemporaryDirectory();
    final base = p.basenameWithoutExtension(inPath);
    return p.join(dir.path, '${base}_$suffix.mp4');
  }

  static Future<bool> _shouldUseCompatCanvas(int w, int h) async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final hw = (info.hardware ?? '').toLowerCase();
      final board = (info.board ?? '').toLowerCase();
      return hw.contains('mt') || hw.contains('mediatek') || board.contains('mt') || w >= 1280 || h >= 720;
    } catch (_) {
      return true;
    }
  }
}

class _ProbeInfo {
  final int width, height;
  final double fps;
  final String codec, pixFmt, profile;
  _ProbeInfo(this.width, this.height, this.fps, this.codec, this.pixFmt, this.profile);
}
