import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';

abstract class DeleteDownloadRepository {
  Future<Either<Failure, void>> deleteDownload(String mediaId);
}