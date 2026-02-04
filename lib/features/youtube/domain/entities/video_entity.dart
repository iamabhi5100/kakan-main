// lib/features/youtube/domain/entities/video_entity.dart

enum DownloadType { video, audio }

class VideoEntity {
  final String id;
  final String title;
  final String channelTitle;
  final int viewCount;
  final String? thumbnailUrl;
  final String? publishedDate;

  /// NEW: channel avatar thumbnail
  final String? channelAvatarUrl;

  VideoEntity({
    required this.id,
    required this.title,
    required this.channelTitle,
    required this.viewCount,
    this.thumbnailUrl,
    this.publishedDate,
    this.channelAvatarUrl,
  });
}
