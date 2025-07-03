// lib/features/followsuggestions/domain/usecases/get_follow_suggestions.dart
import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/followsuggestions/data/models/suggestion_model.dart';
import 'package:kakan/features/followsuggestions/domain/repositories/suggestion_repository.dart';

class GetFollowSuggestions {
  final SuggestionRepository repository;

  GetFollowSuggestions(this.repository);

  Future<Either<Failure, List<SuggestionModel>>> call() async {
    return await repository.getFollowSuggestions();
  }
}