import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/login/data/datasources/remote_data_source.dart';
import 'package:kakan/features/login/domain/entities/login_entity.dart';
import 'package:kakan/features/login/domain/repositories/login_repository.dart';

/// Implementation of the [LoginRepository] for handling login-related operations.
class LoginRepositoryImpl implements LoginRepository {
  final RemoteDataSource remoteDataSource;

  LoginRepositoryImpl({
    required this.remoteDataSource,
  });

  @override
  Future<Either<Failure, LoginEntity>> login(String username, String password) async {
    return Left(ServerFailure(exception: ServerException(message: 'Username/password login not supported')));
  }

  @override
  Future<Either<Failure, String>> requestOtp(String mobile) async {
    try {
      final message = await remoteDataSource.requestOtp(mobile);
      print('OTP Request Successful: $message');
      return Right(message);
    } on ServerException catch (e) {
      print('ServerException in Repository: $e');
      return Left(ServerFailure(exception: e));
    } catch (e) {
      print('Unexpected error in Repository: $e');
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, VerifyOtpResponseWrapper>> verifyOtp(String otp, String otpToken) async {
    try {
      final response = await remoteDataSource.verifyOtp(otp, otpToken);
      print('OTP Verification Successful: token=${response.token}, hasProfile=${response.hasProfile}');
      return Right(response);
    } on ServerException catch (e) {
      print('ServerException in Verify OTP: $e');
      return Left(ServerFailure(exception: e));
    } catch (e) {
      print('Unexpected error in Verify OTP: $e');
      return Left(ServerFailure());
    }
  }
}

abstract class LoginRepository {
  Future<Either<Failure, LoginEntity>> login(String username, String password);
  Future<Either<Failure, String>> requestOtp(String mobile);
  Future<Either<Failure, VerifyOtpResponseWrapper>> verifyOtp(String otp, String otpToken);
}