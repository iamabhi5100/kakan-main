abstract class ProfilePostsEvent {}

class GetProfilePostsEvent extends ProfilePostsEvent {
  final String mediaType;

  GetProfilePostsEvent({required this.mediaType});
}