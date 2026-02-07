import 'package:flutter/foundation.dart';
import 'package:kakan/config/constant_api.dart';
import 'package:kakan/features/home/model/entities/feed_entity.dart';
import 'package:kakan/features/profile/domain/entities/profile_post_entity.dart';

class ProfilePostModel extends ProfilePostEntity {
  /// API post_type (audio | video | image | carousel | text); used for tab filtering.
  final String postType;

  ProfilePostModel({
    required String id,
    required String caption,
    required String title,
    String? thumbnail,
    String? mediaFile,
    required String mediaType,
    required String created,
    required int likesCount,
    required int repostCount,
    required int commentsCount,
    required bool flagLiked,
    required bool flagOwnPost,
    required String userId,
    required UserProfileDetails userProfileDetails,
    required this.postType,
    List<FeedMediaItem>? mediaItems,
  }) : super(
          id: id,
          caption: caption,
          title: title,
          thumbnail: thumbnail,
          mediaFile: mediaFile,
          mediaType: mediaType,
          created: created,
          likesCount: likesCount,
          repostCount: repostCount,
          commentsCount: commentsCount, // Pass to super
          flagLiked: flagLiked,
          flagOwnPost: flagOwnPost,   // Pass to super
          userId: userId,
          userProfileDetails: userProfileDetails,
          mediaItems: mediaItems,
        );

  static String _resolveMediaUrl(String? path) {
    if (path == null || path.isEmpty) return path ?? '';
    final t = path.trim();
    if (t.startsWith('http://') || t.startsWith('https://')) return t;
    if (t.startsWith('/')) return '${ConstantApi.baseUrl}$t';
    return t;
  }

  factory ProfilePostModel.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) {
      print('DEBUG: Parsing ProfilePostModel from JSON: $json');
    }
    final postType = json['post_type']?.toString() ?? '';
    final userProfileJson = json['user_profile_details'];
    final userProfileDetails = userProfileJson is Map<String, dynamic>
        ? UserProfileDetails.fromJson(userProfileJson)
        : UserProfileDetails(
            id: json['user']?.toString() ?? '',
            username: 'unknown',
            name: 'Unknown User',
            profileImage: null,
          );
    final userId = userProfileDetails.id.isNotEmpty
        ? userProfileDetails.id
        : (json['user']?.toString() ?? '');

    final mediaList = json['media'];
    final rawList = mediaList is List<dynamic> ? mediaList : <dynamic>[];
    final mediaItemsList = <FeedMediaItem>[];
    for (final m in rawList) {
      if (m is! Map<String, dynamic>) continue;
      final type = m['media_type']?.toString() ?? 'image';
      final fileRaw = m['media_file']?.toString() ?? '';
      final file = _resolveMediaUrl(fileRaw);
      if (file.isEmpty) continue;
      final thumbRaw = m['thumbnail']?.toString();
      mediaItemsList.add(FeedMediaItem(
        type: type,
        mediaFile: file,
        thumbnail: thumbRaw != null && thumbRaw.isNotEmpty ? _resolveMediaUrl(thumbRaw) : null,
      ));
    }
    dynamic firstMedia;
    if (rawList.isNotEmpty && rawList.first is Map<String, dynamic>) {
      firstMedia = rawList.first as Map<String, dynamic>;
    }
    final mediaType = firstMedia != null
        ? (firstMedia['media_type'] ?? postType).toString()
        : (mediaItemsList.isNotEmpty ? mediaItemsList.first.type : postType);
    // API user-posts often returns media_file: null; backend should include it (like /feeds/) for playback
    final mediaFileRaw = (firstMedia != null ? firstMedia['media_file']?.toString() : null) ??
        json['media_file']?.toString();
    final mediaFile = mediaFileRaw != null && mediaFileRaw.toString().trim().isNotEmpty
        ? _resolveMediaUrl(mediaFileRaw.toString().trim())
        : (mediaItemsList.isNotEmpty ? mediaItemsList.first.mediaFile : null);
    final thumbRaw = firstMedia != null
        ? firstMedia['thumbnail']?.toString()
        : json['thumbnail']?.toString();
    final thumbnail = thumbRaw != null && thumbRaw.isNotEmpty
        ? _resolveMediaUrl(thumbRaw)
        : (mediaItemsList.isNotEmpty ? mediaItemsList.first.thumbnail : null);

    final carouselItems = (postType == 'carousel' && mediaItemsList.length > 1) ? mediaItemsList : null;

    return ProfilePostModel(
      id: json['id']?.toString() ?? '',
      caption: json['caption']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      thumbnail: thumbnail,
      mediaFile: mediaFile,
      mediaType: mediaType.isNotEmpty ? mediaType : postType,
      created: json['created']?.toString() ?? '',
      likesCount: json['likes_count']?.toInt() ?? 0,
      repostCount: json['repost_count']?.toInt() ?? 0,
      commentsCount: json['comments_count']?.toInt() ?? 0,
      flagLiked: json['flag_liked'] ?? false,
      flagOwnPost: json['flag_own_post'] ?? false,
      userId: userId,
      userProfileDetails: userProfileDetails,
      postType: postType,
      mediaItems: carouselItems,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'caption': caption,
      'title': title,
      'thumbnail': thumbnail,
      'media_file': mediaFile,
      'media_type': mediaType,
      'created': created,
      'likes_count': likesCount,
      'repost_count': repostCount,
      'comments_count': commentsCount, // Added to JSON serialization
      'flag_liked': flagLiked,
      'flag_own_post': flagOwnPost, // Added to JSON serialization
      'user': userId,
      'user_profile_details': userProfileDetails.toJson(),
    };
  }
}