import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/chat/data/models/following_user_model.dart';
import 'package:kakan/features/chat/domain/repositories/chat_repository.dart';

class GetFollowingUsers implements UseCase<FollowingUsersResponse, String> {
  final ChatRepository repository;

  GetFollowingUsers(this.repository);

  @override
  Future<Either<Failure, FollowingUsersResponse>> call(String userId) async {
    return await repository.getFollowingUsers(userId);
  }
}