import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// Wraps [child] so that the first back press shows a "press back again to exit"
/// toast; a second back within 2 seconds closes the app.
/// Use this only on root routes (e.g. home shell with bottom nav).
class DoubleBackExitScope extends StatefulWidget {
  const DoubleBackExitScope({super.key, required this.child});

  final Widget child;

  @override
  State<DoubleBackExitScope> createState() => _DoubleBackExitScopeState();
}

class _DoubleBackExitScopeState extends State<DoubleBackExitScope> {
  DateTime? _lastBackPressTime;
  static const _window = Duration(seconds: 2);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        final withinWindow = _lastBackPressTime != null &&
            now.difference(_lastBackPressTime!).inMilliseconds < _window.inMilliseconds;
        if (withinWindow) {
          SystemNavigator.pop();
          return;
        }
        setState(() => _lastBackPressTime = now);
        Fluttertoast.showToast(
          msg: 'Press back again to exit',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      },
      child: widget.child,
    );
  }
}
