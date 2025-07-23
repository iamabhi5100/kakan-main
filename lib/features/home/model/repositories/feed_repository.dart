import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/home/model/entities/feed_entity.dart';

abstract class FeedRepository {
  Future<Either<Failure, List<FeedEntity>>> getFeeds();
  Future<Either<Failure, void>> likeDislikePost(String postId);
  Future<Either<Failure, String>> repost({
    required String postId,
    required String title,
    required String caption,
  });
  Future<Either<Failure, void>> deleteFeed(String feedId);
}