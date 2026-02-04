import 'dart:io';

/// Device compatibility helper
/// Returns true for Android, since older or budget phones may require
/// extra normalization and software fallback.
Future<bool> isCompatDevice() async {
  return Platform.isAndroid;
}
