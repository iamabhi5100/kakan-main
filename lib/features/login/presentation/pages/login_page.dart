// lib/features/login/presentation/pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kakan/core/models/otp_page_args.dart';
import 'package:kakan/features/login/data/datasources/remote_data_source.dart';
import 'package:kakan/features/login/presentation/bloc/otp_bloc.dart';
import 'package:kakan/features/login/presentation/bloc/otp_state.dart';
import 'package:kakan/features/login/presentation/widgets/login_form.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:toastification/toastification.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Check for logout success flag
    final routeState = GoRouterState.of(context);
    final extra = routeState.extra as Map<String, dynamic>?;
    if (extra != null && extra['showLogoutSuccess'] == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        toastification.show(
          context: context,
          title: const Text('Logged out successfully'),
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          autoCloseDuration: const Duration(seconds: 3),
        );
      });
    }

    return BlocProvider(
      create: (_) => di.sl<OtpBloc>(),
      child: Scaffold(
        body: BlocListener<OtpBloc, OtpState>(
          listener: (context, state) {
            print('BlocListener state: $state');
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
              print('OTP Failure: ${state.message}');
              toastification.show(
                context: context,
                title: Text(state.message),
                type: ToastificationType.error,
                style: ToastificationStyle.fillColored,
                autoCloseDuration: const Duration(seconds: 3),
              );
            }
          },
          child: const LoginForm(),
        ),
      ),
    );
  }
}