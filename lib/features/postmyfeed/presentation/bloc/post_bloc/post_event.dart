abstract class PostEvent {}

class CreatePostEvent extends PostEvent {
  final String mediaType;
  final String title;
  final String? caption;
  final String? mediaFilePath;
  final String? mediaId;
  final String? thumbnailPath;
  final String shareTo;

  CreatePostEvent({
    required this.mediaType,
    required this.title,
    this.caption,
    this.mediaFilePath,
    this.mediaId,
    this.thumbnailPath,
    required this.shareTo,
  });
}