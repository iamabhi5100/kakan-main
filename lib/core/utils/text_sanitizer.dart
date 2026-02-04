// lib/core/utils/text_sanitizer.dart
import 'dart:convert';

class TextSanitizer {
  /// Strips invalid UTF-16 surrogate pairs / control chars so Text() never throws.
  static String safe(String? input, {String fallback = ''}) {
    if (input == null) return fallback;
    // Remove invalid surrogates & control characters (except \n\t).
    final sb = StringBuffer();
    for (final rune in input.runes) {
      if (_isValidRune(rune)) sb.writeCharCode(rune);
    }
    // Sometimes APIs deliver UTF-8 bytes mis-decoded; try to “rescue” if we see � a lot.
    final s = sb.toString();
    if (_looksMojibake(s)) {
      try {
        final bytes = latin1.encode(s);
        return utf8.decode(bytes, allowMalformed: true);
      } catch (_) {}
    }
    return s;
  }

  static bool _isValidRune(int r) {
    // Basic control chars except newline & tab are dropped
    if (r < 0x20 && r != 0x09 && r != 0x0A) return false;
    // Lone surrogate halves
    if (r >= 0xD800 && r <= 0xDFFF) return false;
    // Non-characters
    if (r >= 0xFDD0 && r <= 0xFDEF) return false;
    if ((r & 0xFFFF) == 0xFFFF || (r & 0xFFFF) == 0xFFFE) return false;
    return true;
  }

  static bool _looksMojibake(String s) {
    final q = '�';
    final bad = q.runes.first;
    final count = s.runes.where((r) => r == bad).length;
    return count >= 3; // heuristic
  }
}
