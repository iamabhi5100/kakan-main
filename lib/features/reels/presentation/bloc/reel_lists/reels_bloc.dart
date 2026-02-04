import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/home/model/entities/feed_entity.dart';
import 'package:kakan/features/home/model/usecases/add_comment.dart';
import 'package:kakan/features/home/model/usecases/delete_comment.dart';
import 'package:kakan/features/home/model/usecases/get_comments.dart';
import 'package:kakan/features/reels/domain/entities/reel_entity.dart';
import 'package:kakan/features/reels/domain/entities/share_target_entity.dart';
import 'package:kakan/features/reels/domain/usecases/delete_reel.dart';
import 'package:kakan/features/reels/domain/usecases/get_reels.dart';
import 'package:kakan/features/reels/domain/usecases/get_share_targets.dart';
import 'package:kakan/features/reels/domain/usecases/like_reel.dart';
import 'package:kakan/features/reels/domain/usecases/repost_reel.dart';
import 'package:kakan/features/reels/domain/usecases/share_reel.dart';

part 'reels_event.dart';
part 'reels_state.dart';

class ReelsBloc extends Bloc<ReelsEvent, ReelsState> {
  final GetReels getReels;
  final LikeReel likeReel;
  final RepostReel repostReel;
  final ShareReel shareReel;
  final DeleteReel deleteReel;
  final GetShareTargets getShareTargets;
  final GetComments getComments;
  final AddComment addComment;
  final DeleteComment deleteComment;

  ReelsActionState? _cachedReelsState;

  ReelsBloc({
    required this.getReels,
    required this.likeReel,
    required this.repostReel,
    required this.shareReel,
    required this.deleteReel,
    required this.getShareTargets,
    required this.getComments,
    required this.addComment,
    required this.deleteComment,
  }) : super(ReelsInitial()) {
    on<FetchReelsEvent>(_onFetchReels);
    on<FetchMoreReelsEvent>(_onFetchMoreReels);
    on<LikeReelEvent>(_onLikeReel);
    on<RepostReelEvent>(_onRepostReel);
    on<ShareReelEvent>(_onShareReel);
    on<ShareReelToChatEvent>(_onShareReelToChat);
    on<DeleteReelEvent>(_onDeleteReel);
    on<PauseAllReelsEvent>(_onPauseAllReels);
    on<GetReelCommentsEvent>(_onGetReelComments);
    on<AddReelCommentEvent>(_onAddReelComment);
    on<DeleteReelCommentEvent>(_onDeleteReelComment);
  }

  void _emitAndCache(Emitter<ReelsState> emit, ReelsActionState state) {
    _cachedReelsState = state;
    emit(state);
  }

  Future<void> _onFetchReels(FetchReelsEvent event, Emitter<ReelsState> emit) async {
    emit(const ReelsLoading([], true, null));
    final result = await getReels(const Params(nextUrl: null));
    result.fold(
      (failure) => emit(ReelsError(message: _mapFailureToMessage(failure))),
      (data) {
        _emitAndCache(
          emit,
          ReelsLoaded(
            List<ReelEntity>.from(data['reels'] as List),
            data['hasMore'] as bool,
            data['nextUrl'] as String?,
          ),
        );
      },
    );
  }

  Future<void> _onFetchMoreReels(FetchMoreReelsEvent event, Emitter<ReelsState> emit) async {
    if (_cachedReelsState == null) return;
    final current = _cachedReelsState!;
    _emitAndCache(emit, ReelsLoading(current.reels, current.hasMore, current.nextUrl));
    final result = await getReels(Params(nextUrl: current.nextUrl));
    result.fold(
      (failure) => emit(ReelsError(message: _mapFailureToMessage(failure))),
      (data) {
        final updated = [...current.reels, ...List<ReelEntity>.from(data['reels'] as List)];
        _emitAndCache(
          emit,
          ReelsLoaded(
            updated,
            data['hasMore'] as bool,
            data['nextUrl'] as String?,
          ),
        );
      },
    );
  }

  Future<void> _onLikeReel(LikeReelEvent event, Emitter<ReelsState> emit) async {
    if (_cachedReelsState == null) return;
    final current = _cachedReelsState!;
    final original = List<ReelEntity>.from(current.reels);

    final optimistic = current.reels.map((r) {
      if (r.id == event.reelId) {
        final nextCount = event.like ? r.likesCount + 1 : (r.likesCount - 1).clamp(0, 1 << 30);
        return r.copyWith(isLiked: event.like, likesCount: nextCount);
      }
      return r;
    }).toList();

    _emitAndCache(emit, ReelsLikeUpdating(optimistic, current.hasMore, current.nextUrl));

    final res = await likeReel(LikeParams(reelId: event.reelId, like: event.like));
    res.fold(
      (failure) => _emitAndCache(
        emit,
        ReelsLikeError(
          message: _mapFailureToMessage(failure),
          reels: original,
          hasMore: current.hasMore,
          nextUrl: current.nextUrl,
        ),
      ),
      (_) => _emitAndCache(emit, ReelsLoaded(optimistic, current.hasMore, current.nextUrl)),
    );
  }

