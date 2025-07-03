abstract class ProfileimageState {}

class ProfileimageInitial extends ProfileimageState {}

class ProfileimageLoading extends ProfileimageState {}

class ProfileimageUploaded extends ProfileimageState {
  final String message;

  ProfileimageUploaded(this.message);
}

class ProfileimageError extends ProfileimageState {
  final String message;

  ProfileimageError(this.message);
}