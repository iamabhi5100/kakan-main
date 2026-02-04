import 'package:equatable/equatable.dart';

class ReelEntity extends Equatable {
  final String id;
  final UserProfileDetailsEntity userProfileDetails;
  final String created;
  final String mediaType;
  final String title;
  final String caption;
  final String mediaFile;
  final String? thumbnail;
  final String privacy;
  final bool isLiked;
  final int likesCount;
  final int repostCount;
  final int commentsCount;

  const ReelEntity({
    required this.id,
    required this.userProfileDetails,
    required this.created,
    required this.mediaType,
    required this.title,
    required this.caption,
    required this.mediaFile,
    this.thumbnail,
    required this.privacy,
    this.isLiked = false,
    this.likesCount = 0,
    this.repostCount = 0,
    this.commentsCount = 0,
  });

  ReelEntity copyWith({
    String? id,
    UserProfileDetailsEntity? userProfileDetails,
    String? created,
    String? mediaType,
    String? title,
    String? caption,
    String? mediaFile,
    String? thumbnail,
    String? privacy,
    bool? isLiked,
    int? likesCount,
    int? repostCount,
    int? commentsCount,
  }) {
    return ReelEntity(
      id: id ?? this.id,
      userProfileDetails: userProfileDetails ?? this.userProfileDetails,
      created: created ?? this.created,
      mediaType: mediaType ?? this.mediaType,
      title: title ?? this.title,
      caption: caption ?? this.caption,
      mediaFile: mediaFile ?? this.mediaFile,
      thumbnail: thumbnail ?? this.thumbnail,
      privacy: privacy ?? this.privacy,
      isLiked: isLiked ?? this.isLiked,
      likesCount: likesCount ?? this.likesCount,
      repostCount: repostCount ?? this.repostCount,
      commentsCount: commentsCount ?? this.commentsCount,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userProfileDetails,
        created,
        mediaType,
        title,
        caption,
        mediaFile,
        thumbnail,
        privacy,
        isLiked,
        likesCount,
        repostCount,
        commentsCount,
      ];
}

class UserProfileDetailsEntity extends Equatable {
  final String id;
  final String username;
  final String name;
  final String profileImage;

  const UserProfileDetailsEntity({
    required this.id,
    required this.username,
    required this.name,
    required this.profileImage,
  });

  @override
  List<Object> get props => [id, username, name, profileImage];
}