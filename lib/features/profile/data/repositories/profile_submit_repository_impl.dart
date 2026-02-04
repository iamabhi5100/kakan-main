import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/network/network_info.dart';
import 'package:kakan/features/profile/data/datasources/profile_submit_remote_data_source.dart';
import 'package:kakan/features/profile/data/models/profiledetails_model.dart';
import 'package:kakan/features/profile/domain/entities/profiledetails_entity.dart';
import 'package:kakan/features/profile/domain/repositories/profile_submit_repository.dart';

class ProfileSubmitRepositoryImpl implements ProfileSubmitRepository {
  final ProfileSubmitRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  ProfileSubmitRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, ProfiledetailsEntity>> submitProfile(String userId, Map<String, dynamic> data) async {
    if (await networkInfo.isConnected) {
      try {
        final profileDetails = await remoteDataSource.submitProfile(userId, data);
        return Right(profileDetails);
      } on ServerException catch (e) {
        return Left(ServerFailure(exception: e));
      }
    } else {
      return Left(ServerFailure(exception: ServerException(message: 'No internet connection')));
    }
  }
}