
import 'package:kakan/features/youtube/domain/entities/video_entity.dart';
import 'package:kakan/features/youtube/model/video.dart';

class YoutubeHomeResponse {
  final List<Content> contents;

  YoutubeHomeResponse({required this.contents});

  factory YoutubeHomeResponse.fromJson(Map<String, dynamic> json) {
    var contentsList = json['contents'] as List? ?? [];
    List<Content> contents = contentsList
        .map((i) => Content.fromJson(i as Map<String, dynamic>))
        .toList();
    return YoutubeHomeResponse(contents: contents);
  }
}

class Content {
  final String type;
  final Video video;

  Content({required this.type, required this.video});

  factory Content.fromJson(Map<String, dynamic> json) {
    return Content(
      type: json['type'] as String? ?? '',
      video: Video.fromJson(json['video'] ?? {}),
    );
  }
}