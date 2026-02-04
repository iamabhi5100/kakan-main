import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kakan/core/models/otp_page_args.dart';
import 'package:kakan/features/login/data/datasources/remote_data_source.dart';
import 'package:kakan/features/login/presentation/bloc/otp_bloc.dart';
import 'package:kakan/features/login/presentation/bloc/otp_state.dart';
import 'package:kakan/features/login/presentation/widgets/login_form.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:fluttertoast/fluttertoast.dart';

// ⬇️ ADD THIS IMPORT
import 'package:kakan/core/widgets/error_screen.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  // Static flag to prevent multiple toast triggers
  static bool _hasShownLogoutToast = false;

  @override
  Widget build(BuildContext context) {
    print('LoginPage: build called');
    // Check for logout success flag
    final routeState = GoRouterState.of(context);
    final extra = routeState.extra as Map<String, dynamic>?;
    if (extra != null && extra['showLogoutSuccess'] == true && !_hasShownLogoutToast) {
      _hasShownLogoutToast = true; // Prevent re-triggering
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Fluttertoast.showToast(
          msg: 'Logged out successfully',
          toastLength: Toast.LENGTH_SHORT,
          timeInSecForIosWeb: 1,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      });
    } else {
      _hasShownLogoutToast = false; // Reset flag if no logout success
    }

    return BlocProvider(
      create: (_) => di.sl<OtpBloc>(),
      child: Scaffold(
        body: BlocListener<OtpBloc, OtpState>(
          listener: (context, state) {
            print('LoginPage: BlocListener state: $state');
            if (state is OtpSuccess) {
              print('Navigating to OTPPage with phone: ${state.phone}');
              try {
                context.go(
                  '/otp',
                  extra: OTPPageArgs(
                    phone: state.phone ?? '',
                    remoteDataSource: di.sl<RemoteDataSource>(),
                  ),
                );
                print('Navigation successful');
              } catch (e) {
                print('Navigation error: $e');
              }
            } else if (state is OtpFailure) {
              // ⬇️ Show the full-screen error instead of a snackbar
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ErrorScreen(
                  type: state.type,
                  onRetry: () {
                    Navigator.of(context).pop(); // Close error screen
                    // User can tap "Get OTP" again.
                  },
                ),
              ));
            }
          },
          child: const LoginForm(),
        ),
      ),
    );
  }
}
