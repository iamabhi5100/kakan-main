import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/utils/constants.dart';
import 'package:kakan/features/myfiles/domain/usecases/delete_download.dart';
import 'delete_download_event.dart';
import 'delete_download_state.dart';

class DeleteDownloadBloc extends Bloc<DeleteDownloadEvent, DeleteDownloadState> {
  final DeleteDownload deleteDownload;

  DeleteDownloadBloc({required this.deleteDownload}) : super(DeleteDownloadInitial()) {
    on<DeleteDownloadEvent>(_onDeleteDownload);
  }

  Future<void> _onDeleteDownload(
    DeleteDownloadEvent event,
    Emitter<DeleteDownloadState> emit,
  ) async {
    if (kDebugMode) {
      print('DeleteDownloadBloc: Deleting download with mediaId: ${event.mediaId}');
    }
    try {
      emit(DeleteDownloadLoading());
      final result = await deleteDownload(event.mediaId);
      result.fold(
        (failure) {
          if (kDebugMode) {
            print('DeleteDownloadBloc: Error: ${_mapFailureToMessage(failure)}');
          }
          emit(DeleteDownloadError(_mapFailureToMessage(failure)));
        },
        (_) {
          if (kDebugMode) {
            print('DeleteDownloadBloc: Success: Download deleted');
          }
          emit(DeleteDownloadSuccess());
        },
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('DeleteDownloadBloc: Unexpected error: $e');
        print('Stack trace: $stackTrace');
      }
      emit(DeleteDownloadError('Unexpected error: $e'));
    }
  }

  String _mapFailureToMessage(Failure failure) {
    if (failure is ServerFailure) {
      return failure.exception?.message ?? Constants.SERVER_FAILURE_MESSAGE;
    }
    return 'Unexpected error';
  }
}