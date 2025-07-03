import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
// import '../../core/error/failures.dart';
import '../../domain/entities/search_result.dart';
import '../../domain/repositories/search_repository.dart';
import '../datasources/search_remote_datasource.dart';

class SearchRepositoryImpl implements SearchRepository {
  final SearchRemoteDataSource remoteDataSource;

  SearchRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, List<SearchResult>>> searchPeople(String query) async {
    try {
      final remoteResults = await remoteDataSource.searchPeople(query);
      return Right(remoteResults);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, List<SearchResult>>> searchSongs(String query) async {
    try {
      final remoteResults = await remoteDataSource.searchSongs(query);
      return Right(remoteResults);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, List<SearchResult>>> searchVideos(String query) async {
    try {
      final remoteResults = await remoteDataSource.searchVideos(query);
      return Right(remoteResults);
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}