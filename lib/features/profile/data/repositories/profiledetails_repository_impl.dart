import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/network/network_info.dart';
import 'package:kakan/features/profile/data/datasources/profiledetails_remote_data_source.dart';
import 'package:kakan/features/profile/data/models/profiledetails_model.dart';
import 'package:kakan/features/profile/domain/entities/profiledetails_entity.dart';
import 'package:kakan/features/profile/domain/repositories/profiledetails_repository.dart';

class ProfiledetailsRepositoryImpl implements ProfiledetailsRepository {
  final ProfiledetailsRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  ProfiledetailsRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, ProfiledetailsEntity>> getProfiledetails(String userId) async {
    if (await networkInfo.isConnected) {
      try {
        final profileDetails = await remoteDataSource.getProfiledetails(userId);
        return Right(profileDetails);
      } on ServerException catch (e) {
        return Left(ServerFailure(exception: e));
      }
    } else {
      return Left(ServerFailure(exception: ServerException(message: 'No internet connection')));
    }
  }
}