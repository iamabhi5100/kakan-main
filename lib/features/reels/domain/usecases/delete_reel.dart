import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/reels/domain/repositories/reels_repository.dart';

class DeleteReel implements UseCase<void, DeleteReelParams> {
  final ReelsRepository repository;

  DeleteReel(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteReelParams params) async {
    return await repository.deleteReel(params.reelId);
  }
}

class DeleteReelParams extends Equatable {
  final String reelId;

  const DeleteReelParams({required this.reelId});

  @override
  List<Object> get props => [reelId];
}