abstract class DeletePostState {}

class DeletePostInitial extends DeletePostState {}

class DeletePostLoading extends DeletePostState {}

class DeletePostSuccess extends DeletePostState {}

class DeletePostError extends DeletePostState {
  final String message;

  DeletePostError(this.message);
}