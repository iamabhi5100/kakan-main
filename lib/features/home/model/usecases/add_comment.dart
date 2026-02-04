import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/home/model/repositories/feed_repository.dart';

class AddCommentParams {
  final String postId;
  final String content;

  AddCommentParams({
    required this.postId,
    required this.content,
  });
}

class AddComment {
  final FeedRepository repository;

  AddComment(this.repository);

  Future<Either<Failure, void>> call(AddCommentParams params) async {
    return await repository.addComment(params.postId, params.content);
  }
}