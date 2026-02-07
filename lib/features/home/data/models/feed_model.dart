import 'package:kakan/config/constant_api.dart';
import 'package:kakan/features/home/model/entities/feed_entity.dart';

class FeedModel extends FeedEntity {
  /// Turns relative media paths (e.g. /media/media_posts/...) into full URLs.
  static String _resolveMediaUrl(String? path) {
    if (path == null || path.isEmpty) return path ?? '';
    final trimmed = path.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
    if (trimmed.startsWith('/')) return '${ConstantApi.baseUrl}$trimmed';
    return trimmed;
  }
  FeedModel({
    required String id,
    required UserProfileDetails userProfileDetails,
    required String created,
    required String mediaType,
    String? title,
    required String caption,
    required String mediaFile,
    String? thumbnail,
    List<FeedMediaItem>? mediaItems,
    required String privacy,
    required int likesCount,
    required int repostCount,
    required int commentsCount, // Added to constructor
    required bool flagLiked,
    required bool flagOwnPost,   // Added to constructor
  }) : super(
          id: id,
          userProfileDetails: userProfileDetails,
          created: created,
          mediaType: mediaType,
          title: title,
          caption: caption,
          mediaFile: mediaFile,
          thumbnail: thumbnail,
          mediaItems: mediaItems,
          privacy: privacy,
          likesCount: likesCount,
          repostCount: repostCount,
          commentsCount: commentsCount, // Pass to super
          flagLiked: flagLiked,
          flagOwnPost: flagOwnPost,     // Pass to super
        );

  factory FeedModel.fromJson(Map<String, dynamic> json) {
    final userProfileJson = json['user_profile_details'];
    final userProfileDetails = userProfileJson is Map<String, dynamic>
        ? UserProfileDetails.fromJson(userProfileJson)
        : UserProfileDetails(
            id: json['user_id']?.toString() ?? json['id']?.toString() ?? '',
            username: '',
            name: '',
            profileImage: null,
          );

    // API returns post with nested media[]; parse all for carousel, first for single
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
        thumbnail: (thumbRaw != null && thumbRaw.isNotEmpty) ? _resolveMediaUrl(thumbRaw) : null,
      ));
    }
    final postType = json['post_type']?.toString() ?? '';
    final firstMedia = mediaItemsList.isNotEmpty ? mediaItemsList.first : null;
    final mediaType = firstMedia?.type ?? json['media_type']?.toString() ?? postType;
    final mediaFile = firstMedia?.mediaFile ?? _resolveMediaUrl(json['media_file']?.toString() ?? '');
    final thumbnail = firstMedia?.thumbnail;

    return FeedModel(
      id: json['id']?.toString() ?? '',
      userProfileDetails: userProfileDetails,
      created: json['created']?.toString() ?? '',
      mediaType: mediaType,
      title: json['title']?.toString(),
      caption: json['caption']?.toString() ?? '',
      mediaFile: mediaFile,
      thumbnail: thumbnail,
      mediaItems: postType == 'carousel' && mediaItemsList.length > 1 ? mediaItemsList : null,
      privacy: json['privacy']?.toString() ?? '',
      likesCount: json['likes_count']?.toInt() ?? 0,
      repostCount: json['repost_count']?.toInt() ?? 0,
      commentsCount: json['comments_count']?.toInt() ?? 0,
      flagLiked: json['flag_liked'] ?? false,
      flagOwnPost: json['flag_own_post'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_profile_details': userProfileDetails.toJson(),
      'created': created,
      'media_type': mediaType,
      'title': title,
      'caption': caption,
      'media_file': mediaFile,
      'thumbnail': thumbnail,
      'privacy': privacy,
      'likes_count': likesCount,
      'repost_count': repostCount,
      'comments_count': commentsCount, // Added to JSON
      'flag_liked': flagLiked,
      'flag_own_post': flagOwnPost,     // Added to JSON
    };
  }
}