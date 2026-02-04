import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/utils/constants.dart';
import 'package:kakan/features/myfiles/domain/usecases/get_downloads.dart';
import 'downloads_event.dart';
import 'downloads_state.dart';

class DownloadsBloc extends Bloc<DownloadsEvent, DownloadsState> {
  final GetDownloads getDownloads;

  DownloadsBloc({required this.getDownloads}) : super(DownloadsInitial()) {
    on<GetDownloadsEvent>(_onGetDownloads);
  }

  Future<void> _onGetDownloads(
    GetDownloadsEvent event,
    Emitter<DownloadsState> emit,
  ) async {
    if (kDebugMode) {
      print('DownloadsBloc: Fetching downloads for mediaType: ${event.mediaType}, search: ${event.search}');
    }
    try {
      emit(DownloadsLoading());
      final result = await getDownloads(
        GetDownloadsParams(mediaType: event.mediaType, search: event.search),
      );
      result.fold(
        (failure) {
          if (kDebugMode) {
            print('DownloadsBloc: Error: ${_mapFailureToMessage(failure)}');
          }
          emit(DownloadsError(_mapFailureToMessage(failure)));
        },
        (downloads) {
          if (kDebugMode) {
            print('DownloadsBloc: Success: ${downloads.length} items fetched');
          }
          emit(DownloadsLoaded(downloads));
        },
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('DownloadsBloc: Unexpected error: $e');
        print('Stack trace: $stackTrace');
      }
      emit(DownloadsError('Unexpected error: $e'));
    }
  }

  String _mapFailureToMessage(Failure failure) {
    if (failure is ServerFailure) {
      return failure.exception?.message ?? Constants.SERVER_FAILURE_MESSAGE;
    }
    return 'Unexpected error';
  }
}
