import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/home/model/entities/feed_entity.dart';
import 'package:kakan/features/home/model/repositories/feed_repository.dart';

class GetCommentsParams {
  final String postId;

  GetCommentsParams({required this.postId});
}

class GetComments {
  final FeedRepository repository;

  GetComments(this.repository);

  Future<Either<Failure, List<CommentEntity>>> call(GetCommentsParams params) async {
    return await repository.getComments(params.postId);
  }
}