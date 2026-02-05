import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';

class FFCap {
  static bool? _x264;

  /// Returns true if 'libx264' encoder is available in this build.
  /// Uses a real encode probe so we never use libx264 when the build doesn't include it
  /// (e.g. FFmpeg-Kit mobile builds without --enable-libx264).
  static Future<bool> hasX264() async {
    if (_x264 != null) return _x264!;
    // Probe by running a minimal encode; many mobile builds list "libx264" in -encoders
    // but fail with "Unknown encoder 'libx264'" when used.
    final probeArgs = [
      '-y', '-hide_banner', '-loglevel', 'error',
      '-f', 'lavfi', '-i', 'nullsrc=d=0.1:s=64x64',
      '-c:v', 'libx264', '-t', '0', '-f', 'null', '-',
    ];
    final session = await FFmpegKit.executeWithArguments(probeArgs);
    final rc = await session.getReturnCode();
    final found = ReturnCode.isSuccess(rc);
    _x264 = found;
    return found;
  }

  /// Dumps encoders/decoders/muxers/demuxers to the console for diagnostics.
  static Future<void> dumpCapabilities() async {
    await _scan('version');
    await _scan('configuration');
    await _scan('encoders');
    await _scan('decoders');
    await _scan('muxers');
    await _scan('demuxers');
  }

  static Future<bool> _scan(String what, {String? needle}) async {
    final args = <String>['-hide_banner', '-loglevel', 'info'];
    switch (what) {
      case 'version':
        args.addAll(['-version']);
        break;
      case 'configuration':
        args.addAll(['-buildconf']);
        break;
      case 'encoders':
        args.addAll(['-encoders']);
        break;
      case 'decoders':
        args.addAll(['-decoders']);
        break;
      case 'muxers':
        args.addAll(['-muxers']);
        break;
      case 'demuxers':
        args.addAll(['-demuxers']);
        break;
    }

    print('[FFCap] Running: ${args.join(' ')}');
    String full = '';
    final session = await FFmpegKit.executeWithArguments(args);
    final logs = await session.getAllLogsAsString();
    final rc = await session.getReturnCode();
    full = logs ?? '';
    print('[FFCap][$what][rc=${rc?.getValue()}]\n$full');

    if (needle == null) return true;
    final has = full.toLowerCase().contains(needle.toLowerCase());
    print('[FFCap] Needle "$needle" present: $has');
    return has;
  }
}
