// lib/features/followsuggestions/domain/repositories/suggestion_repository.dart
import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/followsuggestions/data/models/suggestion_model.dart';

abstract class SuggestionRepository {
  Future<Either<Failure, List<SuggestionModel>>> getFollowSuggestions();
  Future<Either<Failure, String>> followUser(String userId);
  Future<Either<Failure, String>> unfollowUser(String userId);
}