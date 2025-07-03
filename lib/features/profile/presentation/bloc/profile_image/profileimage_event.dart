abstract class ProfileimageEvent {}

class UploadProfileimageEvent extends ProfileimageEvent {
  final String userId;
  final String imagePath;

  UploadProfileimageEvent({
    required this.userId,
    required this.imagePath,
  });
}