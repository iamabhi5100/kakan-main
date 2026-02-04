// lib/features/youtube/data/youtube_repository_impl.dart

import 'package:dartz/dartz.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/youtube/data/yt_downloader.dart';
import 'package:kakan/features/youtube/data/youtube_service.dart';
import 'package:kakan/features/youtube/domain/repositories/youtube_repository.dart';
import 'package:kakan/features/youtube/model/youtube_home_model.dart';

class YoutubeRepositoryImpl implements YoutubeRepository {
  final YoutubeService api;
  final DefaultCacheManager cacheManager;

  late final YtDownloader _downloader;

  YoutubeRepositoryImpl({
    required this.api,
    required this.cacheManager,
  }) {
    final rapidKey = (dotenv.env['RAPIDAPI_KEY']?.trim() ?? '');
    if (rapidKey.isEmpty) {
      throw ServerException(message: 'RAPIDAPI_KEY missing');
    }

    _downloader = YtDownloader(
      rapidConfig: buildRapidApiConfigFromEnv(rapidApiKey: rapidKey),
    );
  }

  @override
  Future<Either<Failure, List<Content>>> searchVideos(String query) async {
    try {
      final res = await api.searchVideos(query);
      return Right(res);
    } catch (e, st) {
      print('[YT_REPO] searchVideos error: $e\n$st');
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, List<Content>>> fetchHomeVideos() async {
    try {
      final res = await api.fetchHomeVideos();
      return Right(res.contents);
    } catch (e, st) {
      print('[YT_REPO] fetchHomeVideos error: $e\n$st');
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, String>> downloadVideo(
    String videoId,
    String title, {
    bool isAudioOnly = false,
    Function(double)? progressCallback,
    String? preferredQuality,
  }) async {
    try {
      int last = 0;
      final path = await _downloader.download(
        videoIdOrUrl: videoId,
        audioOnly: isAudioOnly,
        customName: title,
        onProgress: (received, total) {
          if (total > 0 && progressCallback != null) {
            final p = (received / total).clamp(0.0, 1.0);
            final pct = (p * 100).round();
            if (pct - last >= 1) {
              last = pct;
              progressCallback(p);
            }
          }
        },
      );
      return Right(path);
    } catch (e, st) {
      print('[YT_REPO] downloadVideo error: $e\n$st');
      return Left(ServerFailure());
    }
  }
}
