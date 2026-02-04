import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kakan/core/models/onboarding_form_args.dart';
import 'package:kakan/core/utils/session_manager.dart';
import 'package:kakan/features/login/data/datasources/remote_data_source.dart';
import 'package:kakan/features/login/presentation/bloc/otp_bloc.dart';
import 'package:kakan/features/login/presentation/bloc/otp_event.dart';
import 'package:kakan/features/login/presentation/bloc/otp_state.dart';
import 'package:kakan/features/login/presentation/widgets/otp_form.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:jwt_decode/jwt_decode.dart';
import 'package:fluttertoast/fluttertoast.dart';

// ⬇️ ADD THIS IMPORT
import 'package:kakan/core/widgets/error_screen.dart';

class OTPPage extends StatelessWidget {
  final String phone;
  final RemoteDataSource remoteDataSource;

  const OTPPage({
    required this.phone,
    required this.remoteDataSource,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print('OTPPage: build called');
    }
    // Cancel any existing toasts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Fluttertoast.cancel();
    });

    return BlocProvider(
      create: (_) => di.sl<OtpBloc>(),
      child: Scaffold(
        body: BlocListener<OtpBloc, OtpState>(
          listener: (context, state) {
            if (kDebugMode) {
              print('OTPPage: BlocListener state: $state');
            }
            if (state is OtpVerified) {
              if (kDebugMode) {
                print('Attempting navigation from OTPPage, userId: ${state.userId}');
              }
              Future.microtask(() async {
                try {
                  final sessionManager = di.sl<SessionManager>();
                  final payload = Jwt.parseJwt(state.token);
                  final authUserId = payload['user_id'] as String?;
                  if (authUserId != null) {
                    await sessionManager.saveUserId(authUserId);
                  }
                  await sessionManager.saveProfileId(state.userId);
                  await sessionManager.saveTokens(
                    accessToken: state.token,
                    refreshToken: state.hasProfile ? state.token : null,
                  );
                  if (state.hasProfile) {
                    context.go('/home');
                  } else {
                    context.go(
                      '/onboarding-form',
                      extra: OnboardingFormArgs(
                        token: state.token,
                        remoteDataSource: remoteDataSource,
                      ),
                    );
                  }
                  if (kDebugMode) {
                    print('Navigation from OTPPage successful');
                  }
                } catch (e) {
                  if (kDebugMode) {
                    print('Navigation error in OTPPage: $e');
                  }
                  Fluttertoast.showToast(
                    msg: 'Navigation error: $e',
                    toastLength: Toast.LENGTH_LONG,
                    gravity: ToastGravity.TOP,
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                    fontSize: 16.0,
                  );
                }
              });
            } else if (state is OtpFailure) {
              // ⬇️ Show the full-screen error instead of a toast
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ErrorScreen(
                  type: state.type,
                  onRetry: () {
                    Navigator.of(context).pop(); // Close error screen
                    // User can press "Submit" again in the OTP form.
                  },
                ),
              ));
            }
          },
          child: OTPForm(
            phone: phone,
            remoteDataSource: remoteDataSource,
          ),
        ),
      ),
    );
  }
}
