import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import '../../domain/entities/search_result.dart';
// import '../../core/error/failures.dart';

abstract class SearchRepository {
  Future<Either<Failure, List<SearchResult>>> searchPeople(String query);
  Future<Either<Failure, List<SearchResult>>> searchSongs(String query);
  Future<Either<Failure, List<SearchResult>>> searchVideos(String query);
}