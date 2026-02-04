// lib/features/youtube/model/youtube_home_model.dart

import 'package:kakan/features/youtube/model/video.dart';

class YoutubeHomeResponse {
  final List<Content> contents;

  YoutubeHomeResponse({required this.contents});

  factory YoutubeHomeResponse.fromJson(Map<String, dynamic> json) {
    final contentsList = (json['data'] as List?) ?? [];
    final contents = contentsList
        .map((i) => Content.fromJson((i as Map).cast<String, dynamic>()))
        .toList();
    return YoutubeHomeResponse(contents: contents);
  }
}

class Content {
  final String type;
  final Video? video;
  final List<Short>? shorts;
  final String? title;
  final String? subtitle;

  Content({
    required this.type,
    this.video,
    this.shorts,
    this.title,
    this.subtitle,
  });

  factory Content.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] as String? ?? '').toString();

    if (type == 'shorts_listing') {
      final dataList = (json['data'] as List?) ?? const [];
      final shorts =
          dataList.map((i) => Short.fromJson((i as Map).cast<String, dynamic>())).toList();
      return Content(
        type: type,
        shorts: shorts,
        title: json['title']?.toString(),
        subtitle: json['subtitle']?.toString(),
      );
    }

    return Content(
      type: type.isEmpty ? 'video' : type,
      video: Video.fromJson(json),
    );
  }
}

class Short {
  final String videoId;
  final String title;
  final String viewCountText;
  final List<Map<String, dynamic>> thumbnail;
  final bool isOriginalAspectRatio;
  final String params;
  final String playerParams;
  final String sequenceParams;

  Short({
    required this.videoId,
    required this.title,
    required this.viewCountText,
    required this.thumbnail,
    required this.isOriginalAspectRatio,
    required this.params,
    required this.playerParams,
    required this.sequenceParams,
  });

  factory Short.fromJson(Map<String, dynamic> json) {
    return Short(
      videoId: (json['videoId'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      viewCountText:
          (json['viewCountText'] ?? json['viewCount'] ?? json['shortViewCountText'] ?? '')
              .toString(),
      thumbnail: ((json['thumbnail'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      isOriginalAspectRatio: (json['isOriginalAspectRatio'] ?? false) == true,
      params: (json['params'] ?? '').toString(),
      playerParams: (json['playerParams'] ?? '').toString(),
      sequenceParams: (json['sequenceParams'] ?? '').toString(),
    );
  }
}
