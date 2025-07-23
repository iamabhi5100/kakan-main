import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/home/data/models/share_models.dart';
import 'package:kakan/features/home/model/repositories/share_repository.dart';

class GetUsersToShare implements UseCase<List<ShareItem>, NoParams> {
  final ShareRepository repository;

  GetUsersToShare(this.repository);

  @override
  Future<Either<Failure, List<ShareItem>>> call(NoParams params) async {
    return await repository.getUsersToShare();
  }
}