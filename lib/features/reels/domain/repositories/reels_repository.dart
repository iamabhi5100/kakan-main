import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/reels/domain/entities/reel_entity.dart';
import 'package:kakan/features/reels/domain/entities/share_target_entity.dart';

abstract class ReelsRepository {
  Future<Either<Failure, Map<String, dynamic>>> getReels({String? nextUrl});
  Future<Either<Failure, void>> likeReel({required String reelId, required bool like});
  Future<Either<Failure, void>> repostReel({
    required String reelId,
    required String mediaType,
    required String title,
    required String caption,
  });
  Future<Either<Failure, void>> deleteReel(String reelId);
  Future<Either<Failure, List<ShareTargetEntity>>> getShareTargets();
  Future<Either<Failure, void>> shareReel(String reelId, String chatId, String type);
}