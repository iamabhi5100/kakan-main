// lib/features/login/presentation/pages/otp_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kakan/core/models/onboarding_form_args.dart';
import 'package:kakan/core/utils/session_manager.dart';
import 'package:kakan/features/login/data/datasources/remote_data_source.dart';
import 'package:kakan/features/login/presentation/bloc/otp_bloc.dart';
import 'package:kakan/features/login/presentation/bloc/otp_state.dart';
import 'package:kakan/features/login/presentation/widgets/otp_form.dart';
import 'package:kakan/injection_container.dart' as di;

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
    return BlocProvider(
      create: (_) => di.sl<OtpBloc>(),
      child: Scaffold(
        // appBar: AppBar(
        //   title: const Text('Enter OTP'),
        // ),
        body:// lib/features/login/presentation/pages/otp_page.dart
// lib/features/login/presentation/pages/otp_page.dart
BlocListener<OtpBloc, OtpState>(
  listener: (context, state) {
    print('OTPPage BlocListener state: $state');
    if (state is OtpVerified) {
      print('Attempting navigation from OTPPage, userId: ${state.userId}');
      Future.microtask(() {
        try {
          di.sl<SessionManager>().saveTokens(
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
          print('Navigation from OTPPage successful');
        } catch (e) {
          print('Navigation error in OTPPage: $e');
        }
      });
    } else if (state is OtpFailure) {
      print('OTP Failure: ${state.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.message)),
      );
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