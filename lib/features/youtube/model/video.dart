// lib/features/youtube/model/video.dart

import 'package:kakan/core/utils/text_sanitizer.dart';
import 'package:kakan/features/youtube/domain/entities/video_entity.dart';

class Video {
  final String videoId;
  final String title;
  final String channelTitle;
  final String viewCountTextRaw;
  final String thumbnailUrl;
  final String? publishedDate;

  /// NEW: parsed channel avatar url from API
  final String? channelAvatarUrl;

  Video({
    required this.videoId,
    required this.title,
    required this.channelTitle,
    required this.viewCountTextRaw,
    required this.thumbnailUrl,
    this.publishedDate,
    this.channelAvatarUrl,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    final id = (json['videoId'] ?? json['id'] ?? '').toString();

    final title = TextSanitizer.safe(json['title']?.toString() ?? '');
    final channel = TextSanitizer.safe(
      (json['channelTitle'] ??
              json['channelTitleSimple'] ??
              json['channel'] ??
              json['author'] ??
              '')
          .toString(),
    );

    final vc = (json['viewCountText'] ??
            json['viewCount'] ??
            json['shortViewCountText'] ??
            json['viewCountShort'] ??
            json['views'] ??
            '')
        .toString();

    final videoThumb = _extractFirstUrlFromListOrString(
      json,
      listKeys: const ['thumbnail', 'thumbnails'],
    );

    final channelAvatar = _extractFirstUrlFromListOrString(
      json,
      // RapidAPI shapes commonly use these keys for the author/channel avatar
      listKeys: const [
        'channelThumbnail',
        'channelThumbnails',
        'authorThumbnails',
        'channelAvatar',
      ],
      stringKeys: const ['channelThumbnailUrl', 'authorThumbnail'],
      preferMinWidth: 60, // try to pick something like s68 if present
    );

    return Video(
      videoId: id,
      title: title,
      channelTitle: channel,
      viewCountTextRaw: vc,
      thumbnailUrl: TextSanitizer.safe(videoThumb ?? ''),
      publishedDate:
          json['publishDate']?.toString() ?? json['publishedTimeText']?.toString(),
      channelAvatarUrl: TextSanitizer.safe(channelAvatar ?? ''),
    );
  }

  VideoEntity toEntity() => VideoEntity(
        id: videoId,
        title: title,
        channelTitle: channelTitle,
        viewCount: _parseViews(viewCountTextRaw),
        thumbnailUrl: thumbnailUrl.isEmpty ? null : thumbnailUrl,
        publishedDate: publishedDate,
        channelAvatarUrl:
            (channelAvatarUrl != null && channelAvatarUrl!.isNotEmpty)
                ? channelAvatarUrl
                : null,
      );

  /// Robust view-count parser
  int _parseViews(String text) {
    if (text.isEmpty) return 0;
    final lower = text.toLowerCase().trim();
    if (lower.contains('no views')) return 0;

    var t = lower.replaceAll('views', '').replaceAll(',', '').trim();

    final suffixMatch = RegExp(r'^([\d\.]+)\s*([kmb])$').firstMatch(t);
    if (suffixMatch != null) {
      final numStr = suffixMatch.group(1) ?? '0';
      final suffix = suffixMatch.group(2) ?? '';
      final base = double.tryParse(numStr) ?? 0.0;
      final mult = switch (suffix) {
        'k' => 1000,
        'm' => 1000000,
        'b' => 1000000000,
        _ => 1,
      };
      return (base * mult).round();
    }

    final digits = RegExp(r'(\d+)').firstMatch(t);
    if (digits != null) {
      return int.tryParse(digits.group(1)!) ?? 0;
    }

    return 0;
  }

  /// Picks a URL from a list of thumbnails (prefer width >= preferMinWidth).
  static String? _extractFirstUrlFromListOrString(
    Map<String, dynamic> json, {
    List<String> listKeys = const [],
    List<String> stringKeys = const [],
    int preferMinWidth = 0,
  }) {
    // try list-based keys first
    for (final key in listKeys) {
      final v = json[key];
      if (v is List && v.isNotEmpty) {
        try {
          // Each item usually: {url, width, height}
          final list = v.cast<Map>();
          // choose the first with width >= preferMinWidth, else first
          Map? chosen;
          if (preferMinWidth > 0) {
            for (final item in list) {
              final w = int.tryParse('${item['width'] ?? ''}') ?? 0;
              if (w >= preferMinWidth) {
                chosen = item;
                break;
              }
            }
          }
          chosen ??= list.first;
          final url = chosen['url']?.toString();
          if (url != null && url.isNotEmpty) return url;
        } catch (_) {
          // ignore and keep trying
        }
      }
    }

    // then try direct string keys
    for (final key in stringKeys) {
      final v = json[key];
      if (v is String && v.isNotEmpty) return v;
    }

    return null;
  }
}
