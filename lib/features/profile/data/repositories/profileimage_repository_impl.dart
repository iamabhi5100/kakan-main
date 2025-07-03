import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/network/network_info.dart';
import 'package:kakan/features/profile/data/datasources/profileimage_remote_data_source.dart';
import 'package:kakan/features/profile/data/models/profileimage_model.dart';
import 'package:kakan/features/profile/domain/entities/profileimage_entity.dart';
import 'package:kakan/features/profile/domain/repositories/profileimage_repository.dart';

class ProfileimageRepositoryImpl implements ProfileimageRepository {
  final ProfileimageRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  ProfileimageRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, ProfileimageEntity>> uploadProfileimage(
    String userId,
    String imagePath,
  ) async {
    if (await networkInfo.isConnected) {
      try {
        final profileimageModel = await remoteDataSource.uploadProfileimage(userId, imagePath);
        return Right(profileimageModel);
      } on ServerException catch (e) {
        return Left(ServerFailure(exception: e));
      }
    } else {
      return Left(ServerFailure(exception: ServerException(message: 'No internet connection')));
    }
  }
}