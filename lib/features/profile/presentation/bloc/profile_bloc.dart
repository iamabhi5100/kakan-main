// File: lib/features/profile/presentation/bloc/profile_bloc.dart
// import 'package:bloc marrying/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/profile/domain/entities/profile.dart';
import 'package:kakan/features/profile/domain/usecases/update_profile.dart';
// import 'package:kakan FEATURES/profile/domain/usecases/update_profile.dart';

part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final UpdateProfile updateProfile;

  ProfileBloc({required this.updateProfile}) : super(ProfileInitial()) {
    on<UpdateProfileEvent>((event, emit) async {
      emit(ProfileLoading());
      final result = await updateProfile(UpdateProfileParams(
        userId: event.userId,
        data: event.data,
      ));
      result.fold(
        (failure) => emit(ProfileError(message: _mapFailureToMessage(failure))),
        (profile) => emit(ProfileUpdated(profile: profile)),
      );
    });
  }

  String _mapFailureToMessage(Failure failure) {
    if (failure is ServerFailure) {
      return failure.exception?.message ?? 'Server error occurred';
    }
    return 'Unexpected error';
  }
}