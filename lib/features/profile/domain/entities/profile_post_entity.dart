import 'package:kakan/features/home/model/entities/feed_entity.dart';

class ProfilePostEntity {
  final String id;
  final String caption;
  final String title;
  final String? thumbnail;
  final String? mediaFile;
  final String mediaType;
  final String created;
  final int likesCount;
  final int repostCount;
  final int commentsCount; // New field
  final bool flagLiked;
  final bool flagOwnPost; // New field
  final String userId;
  final UserProfileDetails userProfileDetails;

  ProfilePostEntity({
    required this.id,
    required this.caption,
    required this.title,
    this.thumbnail,
    this.mediaFile,
    required this.mediaType,
    required this.created,
    required this.likesCount,
    required this.repostCount,
    required this.commentsCount, // Added to constructor
    required this.flagLiked,
    required this.flagOwnPost, // Added to constructor
    required this.userId,
    required this.userProfileDetails,
  });
}