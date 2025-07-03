class ProfilePostEntity {
  final String id;
  final String caption;
  final String title;
  final String? thumbnail;
  final String? mediaFile;
  final String mediaType;
  final String created;

  ProfilePostEntity({
    required this.id,
    required this.caption,
    required this.title,
    this.thumbnail,
    this.mediaFile,
    required this.mediaType,
    required this.created,
  });
}