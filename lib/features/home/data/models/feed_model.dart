import 'package:kakan/features/home/model/entities/feed_entity.dart';

class FeedModel extends FeedEntity {
  FeedModel({
    required String id,
    required UserProfileDetails userProfileDetails,
    required String created,
    required String mediaType,
    String? title,
    required String caption,
    required String mediaFile,
    String? thumbnail,
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
          privacy: privacy,
          likesCount: likesCount,
          repostCount: repostCount,
          commentsCount: commentsCount, // Pass to super
          flagLiked: flagLiked,
          flagOwnPost: flagOwnPost,     // Pass to super
        );

  factory FeedModel.fromJson(Map<String, dynamic> json) {
    return FeedModel(
      id: json['id']?.toString() ?? '',
      userProfileDetails: UserProfileDetails.fromJson(json['user_profile_details']),
      created: json['created']?.toString() ?? '',
      mediaType: json['media_type']?.toString() ?? '',
      title: json['title']?.toString(),
      caption: json['caption']?.toString() ?? '',
      mediaFile: json['media_file']?.toString() ?? '',
      thumbnail: json['thumbnail']?.toString(),
      privacy: json['privacy']?.toString() ?? '',
      likesCount: json['likes_count']?.toInt() ?? 0,
      repostCount: json['repost_count']?.toInt() ?? 0,
      commentsCount: json['comments_count']?.toInt() ?? 0, // Mapped from JSON
      flagLiked: json['flag_liked'] ?? false,
      flagOwnPost: json['flag_own_post'] ?? false,         // Mapped from JSON
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