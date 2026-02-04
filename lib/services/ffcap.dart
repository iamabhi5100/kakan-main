import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';

class FFCap {
  static bool? _x264;

  /// Returns true if 'libx264' encoder is available in this build.
  static Future<bool> hasX264() async {
    if (_x264 != null) return _x264!;
    final found = await _scan('encoders', needle: 'libx264');
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
