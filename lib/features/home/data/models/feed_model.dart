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
    required bool flagLiked,
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
          flagLiked: flagLiked,
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
      flagLiked: json['flag_liked'] ?? false,
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
      'flag_liked': flagLiked,
    };
  }
}

class UserProfileDetails {
  final String id;
  final String username;
  final String name;
  final String? profileImage;

  UserProfileDetails({
    required this.id,
    required this.username,
    required this.name,
    this.profileImage,
  });

  factory UserProfileDetails.fromJson(Map<String, dynamic> json) {
    return UserProfileDetails(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      profileImage: json['profile_image']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'profile_image': profileImage,
    };
  }
}