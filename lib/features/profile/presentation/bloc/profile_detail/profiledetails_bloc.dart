import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/utils/constants.dart';
import 'package:kakan/features/profile/domain/usecases/get_profiledetails.dart';
import 'profiledetails_event.dart';
import 'profiledetails_state.dart';

class ProfiledetailsBloc extends Bloc<ProfiledetailsEvent, ProfiledetailsState> {
  final GetProfiledetails getProfiledetails;

  ProfiledetailsBloc({required this.getProfiledetails})
      : super(ProfiledetailsInitial()) {
    on<GetProfiledetailsEvent>(_onGetProfiledetails);
  }

  Future<void> _onGetProfiledetails(
    GetProfiledetailsEvent event,
    Emitter<ProfiledetailsState> emit,
  ) async {
    if (kDebugMode) {
      print('ProfiledetailsBloc: Fetching profile details for userId: ${event.userId}');
    }
    try {
      emit(ProfiledetailsLoading());
      final result = await getProfiledetails(event.userId);
      result.fold(
        (failure) {
          if (kDebugMode) {
            print('ProfiledetailsBloc: Error: ${_mapFailureToMessage(failure)}');
          }
          emit(ProfiledetailsError(_mapFailureToMessage(failure)));
        },
        (profileDetails) {
          if (kDebugMode) {
            print('ProfiledetailsBloc: Success: '
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
          emit(ProfiledetailsLoaded(profileDetails));
        },
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('ProfiledetailsBloc: Unexpected error: $e');
        print('Stack trace: $stackTrace');
      }
      emit(ProfiledetailsError('Unexpected error: $e'));
    }
  }

  String _mapFailureToMessage(Failure failure) {
    if (failure is ServerFailure) {
      return failure.exception?.message ?? Constants.SERVER_FAILURE_MESSAGE;
    }
    return 'Unexpected error';
  }
}