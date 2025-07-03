
import 'package:kakan/features/youtube/domain/entities/video_entity.dart';

/// Model representing a YouTube video from the API.
class Video {
  final String videoId;
  final String title;
  final String channelTitle;
  final String viewCount;
  final String thumbnailUrl;

  Video({
    required this.videoId,
    required this.title,
    required this.channelTitle,
    required this.viewCount,
    required this.thumbnailUrl,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      videoId: json['videoId'] ?? '',
      title: json['title'] ?? '',
      thumbnailUrl: json['thumbnails'] != null && json['thumbnails'].isNotEmpty
          ? json['thumbnails'][0]['url'] ?? ''
          : '',
      channelTitle: json['author']?['title'] ?? json['channelTitle'] ?? '',
      viewCount: json['stats']?['views']?.toString() ?? '0',
    );
  }

  /// Converts the model to a domain entity.
  VideoEntity toEntity() => VideoEntity(
        id: videoId,
        title: title,
        channelTitle: channelTitle,
        viewCount: int.tryParse(viewCount) ?? 0,
        thumbnailUrl: thumbnailUrl,
        publishedDate: null,
      );
}