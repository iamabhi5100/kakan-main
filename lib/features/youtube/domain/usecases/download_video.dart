import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/youtube/domain/repositories/youtube_repository.dart';

class DownloadVideoParams {
  final String videoId;
  final String title;
  final bool isAudioOnly;
  final String? preferredQuality; // <- keep this
  final Function(double)? progressCallback;

  DownloadVideoParams({
    required this.videoId,
    required this.title,
    this.isAudioOnly = false,
    this.preferredQuality,
    this.progressCallback,
  });
}

class DownloadVideo implements UseCase<String, DownloadVideoParams> {
  final YoutubeRepository repository;

  DownloadVideo(this.repository);

  @override
  Future<Either<Failure, String>> call(DownloadVideoParams params) async {
    return await repository.downloadVideo(
      params.videoId,
      params.title,
      isAudioOnly: params.isAudioOnly,
      progressCallback: params.progressCallback,
      preferredQuality: params.preferredQuality, // <- pass it here
    );
  }
}
