// lib/features/login/domain/usecases/verify_otp.dart
import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/network/models/verify_otp_response.dart';
import 'package:kakan/core/utils/session_manager.dart';
import 'package:kakan/features/login/data/datasources/remote_data_source.dart';
import 'package:kakan/features/login/domain/repositories/auth_repository.dart';
import 'package:kakan/injection_container.dart';

class VerifyOtpParams {
  final String otp;
  final String otpToken;

  VerifyOtpParams({required this.otp, required this.otpToken});
}

class VerifyOtp {
  final AuthRepository repository;

  VerifyOtp(this.repository);

  Future<Either<Failure, VerifyOtpResponseWrapper>> call(VerifyOtpParams params) async {
    final result = await repository.verifyOtp(params.otp, params.otpToken);
    return result;
  }
}