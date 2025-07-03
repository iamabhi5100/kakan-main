import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/profile/domain/entities/profile_post_entity.dart';
import 'package:kakan/features/profile/domain/repositories/profile_posts_repository.dart';

class GetProfilePosts implements UseCase<List<ProfilePostEntity>, String> {
  final ProfilePostsRepository repository;

  GetProfilePosts(this.repository);

  @override
  Future<Either<Failure, List<ProfilePostEntity>>> call(String mediaType) async {
    return await repository.getProfilePosts(mediaType);
  }
}