  Future<void> _onRepostReel(RepostReelEvent event, Emitter<ReelsState> emit) async {
    if (_cachedReelsState == null) return;
    final current = _cachedReelsState!;
    final optimistic = current.reels.map((r) {
      if (r.id == event.reelId) return r.copyWith(repostCount: r.repostCount + 1);
      return r;
    }).toList();

    _emitAndCache(emit, ReelsRepostUpdating(optimistic, current.hasMore, current.nextUrl));

    final res = await repostReel(RepostParams(
      reelId: event.reelId,
      mediaType: event.mediaType,
      title: event.title,
      caption: event.caption,
    ));

    res.fold(
      (failure) => emit(ReelsError(message: _mapFailureToMessage(failure))),
      (_) => _emitAndCache(emit, ReelsLoaded(optimistic, current.hasMore, current.nextUrl)),
    );
  }

  Future<void> _onShareReel(ShareReelEvent event, Emitter<ReelsState> emit) async {
    if (_cachedReelsState == null) return;
    final current = _cachedReelsState!;
    final res = await getShareTargets(NoParams());
    res.fold(
      (failure) => emit(ReelsError(message: _mapFailureToMessage(failure))),
      (targets) => _emitAndCache(
        emit,
        ReelsShareTargetsLoaded(
          reels: current.reels,
          hasMore: current.hasMore,
          nextUrl: current.nextUrl,
          shareTargets: targets,
          reelId: event.reelId,
        ),
      ),
    );
  }

  Future<void> _onShareReelToChat(ShareReelToChatEvent event, Emitter<ReelsState> emit) async {
    if (_cachedReelsState == null) return;
    final current = _cachedReelsState!;
    final shareState = state is ReelsShareTargetsLoaded ? state as ReelsShareTargetsLoaded : null;
    if (shareState == null) return;

    final tgt = shareState.shareTargets.firstWhere(
      (t) => t.chatId == event.chatId,
      orElse: () => throw Exception('Target not found'),
    );

    final res = await shareReel(ShareReelParams(reelId: event.reelId, chatId: event.chatId, type: tgt.type));
    res.fold(
      (failure) => emit(ReelsError(message: _mapFailureToMessage(failure))),
      (_) => _emitAndCache(emit, ReelsLoaded(current.reels, current.hasMore, current.nextUrl)),
    );
  }

  Future<void> _onDeleteReel(DeleteReelEvent event, Emitter<ReelsState> emit) async {
    if (_cachedReelsState == null) return;
    final current = _cachedReelsState!;
    _emitAndCache(emit, ReelsLoading(current.reels, current.hasMore, current.nextUrl));

    final res = await deleteReel(DeleteReelParams(reelId: event.reelId));
    res.fold(
      (failure) => emit(ReelsError(message: _mapFailureToMessage(failure))),
      (_) {
        final updated = current.reels.where((r) => r.id != event.reelId).toList();
        _emitAndCache(emit, ReelsLoaded(updated, current.hasMore, current.nextUrl));
      },
    );
  }

  void _onPauseAllReels(PauseAllReelsEvent event, Emitter<ReelsState> emit) {
    if (_cachedReelsState != null) {
      _emitAndCache(emit, _cachedReelsState!);
    }
  }

  Future<void> _onGetReelComments(GetReelCommentsEvent event, Emitter<ReelsState> emit) async {
    emit(ReelCommentsLoading());
    final res = await getComments(GetCommentsParams(postId: event.reelId));
    res.fold(
      (failure) => emit(ReelCommentsError(_mapFailureToMessage(failure))),
      (comments) => emit(ReelCommentsLoaded(comments)),
    );
  }

  Future<void> _onAddReelComment(AddReelCommentEvent event, Emitter<ReelsState> emit) async {
    final res = await addComment(AddCommentParams(postId: event.reelId, content: event.content));
    res.fold(
      (failure) => emit(ReelCommentsError(_mapFailureToMessage(failure))),
      (_) {
        add(GetReelCommentsEvent(reelId: event.reelId));
        if (_cachedReelsState != null) {
          final current = _cachedReelsState!;
          final updated = current.reels.map((r) {
            if (r.id == event.reelId) return r.copyWith(commentsCount: r.commentsCount + 1);
            return r;
          }).toList();
          _emitAndCache(emit, ReelsLoaded(updated, current.hasMore, current.nextUrl));
        }
      },
    );
  }

  Future<void> _onDeleteReelComment(DeleteReelCommentEvent event, Emitter<ReelsState> emit) async {
    final res = await deleteComment(DeleteCommentParams(commentId: event.commentId));
    res.fold(
      (failure) => emit(ReelCommentsError(_mapFailureToMessage(failure))),
      (_) {
        add(GetReelCommentsEvent(reelId: event.reelId));
        if (_cachedReelsState != null) {
          final current = _cachedReelsState!;
          final updated = current.reels.map((r) {
            if (r.id == event.reelId) {
              final next = r.commentsCount - 1;
              return r.copyWith(commentsCount: next < 0 ? 0 : next);
            }
            return r;
          }).toList();
          _emitAndCache(emit, ReelsLoaded(updated, current.hasMore, current.nextUrl));
        }
      },
    );
  }

  String _mapFailureToMessage(Failure failure) {
    switch (failure.runtimeType) {
      case ServerFailure:
        return 'Server error. Please try again later.';
      default:
        return 'Unexpected error. Please try again.';
    }
  }
}
