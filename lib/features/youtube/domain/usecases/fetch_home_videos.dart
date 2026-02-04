import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/youtube/model/youtube_home_model.dart';
import 'package:kakan/features/youtube/domain/repositories/youtube_repository.dart';

/// Use case for fetching home (trending) YouTube videos.
class FetchHomeVideos implements UseCase<YoutubeHomeResponse, NoParams> {
  final YoutubeRepository repository;

  FetchHomeVideos(this.repository);

  @override
  Future<Either<Failure, YoutubeHomeResponse>> call(NoParams params) async {
    final result = await repository.fetchHomeVideos();
    return result.fold(
      (failure) => Left(failure),
      (contentList) => Right(YoutubeHomeResponse(contents: contentList)),
    );
  }
}