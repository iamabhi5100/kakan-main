import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/profile/domain/entities/profile_post_entity.dart';
import 'package:kakan/features/profile/domain/repositories/profile_posts_repository.dart';

class GetProfilePostsParams {
  final String mediaType;
  final String userId;
  GetProfilePostsParams({required this.mediaType, required this.userId});
}

class GetProfilePosts implements UseCase<List<ProfilePostEntity>, GetProfilePostsParams> {
  final ProfilePostsRepository repository;

  GetProfilePosts(this.repository);

  @override
  Future<Either<Failure, List<ProfilePostEntity>>> call(GetProfilePostsParams params) async {
    return await repository.getProfilePosts(params.userId, params.mediaType);
  }
}