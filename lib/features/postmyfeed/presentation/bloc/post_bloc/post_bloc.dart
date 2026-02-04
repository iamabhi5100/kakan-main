import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/utils/constants.dart';
import 'package:kakan/features/postmyfeed/domain/usecases/create_post.dart';
import 'post_event.dart';
import 'post_state.dart';

class PostBloc extends Bloc<PostEvent, PostState> {
  final CreatePost createPost;

  PostBloc({required this.createPost}) : super(PostInitial()) {
    on<CreatePostEvent>(_onCreatePost);
  }

  Future<void> _onCreatePost(
    CreatePostEvent event,
    Emitter<PostState> emit,
  ) async {
    if (kDebugMode) {
      print('PostBloc: Creating post with title: ${event.title}');
    }
    try {
      emit(PostLoading());
      final result = await createPost(CreatePostParams(
        mediaType: event.mediaType,
        title: event.title,
        caption: event.caption,
        mediaFilePath: event.mediaFilePath,
        mediaId: event.mediaId,
        thumbnailPath: event.thumbnailPath,
        shareTo: event.shareTo, // Add shareTo here
      ));
      result.fold(
        (failure) {
          if (kDebugMode) {
            print('PostBloc: Error: ${_mapFailureToMessage(failure)}');
          }
          emit(PostError(_mapFailureToMessage(failure)));
        },
        (post) {
          if (kDebugMode) {
            print('PostBloc: Success: Post created with ID ${post.id}');
          }
          emit(PostCreated(post));
        },
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('PostBloc: Unexpected error: $e');
        print('Stack trace: $stackTrace');
      }
      emit(PostError('Unexpected error: $e'));
    }
  }

  String _mapFailureToMessage(Failure failure) {
    if (failure is ServerFailure) {
      return failure.exception?.message ?? Constants.SERVER_FAILURE_MESSAGE;
    }
    return 'Unexpected error';
  }
}