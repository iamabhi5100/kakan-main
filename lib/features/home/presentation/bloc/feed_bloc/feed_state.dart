// lib/features/home/presentation/bloc/feed_state.dart
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