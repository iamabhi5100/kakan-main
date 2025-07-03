part of 'reels_bloc.dart';

abstract class ReelsState extends Equatable {
  const ReelsState();

  @override
  List<Object> get props => [];
}

class ReelsInitial extends ReelsState {}

class ReelsLoading extends ReelsState {
  final List<ReelEntity> reels;
  final bool hasMore;
  final String? nextUrl;

  const ReelsLoading(this.reels, this.hasMore, this.nextUrl);

  @override
  List<Object> get props => [reels, hasMore, nextUrl ?? ''];
}

class ReelsLoaded extends ReelsState {
  final List<ReelEntity> reels;
  final bool hasMore;
  final String? nextUrl;

  const ReelsLoaded(this.reels, this.hasMore, this.nextUrl);

  @override
  List<Object> get props => [reels, hasMore, nextUrl ?? ''];
}

class ReelsLikeUpdating extends ReelsState {
  final List<ReelEntity> reels;
  final bool hasMore;
  final String? nextUrl;

  const ReelsLikeUpdating(this.reels, this.hasMore, this.nextUrl);

  @override
  List<Object> get props => [reels, hasMore, nextUrl ?? ''];
}

class ReelsRepostUpdating extends ReelsState {
  final List<ReelEntity> reels;
  final bool hasMore;
  final String? nextUrl;

  const ReelsRepostUpdating(this.reels, this.hasMore, this.nextUrl);

  @override
  List<Object> get props => [reels, hasMore, nextUrl ?? ''];
}

class ReelsShareTargetsLoaded extends ReelsState {
  final List<ReelEntity> reels;
  final bool hasMore;
  final String? nextUrl;
  final List<ShareTargetEntity> shareTargets;
  final String reelId;

  const ReelsShareTargetsLoaded({
    required this.reels,
    required this.hasMore,
    required this.nextUrl,
    required this.shareTargets,
    required this.reelId,
  });

  @override
  List<Object> get props => [reels, hasMore, nextUrl ?? '', shareTargets, reelId];
}

class ReelsError extends ReelsState {
  final String message;

  const ReelsError({required this.message});

  @override
  List<Object> get props => [message];
}

class ReelsLikeError extends ReelsState {
  final String message;
  final List<ReelEntity> reels;
  final bool hasMore;
  final String? nextUrl;

  const ReelsLikeError({
    required this.message,
    required this.reels,
    required this.hasMore,
    required this.nextUrl,
  });

  @override
  List<Object> get props => [message, reels, hasMore, nextUrl ?? ''];
}

class ReelsEmpty extends ReelsState {}