part of 'reels_bloc.dart';

abstract class ReelsEvent extends Equatable {
  const ReelsEvent();

  @override
  List<Object> get props => [];
}

class FetchReelsEvent extends ReelsEvent {}

class FetchMoreReelsEvent extends ReelsEvent {}

class LikeReelEvent extends ReelsEvent {
  final String reelId;
  final bool like;

  const LikeReelEvent({required this.reelId, required this.like});

  @override
  List<Object> get props => [reelId, like];
}

class RepostReelEvent extends ReelsEvent {
  final String reelId;
  final String mediaType;
  final String title;
  final String caption;

  const RepostReelEvent({
    required this.reelId,
    required this.mediaType,
    required this.title,
    required this.caption,
  });

  @override
  List<Object> get props => [reelId, mediaType, title, caption];
}

class ShareReelEvent extends ReelsEvent {
  final String reelId;

  const ShareReelEvent({required this.reelId});

  @override
  List<Object> get props => [reelId];
}

class ShareReelToChatEvent extends ReelsEvent {
  final String reelId;
  final String chatId;

  const ShareReelToChatEvent({required this.reelId, required this.chatId});

  @override
  List<Object> get props => [reelId, chatId];
}

class DeleteReelEvent extends ReelsEvent {
  final String reelId;

  const DeleteReelEvent({required this.reelId});

  @override
  List<Object> get props => [reelId];
}

class PauseAllReelsEvent extends ReelsEvent {}

class GetFeedEvent extends ReelsEvent {}

class FetchMoreFeedsEvent extends ReelsEvent {}