import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/myfiles/domain/entities/download_entity.dart';
import 'package:kakan/features/myfiles/domain/repositories/downloads_repository.dart';

class GetDownloads implements UseCase<List<DownloadEntity>, String> {
  final DownloadsRepository repository;

  GetDownloads(this.repository);

  @override
  Future<Either<Failure, List<DownloadEntity>>> call(String mediaType) async {
    return await repository.getDownloads(mediaType);
  }
}