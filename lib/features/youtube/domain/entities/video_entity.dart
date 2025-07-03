// lib/features/youtube/domain/entities/video_entity.dart
enum DownloadType { video, audio }

// ... existing VideoEntity class ...
class VideoEntity {
  final String id;
  final String title;
  final String channelTitle;
  final int viewCount;
  final String? thumbnailUrl;
  final String? publishedDate;

  VideoEntity({
    required this.id,
    required this.title,
    required this.channelTitle,
    required this.viewCount,
    this.thumbnailUrl,
    this.publishedDate,
  });
}