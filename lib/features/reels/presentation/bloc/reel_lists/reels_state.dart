part of 'reels_bloc.dart';

abstract class ReelsState extends Equatable {
  const ReelsState();

  @override
  List<Object> get props => [];
}

class ReelsInitial extends ReelsState {}

// Base state for when reels are loaded or being updated
abstract class ReelsActionState extends ReelsState {
  final List<ReelEntity> reels;
  final bool hasMore;
  final String? nextUrl;

  const ReelsActionState(this.reels, this.hasMore, this.nextUrl);

  @override
  List<Object> get props => [reels, hasMore, nextUrl ?? ''];
}

class ReelsLoading extends ReelsActionState {
  const ReelsLoading(super.reels, super.hasMore, super.nextUrl);
}

class ReelsLoaded extends ReelsActionState {
  const ReelsLoaded(super.reels, super.hasMore, super.nextUrl);
}

class ReelsLikeUpdating extends ReelsActionState {
  const ReelsLikeUpdating(super.reels, super.hasMore, super.nextUrl);
}

class ReelsRepostUpdating extends ReelsActionState {
  const ReelsRepostUpdating(super.reels, super.hasMore, super.nextUrl);
}

class ReelsShareTargetsLoaded extends ReelsActionState {
  final List<ShareTargetEntity> shareTargets;
  final String reelId;

  const ReelsShareTargetsLoaded({
    required List<ReelEntity> reels,
    required bool hasMore,
    required String? nextUrl,
    required this.shareTargets,
    required this.reelId,
  }) : super(reels, hasMore, nextUrl); // FIX: Added super constructor call

  @override
  List<Object> get props => [reels, hasMore, nextUrl ?? '', shareTargets, reelId];
}

class ReelsError extends ReelsState {
  final String message;
  const ReelsError({required this.message});
  @override
  List<Object> get props => [message];
}

class ReelsLikeError extends ReelsActionState {
  final String message;
  const ReelsLikeError({
    required this.message,
    required List<ReelEntity> reels,
    required bool hasMore,
    required String? nextUrl,
  }) : super(reels, hasMore, nextUrl); // FIX: Added super constructor call

  @override
  List<Object> get props => [message, reels, hasMore, nextUrl ?? ''];
}

class ReelsEmpty extends ReelsState {}

// ADDED FOR COMMENTS
class ReelCommentsLoading extends ReelsState {}

class ReelCommentsLoaded extends ReelsState {
  final List<CommentEntity> comments;
  const ReelCommentsLoaded(this.comments);
  @override
  List<Object> get props => [comments];
}

class ReelCommentsError extends ReelsState {
  final String message;
  const ReelCommentsError(this.message);
  @override
  List<Object> get props => [message];
}