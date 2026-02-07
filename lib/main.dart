import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:go_router/go_router.dart';
import 'package:kakan/config/router.dart';
import 'package:kakan/injection_container.dart' as di;

// Blocs you were providing at the root
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_bloc.dart';
import 'package:kakan/features/login/presentation/bloc/otp_bloc.dart';

// ⬇️ ADD THIS IMPORT
import 'package:kakan/core/widgets/network_gate.dart';

/// Converts an incoming deep link URI to a go_router route.
/// Handles: /post/:id, /reel/:id, and API path /v1/posts/user-posts/:id/
String? _deepLinkUriToRoute(Uri uri) {
  final path = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
  if (path.startsWith('/post/') || path.startsWith('/reel/')) {
    return path.split('?').first;
  }
  // API URL: /v1/posts/user-posts/{postId}/ -> /post/{postId}
  final postMatch = RegExp(r'^/v1/posts/user-posts/([^/]+)').firstMatch(path);
  if (postMatch != null) {
    return '/post/${postMatch.group(1)}';
  }
  return null;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load env (non-fatal if missing)
  try {
    await dotenv.load(fileName: '.env');
    final hasKey = dotenv.env['YOUTUBE_API_KEY']?.isNotEmpty == true;
    // Keep logs minimal in release
    // ignore: avoid_print
    print('DEBUG: .env loaded (YouTube key present: $hasKey)');
  } catch (e) {
    // ignore: avoid_print
    print('ERROR: Failed to load .env file: $e');
  }

  // DI
  try {
    di.init();
    // ignore: avoid_print
    print('DEBUG: GetIt initialization completed');
  } catch (e) {
    // ignore: avoid_print
    print('ERROR: Failed to initialize GetIt: $e');
  }

  // Deep link: when app is opened from a shared post/reel link, start at that route
  String initialLocation = '/splash';
  try {
    final appLinks = AppLinks();
    final uri = await appLinks.getInitialLink();
    if (uri != null && uri.path.isNotEmpty) {
      final route = _deepLinkUriToRoute(uri);
      if (route != null) {
        initialLocation = route;
        // ignore: avoid_print
        print('DEBUG: Deep link initial location: $initialLocation');
      }
    }
  } catch (e) {
    // ignore: avoid_print
    print('DEBUG: No initial app link or error: $e');
  }

  final goRouter = createAppRouter(initialLocation: initialLocation);
  runApp(MyApp(router: goRouter));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => di.sl<DownloadsBloc>()),
        BlocProvider(create: (_) => di.sl<OtpBloc>()),
      ],
      child: MaterialApp.router(
        title: 'Kakan',
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue).copyWith(
            background: Colors.white,
            surface: Colors.white,
          ),
          scaffoldBackgroundColor: Colors.white,
        ),
        // ⬇️ Wrap the whole UI with NetworkGate + deep link listener (when app already open)
        builder: (context, child) => ColoredBox(
          color: Colors.white,
          child: _AppLinkListener(
            router: router,
            child: NetworkGate(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Listens for incoming app links when the app is already open and navigates.
class _AppLinkListener extends StatefulWidget {
  const _AppLinkListener({required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  State<_AppLinkListener> createState() => _AppLinkListenerState();
}

class _AppLinkListenerState extends State<_AppLinkListener> {
  @override
  void initState() {
    super.initState();
    _subscribeToLinks();
  }

  void _subscribeToLinks() {
    final appLinks = AppLinks();
    appLinks.uriLinkStream.listen((Uri uri) {
      final route = _deepLinkUriToRoute(uri);
      if (route != null) {
        widget.router.go(route);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
