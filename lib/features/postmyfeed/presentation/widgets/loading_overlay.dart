import 'package:flutter/material.dart';

class LoadingOverlay {
  static bool _shown = false;

  static void show(BuildContext context, {String? message}) {
    if (_shown) return;
    _shown = true;
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: false,
      barrierLabel: 'loading',
      pageBuilder: (_, __, ___) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.75),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    message ?? 'Please wait…',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static void hide(BuildContext context) {
    if (!_shown) return;
    _shown = false;
    Navigator.of(context, rootNavigator: true).pop();
  }
}
