abstract class DeletePostEvent {}

class DeletePostRequested extends DeletePostEvent {
  final String postId;

  DeletePostRequested({required this.postId});
}