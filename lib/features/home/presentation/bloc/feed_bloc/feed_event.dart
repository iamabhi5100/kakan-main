import 'package:equatable/equatable.dart';

abstract class FeedEvent extends Equatable {
  const FeedEvent();
  @override
  List<Object?> get props => [];
}

/// Pagination & refresh (Reels-style)
class FetchFeedsEvent extends FeedEvent {
  const FetchFeedsEvent();
}

class FetchMoreFeedsEvent extends FeedEvent {
  const FetchMoreFeedsEvent();
}

class RefreshFeedsEvent extends FeedEvent {
  const RefreshFeedsEvent();
}

/// Actions
class LikeDislikePostEvent extends FeedEvent {
  final String postId;
  const LikeDislikePostEvent({required this.postId});
  @override
  List<Object?> get props => [postId];
}

class RepostEvent extends FeedEvent {
  final String postId;
  final String title;
  final String caption;
  const RepostEvent({
    required this.postId,
    required this.title,
    required this.caption,
  });
  @override
  List<Object?> get props => [postId, title, caption];
}

class DeleteFeedEvent extends FeedEvent {
  final String feedId;
  const DeleteFeedEvent({required this.feedId});
  @override
  List<Object?> get props => [feedId];
}

class AddCommentEvent extends FeedEvent {
  final String postId;
  final String content;
  const AddCommentEvent({required this.postId, required this.content});
  @override
  List<Object?> get props => [postId, content];
}

class GetCommentsEvent extends FeedEvent {
  final String postId;
  const GetCommentsEvent({required this.postId});
  @override
  List<Object?> get props => [postId];
}

class DeleteCommentEvent extends FeedEvent {
  final String commentId;
  final String postId;
  const DeleteCommentEvent({required this.commentId, required this.postId});
  @override
  List<Object?> get props => [commentId, postId];
}
