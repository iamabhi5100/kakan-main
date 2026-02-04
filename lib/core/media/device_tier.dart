// lib/core/media/device_tier.dart
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

enum DeviceTier { low, mid, high }

class DeviceTierDetector {
  static Future<DeviceTier> detect() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        final sdk = a.version.sdkInt;
        // Extremely rough, but good enough to gate profiles/resolution.
        if (sdk <= 26) return DeviceTier.low;       // Oreo & below
        if (sdk <= 30) return DeviceTier.mid;       // R & below
        return DeviceTier.high;
      } else if (Platform.isIOS) {
        final i = await info.iosInfo;
        // Very rough mapping via device yearClass-ish guess
        if ((i.utsname.machine ?? '').contains('iPhone7') ||
            (i.utsname.machine ?? '').contains('iPad6')) {
          return DeviceTier.low;
        }
        return DeviceTier.mid;
      }
    } catch (_) {}
    return DeviceTier.mid;
  }
}
