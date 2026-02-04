import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/youtube/model/youtube_home_model.dart';
import 'package:kakan/features/youtube/domain/repositories/youtube_repository.dart';

/// Use case for searching YouTube videos.
class SearchVideos implements UseCase<List<Content>, String> {
  final YoutubeRepository repository;

  SearchVideos(this.repository);

  @override
  Future<Either<Failure, List<Content>>> call(String query) async {
    return await repository.searchVideos(query);
  }
}