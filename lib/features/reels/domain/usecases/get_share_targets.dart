import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/reels/domain/entities/share_target_entity.dart';
import 'package:kakan/features/reels/domain/repositories/reels_repository.dart';

class GetShareTargets implements UseCase<List<ShareTargetEntity>, NoParams> {
  final ReelsRepository repository;

  GetShareTargets(this.repository);

  @override
  Future<Either<Failure, List<ShareTargetEntity>>> call(NoParams params) async {
    return await repository.getShareTargets();
  }
}