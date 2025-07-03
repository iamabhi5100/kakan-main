import 'package:chucker_flutter/chucker_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kakan/config/chucker_config.dart';
import 'package:kakan/config/router.dart';
import 'package:kakan/features/login/presentation/bloc/otp_bloc.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_bloc.dart';
import 'package:kakan/injection_container.dart' as di;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure RootIsolateToken is available
  await Future.delayed(const Duration(milliseconds: 100));
  final rootIsolateToken = RootIsolateToken.instance;
  if (rootIsolateToken == null) {
    print('ERROR: RootIsolateToken is null in main isolate');
  } else {
    print('DEBUG: RootIsolateToken initialized in main isolate');
  }

  // Load .env file
  try {
    await dotenv.load(fileName: '.env');
    print('DEBUG: Loaded .env file, YOUTUBE_API_KEY: ${dotenv.env['YOUTUBE_API_KEY']}');
  } catch (e) {
    print('ERROR: Failed to load .env file: $e');
  }

  // Initialize GetIt dependencies
  try {
    di.init();
    print('DEBUG: GetIt initialization completed');
  } catch (e) {
    print('ERROR: Failed to initialize GetIt: $e');
  }

  // Configure Chucker Flutter
  if (ChuckerConfig.isEnabled) {
    ChuckerFlutter.showOnRelease = false;
    ChuckerFlutter.showNotification = true;
    print('DEBUG: ChuckerFlutter initialized');
  } else {
    print('DEBUG: ChuckerFlutter disabled');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) {
          final bloc = di.sl<DownloadsBloc>();
          print('DEBUG: Created DownloadsBloc in MyApp: $bloc');
          return bloc;
        }),
        BlocProvider(create: (_) {
          final bloc = di.sl<OtpBloc>();
          print('DEBUG: Created OtpBloc in MyApp: $bloc');
          return bloc;
        }),
      ],
      child: MaterialApp.router(
        title: 'Kakan',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}