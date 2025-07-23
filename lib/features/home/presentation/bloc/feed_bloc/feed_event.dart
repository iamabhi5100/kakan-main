import 'package:kakan/features/home/model/entities/feed_entity.dart';

abstract class FeedEvent {}

class GetFeedEvent extends FeedEvent {}

class LikeDislikePostEvent extends FeedEvent {
  final String postId;
  LikeDislikePostEvent({required this.postId});
}

class RepostEvent extends FeedEvent {
  final String postId;
  final String title;
  final String caption;
  RepostEvent({
    required this.postId,
    required this.title,
    required this.caption,
  });
}

class DeleteFeedEvent extends FeedEvent {
  final String feedId;
  DeleteFeedEvent({required this.feedId});
}