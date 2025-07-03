import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import '../entities/search_result.dart';
import '../repositories/search_repository.dart';

class SearchPeople {
  final SearchRepository repository;

  SearchPeople(this.repository);

  Future<Either<Failure, List<SearchResult>>> call(String query) async {
    return await repository.searchPeople(query);
  }
}