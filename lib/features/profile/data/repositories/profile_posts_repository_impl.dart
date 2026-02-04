import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/network/network_info.dart';
import 'package:kakan/features/profile/data/datasources/profile_posts_remote_data_source.dart';
import 'package:kakan/features/profile/domain/entities/profile_post_entity.dart';
import 'package:kakan/features/profile/domain/repositories/profile_posts_repository.dart';

class ProfilePostsRepositoryImpl implements ProfilePostsRepository {
  final ProfilePostsRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  ProfilePostsRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  // <-- MODIFIED: Add the userId parameter to match the abstract class
  Future<Either<Failure, List<ProfilePostEntity>>> getProfilePosts(String userId, String mediaType) async {
    if (await networkInfo.isConnected) {
      try {
        // <-- MODIFIED: Pass both userId and mediaType to the data source
        final posts = await remoteDataSource.getProfilePosts(userId, mediaType);
        return Right(posts);
      } on ServerException catch (e) {
        return Left(ServerFailure(exception: e));
      }
    } else {
      return Left(ServerFailure(exception: ServerException(message: 'No internet connection')));
    }
  }
}