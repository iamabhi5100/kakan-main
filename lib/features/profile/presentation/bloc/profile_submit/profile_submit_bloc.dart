import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/utils/constants.dart';
import 'package:kakan/features/profile/domain/usecases/submit_profile.dart';
import 'profile_submit_event.dart';
import 'profile_submit_state.dart';

class ProfileSubmitBloc extends Bloc<ProfileSubmitEvent, ProfileSubmitState> {
  final SubmitProfile submitProfile;

  ProfileSubmitBloc({required this.submitProfile}) : super(ProfileSubmitInitial()) {
    on<SubmitProfileEvent>(_onSubmitProfile);
  }

  Future<void> _onSubmitProfile(
    SubmitProfileEvent event,
    Emitter<ProfileSubmitState> emit,
  ) async {
    if (kDebugMode) {
      print('ProfileSubmitBloc: Submitting profile for userId: ${event.userId}, data: ${event.data}');
    }
    try {
      emit(ProfileSubmitLoading());
      final result = await submitProfile(SubmitProfileParams(userId: event.userId, data: event.data));
      result.fold(
        (failure) {
          if (kDebugMode) {
            print('ProfileSubmitBloc: Error: ${_mapFailureToMessage(failure)}');
          }
          emit(ProfileSubmitError(_mapFailureToMessage(failure)));
        },
        (profileDetails) {
          if (kDebugMode) {
            print('ProfileSubmitBloc: Success: '
                'name=${profileDetails.name}, '
                'username=${profileDetails.username}, '
                'phone=${profileDetails.phone}, '
                'email=${profileDetails.email}, '
                'dateOfBirth=${profileDetails.dateOfBirth}, '
                'title=${profileDetails.title}, '
                'gender=${profileDetails.gender}, '
                'occupation=${profileDetails.occupation}, '
                'profileImage=${profileDetails.profileImage}');
          }
          emit(ProfileSubmitSuccess(profileDetails));
        },
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('ProfileSubmitBloc: Unexpected error: $e');
        print('Stack trace: $stackTrace');
      }
      emit(ProfileSubmitError('Unexpected error: $e'));
    }
  }

  String _mapFailureToMessage(Failure failure) {
    if (failure is ServerFailure) {
      return failure.exception?.message ?? Constants.SERVER_FAILURE_MESSAGE;
    }
    return 'Unexpected error';
  }
}