import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/home/model/repositories/feed_repository.dart';

class DeleteCommentParams {
  final String commentId;

  DeleteCommentParams({required this.commentId});
}

class DeleteComment {
  final FeedRepository repository;

  DeleteComment(this.repository);

  Future<Either<Failure, void>> call(DeleteCommentParams params) async {
    return await repository.deleteComment(params.commentId);
  }
}