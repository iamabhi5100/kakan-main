import 'package:flutter/foundation.dart';
import 'package:kakan/features/home/data/models/feed_model.dart';
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
    required bool flagLiked,
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
          flagLiked: flagLiked,
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
      flagLiked: json['flag_liked'] ?? false,
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
      'flag_liked': flagLiked,
      'user': userId,
      'user_profile_details': userProfileDetails.toJson(),
    };
  }
}