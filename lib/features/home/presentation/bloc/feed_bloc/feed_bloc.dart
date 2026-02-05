import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/core/utils/constants.dart';
import 'package:kakan/features/home/model/entities/feed_entity.dart';
import 'package:kakan/features/home/model/repositories/feed_repository.dart';
import 'package:kakan/features/home/model/usecases/add_comment.dart';
import 'package:kakan/features/home/model/usecases/delete_comment.dart';
import 'package:kakan/features/home/model/usecases/get_comments.dart';
import 'package:kakan/features/home/model/usecases/get_feeds.dart';
import 'feed_event.dart';
import 'feed_state.dart';

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  final GetFeeds getFeeds;
  final FeedRepository repository;
  final AddComment addComment;
  final GetComments getComments;
  final DeleteComment deleteComment;

  /// cache last action state (like Reels)
  FeedActionState? _cached;
  bool isLoadingMore = false;

  FeedBloc({
    required this.getFeeds,
    required this.repository,
    required this.addComment,
    required this.getComments,
    required this.deleteComment,
  }) : super(FeedInitial()) {
    on<FetchFeedsEvent>(_onFetchFeeds);
    on<FetchMoreFeedsEvent>(_onFetchMoreFeeds);
    on<RefreshFeedsEvent>(_onRefreshFeeds);

    on<LikeDislikePostEvent>(_onLikeDislikePost);
    on<RepostEvent>(_onRepost);
    on<DeleteFeedEvent>(_onDeleteFeed);

    on<AddCommentEvent>(_onAddComment);
    on<GetCommentsEvent>(_onGetComments);
    on<DeleteCommentEvent>(_onDeleteComment);
  }

  void _emitAndCache(Emitter<FeedState> emit, FeedActionState state) {
    _cached = state;
    emit(state);
  }

  Future<void> _onFetchFeeds(
      FetchFeedsEvent event, Emitter<FeedState> emit) async {
    _emitAndCache(emit, const FeedLoading([], true, null));
    final result = await getFeeds(const FeedParams(nextUrl: null));
    result.fold(
      (failure) => emit(FeedError(_mapFailureToMessage(failure))),
      (data) {
        final feeds = List<FeedEntity>.from(data['feeds'] as List);
        final hasMore = data['hasMore'] as bool;
        final nextUrl = data['nextUrl'] as String?;
        _emitAndCache(emit, FeedLoaded(feeds, hasMore, nextUrl));
      },
    );
  }

  Future<void> _onFetchMoreFeeds(
      FetchMoreFeedsEvent event, Emitter<FeedState> emit) async {
    if (_cached == null || _cached!.nextUrl == null || isLoadingMore) return;
    isLoadingMore = true;
    final current = _cached!;
    _emitAndCache(emit, FeedLoading(current.feeds, current.hasMore, current.nextUrl));
    final result = await getFeeds(FeedParams(nextUrl: current.nextUrl));
    result.fold(
      (failure) {
        isLoadingMore = false;
        emit(FeedError(_mapFailureToMessage(failure)));
      },
      (data) {
        isLoadingMore = false;
        final more = List<FeedEntity>.from(data['feeds'] as List);
        final updated = [...current.feeds, ...more];
        _emitAndCache(
          emit,
          FeedLoaded(updated, data['hasMore'] as bool, data['nextUrl'] as String?),
        );
      },
    );
  }

  Future<void> _onRefreshFeeds(
      RefreshFeedsEvent event, Emitter<FeedState> emit) async {
    _emitAndCache(emit, const FeedLoading([], true, null));
    final result = await getFeeds(const FeedParams(nextUrl: null));
    result.fold(
      (failure) => emit(FeedError(_mapFailureToMessage(failure))),
      (data) {
        final feeds = List<FeedEntity>.from(data['feeds'] as List);
        _emitAndCache(
            emit, FeedLoaded(feeds, data['hasMore'] as bool, data['nextUrl'] as String?));
      },
    );
  }

  Future<void> _onLikeDislikePost(
      LikeDislikePostEvent event, Emitter<FeedState> emit) async {
    if (_cached == null) return;
    final current = _cached!;
    // optimistic
    final updated = current.feeds.map((feed) {
      if (feed.id == event.postId) {
        return FeedEntity(
          id: feed.id,
          userProfileDetails: feed.userProfileDetails,
          created: feed.created,
          mediaType: feed.mediaType,
          title: feed.title,
          caption: feed.caption,
          mediaFile: feed.mediaFile,
          thumbnail: feed.thumbnail,
          mediaItems: feed.mediaItems,
          privacy: feed.privacy,
          likesCount: feed.flagLiked ? feed.likesCount - 1 : feed.likesCount + 1,
          repostCount: feed.repostCount,
          commentsCount: feed.commentsCount,
          flagLiked: !feed.flagLiked,
          flagOwnPost: feed.flagOwnPost,
        );
      }
      return feed;
    }).toList();

    _emitAndCache(emit, FeedLoaded(updated, current.hasMore, current.nextUrl));

    final result = await repository.likeDislikePost(event.postId);
    result.fold(
      (failure) {
        emit(FeedActionError(_mapFailureToMessage(failure)));
        // revert
        _emitAndCache(emit, FeedLoaded(current.feeds, current.hasMore, current.nextUrl));
      },
      (_) {
        emit(const FeedActionSuccess(actionType: 'like'));
      },
    );
  }

  Future<void> _onRepost(RepostEvent event, Emitter<FeedState> emit) async {
    emit(FeedActionLoading());
    final result = await repository.repost(
      postId: event.postId,
      title: event.title,
      caption: event.caption,
    );
    result.fold(
      (failure) => emit(FeedActionError(_mapFailureToMessage(failure))),
      (newPostId) {
        emit(FeedActionSuccess(actionType: 'repost', newPostId: newPostId));
        add(const RefreshFeedsEvent());
      },
    );
  }

  Future<void> _onDeleteFeed(
      DeleteFeedEvent event, Emitter<FeedState> emit) async {
    emit(FeedActionLoading());
    final result = await repository.deleteFeed(event.feedId);
    result.fold(
      (failure) => emit(FeedActionError(_mapFailureToMessage(failure))),
      (_) {
        emit(const FeedActionSuccess(actionType: 'delete'));
        add(const RefreshFeedsEvent());
      },
    );
  }

  Future<void> _onAddComment(
      AddCommentEvent event, Emitter<FeedState> emit) async {
    emit(FeedActionLoading());
    final result =
        await addComment(AddCommentParams(postId: event.postId, content: event.content));
    result.fold(
      (failure) => emit(FeedActionError(_mapFailureToMessage(failure))),
      (_) {
        // bump count locally
        if (_cached != null) {
          final cur = _cached!;
          final updated = cur.feeds.map((f) {
            if (f.id == event.postId) {
              return FeedEntity(
                id: f.id,
                userProfileDetails: f.userProfileDetails,
                created: f.created,
                mediaType: f.mediaType,
                title: f.title,
                caption: f.caption,
                mediaFile: f.mediaFile,
                thumbnail: f.thumbnail,
                mediaItems: f.mediaItems,
                privacy: f.privacy,
                likesCount: f.likesCount,
                repostCount: f.repostCount,
                commentsCount: f.commentsCount + 1,
                flagLiked: f.flagLiked,
                flagOwnPost: f.flagOwnPost,
              );
            }
            return f;
          }).toList();
          _emitAndCache(emit, FeedLoaded(updated, cur.hasMore, cur.nextUrl));
        }
        emit(const FeedActionSuccess(actionType: 'comment'));
        add(GetCommentsEvent(postId: event.postId));
      },
    );
  }

  Future<void> _onGetComments(
      GetCommentsEvent event, Emitter<FeedState> emit) async {
    emit(CommentsLoading());
    final result = await getComments(GetCommentsParams(postId: event.postId));
    result.fold(
      (failure) => emit(CommentsError(_mapFailureToMessage(failure))),
      (comments) => emit(CommentsLoaded(comments)),
    );
  }

  Future<void> _onDeleteComment(
      DeleteCommentEvent event, Emitter<FeedState> emit) async {
    emit(FeedActionLoading());
    final result = await deleteComment(DeleteCommentParams(commentId: event.commentId));
    result.fold(
      (failure) => emit(FeedActionError(_mapFailureToMessage(failure))),
      (_) {
        if (_cached != null) {
          final cur = _cached!;
          final updated = cur.feeds.map((f) {
            if (f.id == event.postId && f.commentsCount > 0) {
              return FeedEntity(
                id: f.id,
                userProfileDetails: f.userProfileDetails,
                created: f.created,
                mediaType: f.mediaType,
                title: f.title,
                caption: f.caption,
                mediaFile: f.mediaFile,
                thumbnail: f.thumbnail,
                mediaItems: f.mediaItems,
                privacy: f.privacy,
                likesCount: f.likesCount,
                repostCount: f.repostCount,
                commentsCount: f.commentsCount - 1,
                flagLiked: f.flagLiked,
                flagOwnPost: f.flagOwnPost,
              );
            }
            return f;
          }).toList();
          _emitAndCache(emit, FeedLoaded(updated, cur.hasMore, cur.nextUrl));
        }
        emit(const FeedActionSuccess(actionType: 'delete_comment'));
        add(GetCommentsEvent(postId: event.postId));
      },
    );
  }

  String _mapFailureToMessage(Failure failure) {
    if (failure is ServerFailure) {
      return failure.exception?.message ?? Constants.SERVER_FAILURE_MESSAGE;
    }
    return 'Unexpected error';
  }
}
