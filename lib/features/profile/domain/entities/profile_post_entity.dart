import 'package:kakan/features/home/data/models/feed_model.dart';
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
  final bool flagLiked;
  final String userId; // Added for fetching user details
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
    required this.flagLiked,
    required this.userId,
    required this.userProfileDetails,
  });
}
