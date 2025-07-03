// lib/features/home/presentation/bloc/feed_bloc.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/core/utils/constants.dart';
import 'package:kakan/features/home/model/usecases/get_feeds.dart';
import 'feed_event.dart';
import 'feed_state.dart';

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  final GetFeeds getFeeds;

  FeedBloc({required this.getFeeds}) : super(FeedInitial()) {
    on<GetFeedEvent>(_onGetFeeds);
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

  String _mapFailureToMessage(Failure failure) {
    if (failure is ServerFailure) {
      return failure.exception?.message ?? Constants.SERVER_FAILURE_MESSAGE;
    }
    return 'Unexpected error';
  }
}