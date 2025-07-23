import 'package:kakan/features/home/model/entities/feed_entity.dart';

abstract class FeedState {}

class FeedInitial extends FeedState {}

class FeedLoading extends FeedState {}

class FeedLoaded extends FeedState {
  final List<FeedEntity> feeds;
  FeedLoaded(this.feeds);
}

class FeedError extends FeedState {
  final String message;
  FeedError(this.message);
}

class FeedActionLoading extends FeedState {}

class FeedActionSuccess extends FeedState {
  final String? newPostId;
  FeedActionSuccess({this.newPostId});
}

class FeedActionError extends FeedState {
  final String message;
  FeedActionError(this.message);
}