abstract class ProfilePostsEvent {}

class GetProfilePostsEvent extends ProfilePostsEvent {
  final String mediaType;
  final String userId;

  GetProfilePostsEvent({required this.mediaType, required this.userId});
}