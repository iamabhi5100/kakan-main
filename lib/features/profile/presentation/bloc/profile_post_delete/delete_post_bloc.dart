import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/utils/constants.dart';
import 'package:kakan/features/profile/domain/usecases/delete_post.dart';
// import 'package:kakan/features/postmyfeed/domain/usecases/delete_post.dart';
import 'delete_post_event.dart';
import 'delete_post_state.dart';

class DeletePostBloc extends Bloc<DeletePostEvent, DeletePostState> {
  final DeletePost deletePost;

  DeletePostBloc({required this.deletePost}) : super(DeletePostInitial()) {
    on<DeletePostRequested>(_onDeletePostRequested);
  }

  Future<void> _onDeletePostRequested(
    DeletePostRequested event,
    Emitter<DeletePostState> emit,
  ) async {
    if (kDebugMode) {
      print('DeletePostBloc: Deleting post with ID: ${event.postId}');
    }
    try {
      emit(DeletePostLoading());
      final result = await deletePost(event.postId);
      result.fold(
        (failure) {
          if (kDebugMode) {
            print('DeletePostBloc: Error: ${_mapFailureToMessage(failure)}');
          }
          emit(DeletePostError(_mapFailureToMessage(failure)));
        },
        (_) {
          if (kDebugMode) {
            print('DeletePostBloc: Post deleted successfully');
          }
          emit(DeletePostSuccess());
        },
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('DeletePostBloc: Unexpected error: $e');
        print('Stack trace: $stackTrace');
      }
      emit(DeletePostError('Unexpected error: $e'));
    }
  }

  String _mapFailureToMessage(Failure failure) {
    if (failure is ServerFailure) {
      return failure.exception?.message ?? Constants.SERVER_FAILURE_MESSAGE;
    }
    return 'Unexpected error';
  }
}