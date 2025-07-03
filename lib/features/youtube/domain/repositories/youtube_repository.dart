import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/youtube/domain/entities/video_entity.dart';

abstract class YoutubeRepository {
  Future<Either<Failure, List<VideoEntity>>> searchVideos(String query);

  Future<Either<Failure, List<VideoEntity>>> fetchHomeVideos();

  Future<Either<Failure, String>> downloadVideo(
    String videoId,
    String title, {
    bool isAudioOnly = false,
    Function(double)? progressCallback,
    String? preferredQuality, // <- add this line!
  });
}
