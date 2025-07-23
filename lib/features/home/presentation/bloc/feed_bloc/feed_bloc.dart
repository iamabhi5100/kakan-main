import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/core/utils/constants.dart';
import 'package:kakan/features/home/model/entities/feed_entity.dart';
import 'package:kakan/features/home/model/repositories/feed_repository.dart';
import 'package:kakan/features/home/model/usecases/get_feeds.dart';
import 'feed_event.dart';
import 'feed_state.dart';

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  final GetFeeds getFeeds;
  final FeedRepository repository;
  List<FeedEntity> _currentFeeds = []; // Cache current feeds

  FeedBloc({
    required this.getFeeds,
    required this.repository,
  }) : super(FeedInitial()) {
    on<GetFeedEvent>(_onGetFeeds);
    on<LikeDislikePostEvent>(_onLikeDislikePost);
    on<RepostEvent>(_onRepost);
    on<DeleteFeedEvent>(_onDeleteFeed);
  }

  Future<void> _onGetFeeds(
    GetFeedEvent event,
    Emitter<FeedState> emit,
  ) async {
    if (kDebugMode) {
      print('FeedBloc: Fetching feeds');
    }
    try {
      emit(FeedLoading());
      final result = await getFeeds(NoParams());
      result.fold(
        (failure) {
          if (kDebugMode) {
            print('FeedBloc: Error: ${_mapFailureToMessage(failure)}');
          }
          emit(FeedError(_mapFailureToMessage(failure)));
        },
        (feeds) {
          if (kDebugMode) {
            print('FeedBloc: Success: ${feeds.length} feeds fetched');
          }
          _currentFeeds = feeds; // Cache feeds
          emit(FeedLoaded(feeds));
        },
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('FeedBloc: Unexpected error: $e');
        print('Stack trace: $stackTrace');
      }
      emit(FeedError('Unexpected error: $e'));
    }
  }

  Future<void> _onLikeDislikePost(
    LikeDislikePostEvent event,
    Emitter<FeedState> emit,
  ) async {
    try {
      // Update local state optimistically
      final updatedFeeds = _currentFeeds.map((feed) {
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
            privacy: feed.privacy,
            likesCount: feed.flagLiked ? feed.likesCount - 1 : feed.likesCount + 1,
            repostCount: feed.repostCount,
            flagLiked: !feed.flagLiked,
          );
        }
        return feed;
      }).toList();

      emit(FeedLoaded(updatedFeeds)); // Emit updated state without loading

      final result = await repository.likeDislikePost(event.postId);
      result.fold(
        (failure) {
          if (kDebugMode) {
            print('FeedBloc: Like/Dislike Error: ${_mapFailureToMessage(failure)}');
          }
          emit(FeedActionError(_mapFailureToMessage(failure)));
          // Revert optimistic update
          emit(FeedLoaded(_currentFeeds));
        },
        (_) {
          if (kDebugMode) {
            print('FeedBloc: Like/Dislike Success');
          }
          _currentFeeds = updatedFeeds; // Update cache on success
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('FeedBloc: Like/Dislike Unexpected error: $e');
      }
      emit(FeedActionError('Unexpected error: $e'));
      emit(FeedLoaded(_currentFeeds)); // Revert to cached state
    }
  }

  Future<void> _onRepost(
    RepostEvent event,
    Emitter<FeedState> emit,
  ) async {
    try {
      emit(FeedActionLoading());
      final result = await repository.repost(
        postId: event.postId,
        title: event.title,
        caption: event.caption,
      );
      result.fold(
        (failure) {
          if (kDebugMode) {
            print('FeedBloc: Repost Error: ${_mapFailureToMessage(failure)}');
          }
          emit(FeedActionError(_mapFailureToMessage(failure)));
        },
        (newPostId) {
          if (kDebugMode) {
            print('FeedBloc: Repost Success, new post ID: $newPostId');
          }
          emit(FeedActionSuccess(newPostId: newPostId));
          add(GetFeedEvent()); // Repost adds a new feed, so refresh
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('FeedBloc: Repost Unexpected error: $e');
      }
      emit(FeedActionError('Unexpected error: $e'));
    }
  }

  Future<void> _onDeleteFeed(
    DeleteFeedEvent event,
    Emitter<FeedState> emit,
  ) async {
    try {
      emit(FeedActionLoading());
      final result = await repository.deleteFeed(event.feedId);
      result.fold(
        (failure) {
          if (kDebugMode) {
            print('FeedBloc: Delete Error: ${_mapFailureToMessage(failure)}');
          }
          emit(FeedActionError(_mapFailureToMessage(failure)));
        },
        (_) {
          if (kDebugMode) {
            print('FeedBloc: Delete Success');
          }
          emit(FeedActionSuccess());
          add(GetFeedEvent()); // Delete removes a feed, so refresh
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('FeedBloc: Delete Unexpected error: $e');
      }
      emit(FeedActionError('Unexpected error: $e'));
    }
  }

  String _mapFailureToMessage(Failure failure) {
    if (failure is ServerFailure) {
      return failure.exception?.message ?? Constants.SERVER_FAILURE_MESSAGE;
    }
    return 'Unexpected error';
  }
}