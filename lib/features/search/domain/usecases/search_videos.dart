import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
// import '../../core/error/failures.dart';
import '../entities/search_result.dart';
import '../repositories/search_repository.dart';

class SearchVideos {
  final SearchRepository repository;

  SearchVideos(this.repository);

  Future<Either<Failure, List<SearchResult>>> call(String query) async {
    return await repository.searchVideos(query);
  }
}