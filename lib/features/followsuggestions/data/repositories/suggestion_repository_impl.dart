// lib/features/followsuggestions/data/repositories/suggestion_repository_impl.dart
import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/followsuggestions/data/datasources/suggestion_remote_data_source.dart' as follow_suggestions;
import 'package:kakan/features/followsuggestions/data/models/suggestion_model.dart';
import 'package:kakan/features/followsuggestions/domain/repositories/suggestion_repository.dart';

class SuggestionRepositoryImpl implements SuggestionRepository {
  final follow_suggestions.RemoteDataSource remoteDataSource;

  SuggestionRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<SuggestionModel>>> getFollowSuggestions() async {
    try {
      final suggestions = await remoteDataSource.getFollowSuggestions();
      return Right(suggestions);
    } on ServerException catch (e) {
      return Left(ServerFailure(exception: e));
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, String>> followUser(String userId) async {
    try {
      final message = await remoteDataSource.followUser(userId);
      return Right(message);
    } on ServerException catch (e) {
      return Left(ServerFailure(exception: e));
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, String>> unfollowUser(String userId) async {
    try {
      final message = await remoteDataSource.unfollowUser(userId);
      return Right(message);
    } on ServerException catch (e) {
      return Left(ServerFailure(exception: e));
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}
