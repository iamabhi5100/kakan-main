import 'package:kakan/features/home/data/models/feed_model.dart';

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
  final bool flagLiked;

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
    required this.flagLiked,
  });
}