import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/reels/domain/repositories/reels_repository.dart';

class RepostReel implements UseCase<void, RepostParams> {
  final ReelsRepository repository;

  RepostReel(this.repository);

  @override
  Future<Either<Failure, void>> call(RepostParams params) async {
    return await repository.repostReel(
      reelId: params.reelId,
      mediaType: params.mediaType,
      title: params.title,
      caption: params.caption,
    );
  }
}

class RepostParams extends Equatable {
  final String reelId;
  final String mediaType;
  final String title;
  final String caption;

  const RepostParams({
    required this.reelId,
    required this.mediaType,
    required this.title,
    required this.caption,
  });

  @override
  List<Object> get props => [reelId, mediaType, title, caption];
}