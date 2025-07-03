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

  ReelModel({
    required this.id,
    required this.userProfileDetails,
    required this.created,
    required this.mediaType,
    required this.title,
    required this.caption,
    required this.mediaFile,
    this.thumbnail,
    required this.privacy,
  });

  factory ReelModel.fromJson(Map<String, dynamic> json) {
    return ReelModel(
      id: json['id'] as String,
      userProfileDetails: UserProfileDetailsModel.fromJson(json['user_profile_details'] as Map<String, dynamic>),
      created: json['created'] as String,
      mediaType: json['media_type'] as String,
      title: json['title'] as String,
      caption: json['caption'] as String? ?? '',
      mediaFile: json['media_file'] as String,
      thumbnail: json['thumbnail'] as String?,
      privacy: json['privacy'] as String,
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
    );
  }
}

class UserProfileDetailsModel {
  final String id;
  final String username;
  final String name;
  final String profileImage;

  UserProfileDetailsModel({
    required this.id,
    required this.username,
    required this.name,
    required this.profileImage,
  });

  factory UserProfileDetailsModel.fromJson(Map<String, dynamic> json) {
    return UserProfileDetailsModel(
      id: json['id'] as String,
      username: json['username'] as String,
      name: json['name'] as String,
      profileImage: json['profile_image'] as String? ?? '',
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