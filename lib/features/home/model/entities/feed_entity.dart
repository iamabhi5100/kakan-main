class FeedEntity {
  final String id;
  final UserProfileDetails userProfileDetails;
  final String created;
  final String mediaType;
  final String? title;
  final String caption;
  final String mediaFile;
  final String? thumbnail;
  final String privacy;
  final int likesCount;
  final int repostCount;
  final int commentsCount; // New field
  final bool flagLiked;
  final bool flagOwnPost;   // New field

  FeedEntity({
    required this.id,
    required this.userProfileDetails,
    required this.created,
    required this.mediaType,
    this.title,
    required this.caption,
    required this.mediaFile,
    this.thumbnail,
    required this.privacy,
    required this.likesCount,
    required this.repostCount,
    required this.commentsCount, // Added to constructor
    required this.flagLiked,
    required this.flagOwnPost,   // Added to constructor
  });
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

class CommentEntity {
  final String id;
  final String created;
  final String content;
  final String userProfileId;
  final String postId;
  final UserProfileDetails userProfileDetails;

  CommentEntity({
    required this.id,
    required this.created,
    required this.content,
    required this.userProfileId,
    required this.postId,
    required this.userProfileDetails,
  });
}