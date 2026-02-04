import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:kakan/config/router.dart';
import 'package:kakan/injection_container.dart' as di;

// Blocs you were providing at the root
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_bloc.dart';
import 'package:kakan/features/login/presentation/bloc/otp_bloc.dart';

// ⬇️ ADD THIS IMPORT
import 'package:kakan/core/widgets/network_gate.dart';

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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
        // ⬇️ Wrap the whole UI with NetworkGate so offline shows a full-screen
        builder: (context, child) => ColoredBox(
          color: Colors.white,
          child: NetworkGate(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
