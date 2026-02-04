import 'package:flutter/material.dart';
import 'package:kakan/core/error/app_error.dart';
import 'package:kakan/core/widgets/error_screen.dart';

/// Pushes the full-screen ErrorScreen. When "Retry" is tapped, the screen
/// is dismissed and (optionally) a retry callback is invoked.
void showErrorScreen(
  BuildContext context,
  AppErrorType type, {
  VoidCallback? onRetry,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (screenCtx) => ErrorScreen(
        type: type,
        onRetry: () {
          Navigator.of(screenCtx).pop(); // close error screen
          if (onRetry != null) onRetry();
        },
      ),
    ),
  );
}
