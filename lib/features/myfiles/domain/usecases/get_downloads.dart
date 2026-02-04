import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/myfiles/domain/entities/download_entity.dart';
import 'package:kakan/features/myfiles/domain/repositories/downloads_repository.dart';

class GetDownloads implements UseCase<List<DownloadEntity>, GetDownloadsParams> {
  final DownloadsRepository repository;

  GetDownloads(this.repository);

  @override
  Future<Either<Failure, List<DownloadEntity>>> call(GetDownloadsParams params) async {
    return await repository.getDownloads(params.mediaType, search: params.search);
  }
}

class GetDownloadsParams {
  final String mediaType;
  final String? search;

  GetDownloadsParams({required this.mediaType, this.search});
}
