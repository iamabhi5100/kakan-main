import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/myfiles/domain/repositories/delete_download_repository.dart';

class DeleteDownload implements UseCase<void, String> {
  final DeleteDownloadRepository repository;

  DeleteDownload(this.repository);

  @override
  Future<Either<Failure, void>> call(String mediaId) async {
    return await repository.deleteDownload(mediaId);
  }
}