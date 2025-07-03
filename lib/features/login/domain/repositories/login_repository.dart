import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import '../entities/login_entity.dart';

abstract class LoginRepository {
  Future<Either<Failure, LoginEntity>> login(String username, String password);
  Future<Either<Failure, String>> requestOtp(String mobile);
  Future<Either<Failure, String>> verifyOtp(String mobile, String otp); // Add this
}

