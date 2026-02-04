import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:kakan/core/error/app_error.dart';
import 'package:kakan/core/widgets/error_screen.dart';

/// Shows a full-screen "No Internet" error whenever the device is offline.
/// Put this high in the tree (e.g., MaterialApp.builder) to cover all pages.
class NetworkGate extends StatelessWidget {
  final Widget child;

  const NetworkGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Use dynamic so it compiles with both old and v6+ connectivity_plus
    return StreamBuilder<dynamic>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snap) {
        final data = snap.data;
        bool connected = true; // optimistic until first value arrives

        if (data is List<ConnectivityResult>) {
          // v6+: list of transports
          connected = data.any((r) => r != ConnectivityResult.none);
        } else if (data is ConnectivityResult) {
          // older versions: single result
          connected = data != ConnectivityResult.none;
        }

        if (snap.hasData && !connected) {
          return ErrorScreen(
            type: AppErrorType.noInternet,
            onRetry: () {
              // No-op: when connectivity returns, stream rebuilds automatically.
            },
          );
        }

        return child;
      },
    );
  }
}
