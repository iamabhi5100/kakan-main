// lib/features/followsuggestions/domain/usecases/follow_user.dart
import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/followsuggestions/domain/repositories/suggestion_repository.dart';

class FollowUser implements UseCase<String, String> {
  final SuggestionRepository repository;

  FollowUser(this.repository);

  @override
  Future<Either<Failure, String>> call(String userId) async {
    return await repository.followUser(userId);
  }
}