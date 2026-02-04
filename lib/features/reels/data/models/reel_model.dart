import 'package:kakan/features/reels/domain/entities/reel_entity.dart';

class ReelModel {
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

  /// Null-safe constructor (DO NOT use strict `as String`)
  factory ReelModel.fromJsonSafe(Map<String, dynamic> json) {
    final up = (json['user_profile_details'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ReelModel(
      id: (json['id'] ?? '').toString(),
      userProfileDetails: UserProfileDetailsModel.fromJsonSafe(up),
      created: (json['created'] ?? '').toString(),
      mediaType: (json['media_type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      caption: (json['caption'] ?? '').toString(),
      mediaFile: (json['media_file'] ?? '').toString(),
      thumbnail: json['thumbnail'] == null ? null : json['thumbnail'].toString(),
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
