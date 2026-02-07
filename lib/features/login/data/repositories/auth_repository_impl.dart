import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/login/data/datasources/remote_data_source.dart';
import 'package:kakan/features/login/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final RemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, String>> requestOtp(String mobile) async {
    try {
      final result = await remoteDataSource.requestOtp(mobile);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(exception: e));
    }
  }

  @override
  Future<Either<Failure, VerifyOtpResponseWrapper>> verifyOtp(String otp, String otpToken) async {
    try {
      final response = await remoteDataSource.verifyOtp(otp, otpToken);
      return Right(response);
    } on ServerException catch (e) {
      return Left(ServerFailure(exception: e));
    }
  }

  @override
  Future<Either<Failure, String>> createProfile(String token, Map<String, dynamic> profileData) async {
    try {
      final result = await remoteDataSource.createProfile(token, profileData);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(exception: e));
    }
  }
}