import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/reels/domain/repositories/reels_repository.dart';

class LikeReel implements UseCase<void, LikeParams> {
  final ReelsRepository repository;

  LikeReel(this.repository);

  @override
  Future<Either<Failure, void>> call(LikeParams params) async {
    return await repository.likeReel(reelId: params.reelId, like: params.like);
  }
}

class LikeParams extends Equatable {
  final String reelId;
  final bool like;

  const LikeParams({required this.reelId, required this.like});

  @override
  List<Object> get props => [reelId, like];
}