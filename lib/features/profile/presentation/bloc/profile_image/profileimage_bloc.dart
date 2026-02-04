import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/utils/constants.dart';
import 'package:kakan/features/profile/domain/usecases/upload_profileimage.dart';
import 'profileimage_event.dart';
import 'profileimage_state.dart';

class ProfileimageBloc extends Bloc<ProfileimageEvent, ProfileimageState> {
  final UploadProfileimage uploadProfileimage;

  ProfileimageBloc({required this.uploadProfileimage})
      : super(ProfileimageInitial()) {
    on<UploadProfileimageEvent>(_onUploadProfileimage);
  }

  Future<void> _onUploadProfileimage(
    UploadProfileimageEvent event,
    Emitter<ProfileimageState> emit,
  ) async {
    emit(ProfileimageLoading());
    final result = await uploadProfileimage(
      UploadProfileimageParams(
        userId: event.userId,
        imagePath: event.imagePath,
      ),
    );
    result.fold(
      (failure) => emit(ProfileimageError(_mapFailureToMessage(failure))),
      (entity) => emit(ProfileimageUploaded(entity.message)),
    );
  }

  String _mapFailureToMessage(Failure failure) {
    if (failure is ServerFailure) {
      return failure.exception?.message ?? Constants.SERVER_FAILURE_MESSAGE;
    }
    return 'Unexpected error';
  }
}