import 'package:flutter/foundation.dart';
import 'package:kakan/features/home/model/entities/feed_entity.dart';
import 'package:kakan/features/profile/domain/entities/profile_post_entity.dart';

class ProfilePostModel extends ProfilePostEntity {
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
    required int commentsCount, // Added to constructor
    required bool flagLiked,
    required bool flagOwnPost, // Added to constructor
    required String userId,
    required UserProfileDetails userProfileDetails,
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
        );

  factory ProfilePostModel.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) {
      print('DEBUG: Parsing ProfilePostModel from JSON: $json');
    }
    return ProfilePostModel(
      id: json['id']?.toString() ?? '',
      caption: json['caption']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      thumbnail: json['thumbnail']?.toString(),
      mediaFile: json['media_file']?.toString(),
      mediaType: json['media_type']?.toString() ?? '',
      created: json['created']?.toString() ?? '',
      likesCount: json['likes_count']?.toInt() ?? 0,
      repostCount: json['repost_count']?.toInt() ?? 0,
      commentsCount: json['comments_count']?.toInt() ?? 0, // Mapped from JSON
      flagLiked: json['flag_liked'] ?? false,
      flagOwnPost: json['flag_own_post'] ?? false, // Mapped from JSON
      userId: json['user']?.toString() ?? '',
      userProfileDetails: json['user_profile_details'] != null
          ? UserProfileDetails.fromJson(json['user_profile_details'])
          : UserProfileDetails(
              id: '',
              username: json['user']?.toString() ?? 'unknown',
              name: 'Unknown User',
              profileImage: null,
            ),
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