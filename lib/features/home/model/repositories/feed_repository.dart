import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/home/model/entities/feed_entity.dart';

abstract class FeedRepository {
  /// Reels-style contract
  Future<Either<Failure, Map<String, dynamic>>> getFeeds({String? nextUrl});

  Future<Either<Failure, void>> likeDislikePost(String postId);
  Future<Either<Failure, String>> repost({
    required String postId,
    required String title,
    required String caption,
  });
  Future<Either<Failure, void>> deleteFeed(String feedId);
  Future<Either<Failure, void>> addComment(String postId, String content);
  Future<Either<Failure, List<CommentEntity>>> getComments(String postId);
  Future<Either<Failure, void>> deleteComment(String commentId);
}
