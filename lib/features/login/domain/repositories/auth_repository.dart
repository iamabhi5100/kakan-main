import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/login/data/datasources/remote_data_source.dart';

abstract class AuthRepository {
  Future<Either<Failure, String>> requestOtp(String mobile);
  Future<Either<Failure, VerifyOtpResponseWrapper>> verifyOtp(String otp, String otpToken);
  Future<Either<Failure, String>> createProfile(String token, Map<String, dynamic> profileData);
}