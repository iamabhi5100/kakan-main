import 'package:flutter/foundation.dart';

class ChuckerConfig {
  // Enable Chucker only in debug mode by default
  static bool get isEnabled => kDebugMode && _isChuckerEnabled;

  // Internal flag for toggling Chucker (can be modified via UI or env)
  static bool _isChuckerEnabled = true;

  // Method to toggle Chucker (e.g., via UI for testers)
  static void setChuckerEnabled(bool enabled) {
    _isChuckerEnabled = enabled;
  }
}