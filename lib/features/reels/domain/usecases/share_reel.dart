import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/reels/domain/repositories/reels_repository.dart';

class ShareReel implements UseCase<void, ShareReelParams> {
  final ReelsRepository repository;

  ShareReel(this.repository);

  @override
  Future<Either<Failure, void>> call(ShareReelParams params) async {
    return await repository.shareReel(params.reelId, params.chatId, params.type);
  }
}

class ShareReelParams extends Equatable {
  final String reelId;
  final String chatId;
  final String type;

  const ShareReelParams({
    required this.reelId,
    required this.chatId,
    required this.type,
  });

  @override
  List<Object> get props => [reelId, chatId, type];
}