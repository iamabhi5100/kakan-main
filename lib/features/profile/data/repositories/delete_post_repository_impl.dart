import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/network/network_info.dart';
import 'package:kakan/features/profile/data/datasources/delete_post_remote_data_source.dart';
import 'package:kakan/features/profile/domain/repositories/delete_post_repository.dart';
// import 'package:kakan/features/postmyfeed/data/datasources/delete_post_remote_data_source.dart';
// import 'package:kakan/features/postmyfeed/domain/repositories/delete_post_repository.dart';

class DeletePostRepositoryImpl implements DeletePostRepository {
  final DeletePostRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  DeletePostRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, void>> deletePost(String postId) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.deletePost(postId);
        return const Right(null);
      } on ServerException catch (e) {
        return Left(ServerFailure(exception: e));
      }
    } else {
      return Left(ServerFailure(exception: ServerException(message: 'No internet connection')));
    }
  }
}