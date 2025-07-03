import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
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

  ReelsBloc({
    required this.getReels,
    required this.likeReel,
    required this.repostReel,
    required this.shareReel,
    required this.deleteReel,
    required this.getShareTargets,
  }) : super(ReelsInitial()) {
    print('DEBUG: ReelsBloc initialized with getReels: $getReels, likeReel: $likeReel, repostReel: $repostReel, shareReel: $shareReel, deleteReel: $deleteReel, getShareTargets: $getShareTargets');

    on<FetchReelsEvent>((event, emit) async {
      emit(const ReelsLoading([], true, null));
      final result = await getReels(Params(nextUrl: null));
      result.fold(
        (failure) => emit(ReelsError(message: _mapFailureToMessage(failure))),
        (data) {
          print('DEBUG: Fetched ${data['reels'].length} reels, hasMore: ${data['hasMore']}');
          emit(ReelsLoaded(
            List<ReelEntity>.from(data['reels'] as List),
            data['hasMore'] as bool,
            data['nextUrl'] as String?,
          ));
        },
      );
    });

    on<FetchMoreReelsEvent>((event, emit) async {
      if (state is ReelsLoaded) {
        final currentState = state as ReelsLoaded;
        emit(ReelsLoading(currentState.reels, currentState.hasMore, currentState.nextUrl));
        final result = await getReels(Params(nextUrl: currentState.nextUrl));
        result.fold(
          (failure) => emit(ReelsError(message: _mapFailureToMessage(failure))),
          (data) {
            final updatedReels = [...currentState.reels, ...data['reels'] as List];
            print('DEBUG: Fetched more reels, total: ${updatedReels.length}');
            emit(ReelsLoaded(
              List<ReelEntity>.from(updatedReels),
              data['hasMore'] as bool,
              data['nextUrl'] as String?,
            ));
          },
        );
      }
    });

    on<LikeReelEvent>((event, emit) async {
      if (state is ReelsLoaded) {
        final currentState = state as ReelsLoaded;
        final updatedReels = currentState.reels.map((reel) {
          if (reel.id == event.reelId) {
            return reel.copyWith(
              isLiked: event.like,
              likesCount: event.like ? reel.likesCount + 1 : reel.likesCount - 1,
            );
          }
          return reel;
        }).toList();
        emit(ReelsLikeUpdating(updatedReels, currentState.hasMore, currentState.nextUrl));
        final result = await likeReel(LikeParams(reelId: event.reelId, like: event.like));
        result.fold(
          (failure) => emit(ReelsLikeError(
            message: _mapFailureToMessage(failure),
            reels: currentState.reels,
            hasMore: currentState.hasMore,
            nextUrl: currentState.nextUrl,
          )),
          (_) => emit(ReelsLoaded(updatedReels, currentState.hasMore, currentState.nextUrl)),
        );
      }
    });

    on<RepostReelEvent>((event, emit) async {
      if (state is ReelsLoaded) {
        final currentState = state as ReelsLoaded;
        final updatedReels = currentState.reels.map((reel) {
          if (reel.id == event.reelId) {
            return reel.copyWith(repostCount: reel.repostCount + 1);
          }
          return reel;
        }).toList();
        emit(ReelsRepostUpdating(updatedReels, currentState.hasMore, currentState.nextUrl));
        final result = await repostReel(RepostParams(
          reelId: event.reelId,
          mediaType: event.mediaType,
          title: event.title,
          caption: event.caption,
        ));
        result.fold(
          (failure) => emit(ReelsError(message: _mapFailureToMessage(failure))),
          (_) => emit(ReelsLoaded(updatedReels, currentState.hasMore, currentState.nextUrl)),
        );
      }
    });

    on<ShareReelEvent>((event, emit) async {
      if (state is ReelsLoaded) {
        final currentState = state as ReelsLoaded;
        final result = await getShareTargets(NoParams());
        result.fold(
          (failure) => emit(ReelsError(message: _mapFailureToMessage(failure))),
          (targets) => emit(ReelsShareTargetsLoaded(
            reels: currentState.reels,
            hasMore: currentState.hasMore,
            nextUrl: currentState.nextUrl,
            shareTargets: targets,
            reelId: event.reelId,
          )),
        );
      }
    });

    on<ShareReelToChatEvent>((event, emit) async {
      if (state is ReelsShareTargetsLoaded) {
        final currentState = state as ReelsShareTargetsLoaded;
        final target = currentState.shareTargets.firstWhere(
          (t) => t.chatId == event.chatId,
          orElse: () => throw Exception('Target not found'),
        );
        final result = await shareReel(ShareReelParams(
          reelId: event.reelId,
          chatId: event.chatId,
          type: target.type,
        ));
        result.fold(
          (failure) => emit(ReelsError(message: _mapFailureToMessage(failure))),
          (_) => emit(ReelsLoaded(currentState.reels, currentState.hasMore, currentState.nextUrl)),
        );
      }
    });

    on<DeleteReelEvent>((event, emit) async {
      if (state is ReelsLoaded) {
        final currentState = state as ReelsLoaded;
        emit(ReelsLoading(currentState.reels, currentState.hasMore, currentState.nextUrl));
        final result = await deleteReel(DeleteReelParams(reelId: event.reelId));
        result.fold(
          (failure) => emit(ReelsError(message: _mapFailureToMessage(failure))),
          (_) {
            final updatedReels = currentState.reels.where((reel) => reel.id != event.reelId).toList();
            print('DEBUG: Reel ${event.reelId} deleted, new reel count: ${updatedReels.length}');
            emit(ReelsLoaded(updatedReels, currentState.hasMore, currentState.nextUrl));
          },
        );
      }
    });

    on<PauseAllReelsEvent>((event, emit) async {
      if (state is ReelsLoaded) {
        final currentState = state as ReelsLoaded;
        emit(currentState);
      }
    });
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