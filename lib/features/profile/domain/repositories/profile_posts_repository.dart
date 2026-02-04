import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/profile/domain/entities/profile_post_entity.dart';

abstract class ProfilePostsRepository {
  // <-- MODIFIED: Update the method to accept both userId and mediaType
  Future<Either<Failure, List<ProfilePostEntity>>> getProfilePosts(String userId, String mediaType);
}