import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/utils/constants.dart';
import 'package:kakan/features/profile/domain/usecases/get_profile_posts.dart';
import 'profile_posts_event.dart';
import 'profile_posts_state.dart';

class ProfilePostsBloc extends Bloc<ProfilePostsEvent, ProfilePostsState> {
  final GetProfilePosts getProfilePosts;

  ProfilePostsBloc({required this.getProfilePosts}) : super(ProfilePostsInitial()) {
    on<GetProfilePostsEvent>(_onGetProfilePosts);
  }

  Future<void> _onGetProfilePosts(
    GetProfilePostsEvent event,
    Emitter<ProfilePostsState> emit,
  ) async {
    if (kDebugMode) {
      print('ProfilePostsBloc: Fetching posts for mediaType: ${event.mediaType}');
    }
    try {
      emit(ProfilePostsLoading());
      final result = await getProfilePosts(event.mediaType);
      result.fold(
        (failure) {
          if (kDebugMode) {
            print('ProfilePostsBloc: Error: ${_mapFailureToMessage(failure)}');
          }
          emit(ProfilePostsError(_mapFailureToMessage(failure)));
        },
        (posts) {
          if (kDebugMode) {
            print('ProfilePostsBloc: Success: ${posts.length} items fetched');
          }
          emit(ProfilePostsLoaded(posts));
        },
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('ProfilePostsBloc: Unexpected error: $e');
        print('Stack trace: $stackTrace');
      }
      emit(ProfilePostsError('Unexpected error: $e'));
    }
  }

  String _mapFailureToMessage(Failure failure) {
    if (failure is ServerFailure) {
      return failure.exception?.message ?? Constants.SERVER_FAILURE_MESSAGE;
    }
    return 'Unexpected error';
  }
}