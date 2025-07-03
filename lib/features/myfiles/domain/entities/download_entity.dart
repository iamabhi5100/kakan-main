class DownloadEntity {
  final String id;
  final String created;
  final String mediaType;
  final String? mediaFile;
  final String? title;
  final String? duration;
    final String? thumbnail;

  DownloadEntity({
    required this.id,
    required this.created,
    required this.mediaType,
    this.mediaFile,
    this.thumbnail,
    this.title,
    this.duration,
  });
}