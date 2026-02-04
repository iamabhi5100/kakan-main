import 'dart:io';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:kakan/services/ffcap.dart';
import 'package:path/path.dart' as p;

enum CropAspect { original, ratio1x1, ratio9x16, ratio16x9, ratio4x5 }

class FFmpegExporter {
  static Future<String> export(
    String inputPath, {
    String? outputDir,
    Duration? trimStart,
    Duration? trimEnd,
    bool copyIfNoEdits = false,
    int crf = 21,
    String preset = 'veryfast',
    CropAspect? cropAspect = CropAspect.original,
  }) async {
    final dir = outputDir ?? p.dirname(inputPath);
    final out = p.join(
      dir,
      '${p.basenameWithoutExtension(inputPath)}_safe_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );

    final probe = await FFprobeKit.getMediaInformation(inputPath);
    final info = probe.getMediaInformation();
    if (info == null) {
      throw Exception('Could not probe input');
    }

    final streams = info.getStreams() ?? [];
    final hasAudio = streams.any((s) => (s.getAllProperties()?['codec_type']) == 'audio');

    final videoStream = streams.firstWhere(
      (s) => (s.getAllProperties()?['codec_type']) == 'video',
      orElse: () => streams.first,
    );

    final props = videoStream.getAllProperties() ?? {};
    final fpsStr = (props['avg_frame_rate'] as String?) ??
        (props['r_frame_rate'] as String?) ?? '30/1';
    final width = (props['width'] as int?) ?? 0;
    final height = (props['height'] as int?) ?? 0;

    double fps;
    try {
      final sp = fpsStr.split('/');
      fps = sp.length == 2 ? (double.parse(sp[0]) / double.parse(sp[1])) : 30.0;
      if (!fps.isFinite || fps <= 0) fps = 30.0;
      if (fps > 30) fps = 30.0;
    } catch (_) {
      fps = 30.0;
    }

    final filters = <String>[];
    final wantCrop = (cropAspect != null && cropAspect != CropAspect.original);
    if (wantCrop && width > 0 && height > 0) {
      final A = _aspectToDouble(cropAspect!).toStringAsFixed(8);
      final crop =
          "crop=w='if(gte(iw/ih,$A),ih*$A,iw)':h='if(gte(iw/ih,$A),ih,iw/$A)':x='(iw - w)/2':y='(ih - h)/2'";
      filters.add(crop);
    }
    filters.addAll([
      "scale=trunc(iw/2)*2:trunc(ih/2)*2",
      "setsar=1:1",
      "format=yuv420p",
    ]);
    final vf = filters.join(',');

    final x264 = await FFCap.hasX264();
    final common = <String>[
      '-y',
      '-hide_banner', '-loglevel', 'info',
      '-hwaccel', 'none',
      if (trimStart != null) ...['-ss', '${trimStart.inMilliseconds / 1000}'],
      '-i', inputPath,
      if (trimEnd != null) ...['-to', '${trimEnd.inMilliseconds / 1000}'],
      '-vf', vf,
      '-pix_fmt', 'yuv420p',
      '-r', fps.toStringAsFixed(3),
      '-threads', '2',
      if (hasAudio) ...['-c:a', 'aac', '-b:a', '128k', '-ar', '44100', '-ac', '2'] else '-an',
      '-movflags', '+faststart',
      '-max_muxing_queue_size', '1024',
      out,
    ];

    final args = <String>[
      ...common.take(0),
      '-y','-hide_banner','-loglevel','info','-hwaccel','none',
      if (trimStart != null) ...['-ss', '${trimStart.inMilliseconds / 1000}'],
      '-i', inputPath,
      if (trimEnd != null) ...['-to', '${trimEnd.inMilliseconds / 1000}'],
      '-vf', vf,
      if (x264) ...[
        '-c:v', 'libx264',
        '-profile:v', 'baseline',
        '-level:v', '3.0',
        '-preset', preset,
        '-crf', '$crf',
      ] else ...[
        // Fallback if x264 missing
        '-c:v', 'mpeg4',
        '-qscale:v', '3',
      ],
      '-pix_fmt', 'yuv420p',
      '-r', fps.toStringAsFixed(3),
      '-threads', '2',
      if (hasAudio) ...['-c:a', 'aac', '-b:a', '128k', '-ar', '44100', '-ac', '2'] else '-an',
      '-movflags', '+faststart',
      '-max_muxing_queue_size', '1024',
      out,
    ];

    print('[FFmpegExporter] Using codec: ${x264 ? 'libx264 (software)' : 'mpeg4 (fallback)'}');
    print('[FFmpegExporter] CMD: ${args.join(' ')}');

    final session = await FFmpegKit.executeWithArguments(args);
    final rc = await session.getReturnCode();
    final logs = await session.getAllLogsAsString();
    print('[FFmpegExporter] RC=${rc?.getValue()}');
    if (!(ReturnCode.isSuccess(rc))) {
      print('[FFmpegExporter] FULL LOGS:\n$logs');
    }

    if (ReturnCode.isSuccess(rc)) return out;

    if (copyIfNoEdits && trimStart == null && trimEnd == null) {
      final copyOut = p.join(
        dir,
        '${p.basenameWithoutExtension(inputPath)}_copy_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );
      final copyArgs = [
        '-y','-hide_banner','-loglevel','info',
        '-hwaccel','none',
        '-i', inputPath,
        '-c','copy',
        '-movflags','+faststart',
        copyOut,
      ];
      print('[FFmpegExporter] COPY fallback CMD: ${copyArgs.join(' ')}');
      final copySess = await FFmpegKit.executeWithArguments(copyArgs);
      final copyRc = await copySess.getReturnCode();
      final copyLogs = await copySess.getAllLogsAsString();
      print('[FFmpegExporter] COPY RC=${copyRc?.getValue()}');
      if (!ReturnCode.isSuccess(copyRc)) {
        print('[FFmpegExporter] COPY LOGS:\n$copyLogs');
      }
      if (ReturnCode.isSuccess(copyRc)) return copyOut;
    }

    throw Exception('FFmpeg export failed (${rc?.getValue()}):$logs');
  }

  /// Returns video duration from file (via FFprobe). Used when native player metadata isn't ready.
  static Future<Duration> getMediaDuration(String inputPath) async {
    final probe = await FFprobeKit.getMediaInformation(inputPath);
    final info = probe.getMediaInformation();
    final durStr = info?.getDuration();
    if (durStr == null || durStr.isEmpty) return Duration.zero;
    final sec = double.tryParse(durStr) ?? 0.0;
    return Duration(milliseconds: (sec * 1000).round());
  }

  /// Mali-safe export: CFR 30fps, even dims, yuv420p. Uses libx264 if available, else mpeg4.
  /// Use for upload/share to avoid green diagonal glitch on Mali/MediaTek GPUs.
  static Future<String> exportMaliSafe(
    String inputPath, {
    Duration? trimStart,
    Duration? trimEnd,
    String? outputDir,
  }) async {
    final dir = outputDir ?? p.dirname(inputPath);
    final out = p.join(
      dir,
      '${p.basenameWithoutExtension(inputPath)}_mali_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );
    final start = trimStart ?? Duration.zero;
    final end = trimEnd;

    final vf =
        'bwdif=mode=0:parity=auto:deint=all,'
        'setsar=1,'
        'scale=trunc(iw/2)*2:trunc(ih/2)*2,'
        'format=yuv420p,'
        'pad=ceil(iw/32)*32:ceil(ih/32)*32:(ow-iw)/2:(oh-ih)/2';

    // -vsync is deprecated in newer FFmpeg; use -fps_mode.
    // libx264 may be missing in some FFmpegKit mobile builds; fall back to mpeg4.
    final hasX264 = await FFCap.hasX264();

    final cmd = <String>[
      '-y',
      '-ss', (start.inMilliseconds / 1000.0).toStringAsFixed(3),
      if (end != null) ...['-to', (end.inMilliseconds / 1000.0).toStringAsFixed(3)],
      '-i', inputPath,
      '-vf', vf,
      '-fps_mode', 'cfr',
      '-r', '30',
      '-pix_fmt', 'yuv420p',
      if (hasX264) ...[
        '-c:v', 'libx264',
        '-preset', 'veryfast',
        '-crf', '20',
        '-profile:v', 'baseline',
        '-level', '3.1',
        '-g', '30',
        '-bf', '0',
        '-refs', '1',
        '-color_primaries', 'bt709',
        '-colorspace', 'bt709',
        '-color_trc', 'bt709',
      ] else ...[
        '-c:v', 'mpeg4',
        '-qscale:v', '3',
      ],
      '-c:a', 'aac',
      '-b:a', '128k',
      '-ar', '44100',
      '-movflags', '+faststart',
      out,
    ];

    final session = await FFmpegKit.executeWithArguments(cmd);
    final rc = await session.getReturnCode();
    if (!ReturnCode.isSuccess(rc)) {
      final logs = await session.getAllLogsAsString();
      throw Exception('Mali-safe export failed (${rc?.getValue()}):$logs');
    }
    return out;
  }

  static double _aspectToDouble(CropAspect aspect) {
    switch (aspect) {
      case CropAspect.ratio1x1:  return 1.0;
      case CropAspect.ratio9x16: return 9/16;
      case CropAspect.ratio16x9: return 16/9;
      case CropAspect.ratio4x5:  return 4/5;
      case CropAspect.original:
      default: return 0.0;
    }
  }
}
