import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/youtube/model/youtube_home_model.dart';

abstract class YoutubeRepository {
  Future<Either<Failure, List<Content>>> searchVideos(String query);

  Future<Either<Failure, List<Content>>> fetchHomeVideos();

  Future<Either<Failure, String>> downloadVideo(
    String videoId,
    String title, {
    bool isAudioOnly = false,
    Function(double)? progressCallback,
    String? preferredQuality, // <- add this line!
  });
}