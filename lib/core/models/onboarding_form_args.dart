// lib/core/models/onboarding_form_args.dart
import 'package:kakan/features/login/data/datasources/remote_data_source.dart';

class OnboardingFormArgs {
  final String token;
  final RemoteDataSource remoteDataSource;

  OnboardingFormArgs({
    required this.token,
    required this.remoteDataSource,
  });
}