import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/network/network_info.dart';
import 'package:kakan/features/reels/data/datasources/reels_remote_data_source.dart';
import 'package:kakan/features/reels/data/models/reel_model.dart' as model;
import 'package:kakan/features/reels/data/models/share_target_model.dart';
import 'package:kakan/features/reels/domain/entities/reel_entity.dart';
import 'package:kakan/features/reels/domain/entities/share_target_entity.dart';
import 'package:kakan/features/reels/domain/repositories/reels_repository.dart';

class ReelsRepositoryImpl implements ReelsRepository {
  final ReelsRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  ReelsRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, Map<String, dynamic>>> getReels({String? nextUrl}) async {
    if (await networkInfo.isConnected) {
      try {
        final response = await remoteDataSource.getReels(nextUrl: nextUrl);
        final reels = response['results'] as List<model.ReelModel>;
        final hasMore = response['next'] != null;
        final newNextUrl = response['next'] as String?;
        print('DEBUG: Repository fetched ${reels.length} reels, hasMore: $hasMore');
        return Right({
          'reels': reels.map((model) => model.toEntity()).toList(),
          'hasMore': hasMore,
          'nextUrl': newNextUrl,
        });
      } catch (e) {
        print('ERROR: Repository failed to fetch reels: $e');
        return Left(ServerFailure());
      }
    } else {
      print('ERROR: No network connection');
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, void>> likeReel({required String reelId, required bool like}) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.likeReel(reelId: reelId, like: like);
        print('DEBUG: Repository like action successful for reel $reelId');
        return const Right(null);
      } catch (e) {
        print('ERROR: Repository like action failed for reel $reelId: $e');
        return Left(ServerFailure());
      }
    } else {
      print('ERROR: No network connection for like action');
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, void>> repostReel({
    required String reelId,
    required String mediaType,
    required String title,
    required String caption,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.repostReel(
          reelId: reelId,
          mediaType: mediaType,
          title: title,
          caption: caption,
        );
        print('DEBUG: Repository repost action successful for reel $reelId');
        return const Right(null);
      } catch (e) {
        print('ERROR: Repository repost action failed for reel $reelId: $e');
        return Left(ServerFailure());
      }
    } else {
      print('ERROR: No network connection for repost action');
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, void>> deleteReel(String reelId) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.deleteReel(reelId);
        print('DEBUG: Repository delete action successful for reel $reelId');
        return const Right(null);
      } catch (e) {
        print('ERROR: Repository delete action failed for reel $reelId: $e');
        return Left(ServerFailure());
      }
    } else {
      print('ERROR: No network connection for delete action');
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, List<ShareTargetEntity>>> getShareTargets() async {
    if (await networkInfo.isConnected) {
      try {
        final targets = await remoteDataSource.getShareTargets();
        print('DEBUG: Repository fetched ${targets.length} share targets');
        return Right(targets.map((model) => model.toEntity()).toList());
      } catch (e) {
        print('ERROR: Repository failed to fetch share targets: $e');
        return Left(ServerFailure());
      }
    } else {
      print('ERROR: No network connection for share targets');
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, void>> shareReel(String reelId, String chatId, String type) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.shareReel(reelId, chatId, type);
        print('DEBUG: Repository share action successful for reel $reelId to chat $chatId (type: $type)');
        return const Right(null);
      } catch (e) {
        print('ERROR: Repository share action failed for reel $reelId: $e');
        return Left(ServerFailure());
      }
    } else {
      print('ERROR: No network connection for share action');
      return Left(ServerFailure());
    }
  }
}