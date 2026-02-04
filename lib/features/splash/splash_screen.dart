import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kakan/core/utils/session_manager.dart';
import 'package:kakan/injection_container.dart' as di;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _session = di.sl<SessionManager>();

  @override
  void initState() {
    super.initState();
    // Let a first frame render, then run async logic to avoid any blank frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _decideRoute());
  }

  Future<void> _decideRoute() async {
    try {
      final token = await _session.getAccessToken();
      if (!mounted) return;
      if (token != null && token.isNotEmpty) {
        context.go('/home');
      } else {
        context.go('/login');
      }
    } catch (_) {
      if (!mounted) return;
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Paint something (white background + logo/spinner) immediately.
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          width: 72,
          height: 72,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }
}
