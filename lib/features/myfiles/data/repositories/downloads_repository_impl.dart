import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/network/network_info.dart';
import 'package:kakan/features/myfiles/data/datasources/downloads_remote_data_source.dart';
import 'package:kakan/features/myfiles/domain/entities/download_entity.dart';
import 'package:kakan/features/myfiles/domain/repositories/downloads_repository.dart';

class DownloadsRepositoryImpl implements DownloadsRepository {
  final DownloadsRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  DownloadsRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<DownloadEntity>>> getDownloads(String mediaType, {String? search}) async {
    if (await networkInfo.isConnected) {
      try {
        final downloads = await remoteDataSource.getDownloads(mediaType, search: search);
        return Right(downloads);
      } on ServerException catch (e) {
        return Left(ServerFailure(exception: e));
      }
    } else {
      return Left(ServerFailure(exception: ServerException(message: 'No internet connection')));
    }
  }
}
