import 'package:equatable/equatable.dart';
import 'package:kakan/features/home/model/entities/feed_entity.dart';

abstract class FeedState extends Equatable {
  const FeedState();
  @override
  List<Object?> get props => [];
}

class FeedInitial extends FeedState {}

/// Base state that carries the list + pagination info (Reels-style)
abstract class FeedActionState extends FeedState {
  final List<FeedEntity> feeds;
  final bool hasMore;
  final String? nextUrl;
  const FeedActionState(this.feeds, this.hasMore, this.nextUrl);

  @override
  List<Object?> get props => [feeds, hasMore, nextUrl ?? ''];
}

class FeedLoading extends FeedActionState {
  const FeedLoading(super.feeds, super.hasMore, super.nextUrl);
}

class FeedLoaded extends FeedActionState {
  const FeedLoaded(super.feeds, super.hasMore, super.nextUrl);
}

class FeedError extends FeedState {
  final String message;
  const FeedError(this.message);
  @override
  List<Object?> get props => [message];
}

class FeedActionLoading extends FeedState {}

/// Values: "like", "repost", "delete", "comment", "delete_comment"
class FeedActionSuccess extends FeedState {
  final String actionType;
  final String? newPostId;
  const FeedActionSuccess({required this.actionType, this.newPostId});

  @override
  List<Object?> get props => [actionType, newPostId ?? ''];
}

class FeedActionError extends FeedState {
  final String message;
  const FeedActionError(this.message);
  @override
  List<Object?> get props => [message];
}

/// Comments side states
class CommentsLoading extends FeedState {}

class CommentsLoaded extends FeedState {
  final List<CommentEntity> comments;
  const CommentsLoaded(this.comments);
  @override
  List<Object?> get props => [comments];
}

class CommentsError extends FeedState {
  final String message;
  const CommentsError(this.message);
  @override
  List<Object?> get props => [message];
}
