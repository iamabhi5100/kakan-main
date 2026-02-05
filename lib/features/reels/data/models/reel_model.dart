import 'package:kakan/config/constant_api.dart';
import 'package:kakan/features/reels/domain/entities/reel_entity.dart';

class ReelModel {
  static String _resolveMediaUrl(String? path) {
    if (path == null || path.isEmpty) return path ?? '';
    final trimmed = path.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
    if (trimmed.startsWith('/')) return '${ConstantApi.baseUrl}$trimmed';
    return trimmed;
  }
  final String id;
  final UserProfileDetailsModel userProfileDetails;
  final String created;
  final String mediaType;
  final String title;
  final String caption;
  final String mediaFile;
  final String? thumbnail;
  final String privacy;
  final int likesCount;
  final int repostCount;
  final int commentsCount;
  final bool flagLiked;

  ReelModel({
    required this.id,
    required this.userProfileDetails,
    required this.created,
    required this.mediaType,
    required this.title,
    required this.caption,
    required this.mediaFile,
    required this.thumbnail,
    required this.privacy,
    required this.likesCount,
    required this.repostCount,
    required this.commentsCount,
    required this.flagLiked,
  });

  /// Null-safe constructor. Supports feeds/trims API shape: post with nested media[].
  factory ReelModel.fromJsonSafe(Map<String, dynamic> json) {
    final up = (json['user_profile_details'] as Map?)?.cast<String, dynamic>() ?? const {};
    // API returns media[]; take first item for media_file, media_type, thumbnail
    final mediaList = json['media'];
    final rawList = mediaList is List<dynamic> ? mediaList : <dynamic>[];
    dynamic firstMedia;
    if (rawList.isNotEmpty && rawList.first is Map<String, dynamic>) {
      firstMedia = rawList.first as Map<String, dynamic>;
    }
    final mediaFileRaw = firstMedia != null
        ? (firstMedia['media_file'] ?? '').toString()
        : (json['media_file'] ?? '').toString();
    final mediaFile = _resolveMediaUrl(mediaFileRaw);
    final mediaType = firstMedia != null
        ? (firstMedia['media_type'] ?? json['post_type'] ?? '').toString()
        : (json['media_type'] ?? json['post_type'] ?? '').toString();
    final thumbRaw = firstMedia != null
        ? firstMedia['thumbnail']?.toString()
        : json['thumbnail']?.toString();
    final thumbnail = (thumbRaw != null && thumbRaw.toString().trim().isNotEmpty)
        ? _resolveMediaUrl(thumbRaw)
        : null;

    return ReelModel(
      id: (json['id'] ?? '').toString(),
      userProfileDetails: UserProfileDetailsModel.fromJsonSafe(up),
      created: (json['created'] ?? '').toString(),
      mediaType: mediaType,
      title: (json['title'] ?? '').toString(),
      caption: (json['caption'] ?? '').toString(),
      mediaFile: mediaFile,
      thumbnail: thumbnail,
      privacy: (json['privacy'] ?? '').toString(),
      likesCount: _safeInt(json['likes_count']),
      repostCount: _safeInt(json['repost_count']),
      commentsCount: _safeInt(json['comments_count']),
      flagLiked: (json['flag_liked'] is bool) ? json['flag_liked'] as bool : false,
    );
  }

  ReelEntity toEntity() {
    return ReelEntity(
      id: id,
      userProfileDetails: userProfileDetails.toEntity(),
      created: created,
      mediaType: mediaType,
      title: title,
      caption: caption,
      mediaFile: mediaFile,
      thumbnail: thumbnail,
      privacy: privacy,
      isLiked: flagLiked,
      likesCount: likesCount,
      repostCount: repostCount,
      commentsCount: commentsCount,
    );
  }

  static int _safeInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

class UserProfileDetailsModel {
  final String id;
  final String username;
  final String name;
  final String profileImage; // keep non-null for entity

  UserProfileDetailsModel({
    required this.id,
    required this.username,
    required this.name,
    required this.profileImage,
  });

  factory UserProfileDetailsModel.fromJsonSafe(Map<String, dynamic> json) {
    return UserProfileDetailsModel(
      id: (json['id'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      profileImage: (json['profile_image'] ?? '').toString(),
    );
  }

  UserProfileDetailsEntity toEntity() {
    return UserProfileDetailsEntity(
      id: id,
      username: username,
      name: name,
      profileImage: profileImage,
    );
    }
}
