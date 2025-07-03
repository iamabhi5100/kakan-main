// File: lib/features/profile/data/repositories/profile_repository_impl.dart
import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:kakan/features/profile/domain/entities/profile.dart';
import 'package:kakan/features/profile/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;

  ProfileRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, Profile>> updateProfile(String userId, Map<String, dynamic> data) async {
    try {
      final profile = await remoteDataSource.updateProfile(userId, data);
      return Right(profile);
    } on ServerException catch (e) {
      return Left(ServerFailure(exception: e));
    }
  }
}