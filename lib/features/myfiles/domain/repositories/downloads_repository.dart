import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/myfiles/domain/entities/download_entity.dart';

abstract class DownloadsRepository {
  Future<Either<Failure, List<DownloadEntity>>> getDownloads(String mediaType);
}