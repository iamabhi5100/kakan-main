import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/network/network_info.dart';
import 'package:kakan/features/myfiles/data/datasources/delete_download_remote_data_source.dart';
import 'package:kakan/features/myfiles/domain/repositories/delete_download_repository.dart';

class DeleteDownloadRepositoryImpl implements DeleteDownloadRepository {
  final DeleteDownloadRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  DeleteDownloadRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, void>> deleteDownload(String mediaId) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.deleteDownload(mediaId);
        return const Right(null);
      } on ServerException catch (e) {
        return Left(ServerFailure(exception: e));
      }
    } else {
      return Left(ServerFailure(exception: ServerException(message: 'No internet connection')));
    }
  }
}