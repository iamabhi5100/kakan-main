class PostEntity {
  final String id;
  final String title;
  final String? caption;
  final String? mediaFile;
  final String? thumbnail;

  PostEntity({
    required this.id,
    required this.title,
    this.caption,
    this.mediaFile,
    this.thumbnail,
  });
}