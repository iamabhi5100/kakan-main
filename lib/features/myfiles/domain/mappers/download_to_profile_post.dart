import 'package:kakan/features/home/model/entities/feed_entity.dart';
import 'package:kakan/features/myfiles/domain/entities/download_entity.dart';
import 'package:kakan/features/profile/domain/entities/profile_post_entity.dart';

/// Builds a [ProfilePostEntity] from a [DownloadEntity] so My Files items
/// can be shown in [VideoFeedWidget] / [AudioFeedWidget].
ProfilePostEntity profilePostFromDownload(DownloadEntity d) {
  const myFilesUserId = 'myfiles';
  final userProfileDetails = UserProfileDetails(
    id: myFilesUserId,
    username: 'myfiles',
    name: 'My Files',
    profileImage: null,
  );
  return ProfilePostEntity(
    id: d.id,
    caption: d.title ?? '',
    title: d.title ?? (d.mediaType == 'video' ? 'Untitled Video' : 'Untitled Audio'),
    thumbnail: d.thumbnail,
    mediaFile: d.mediaFile,
    mediaType: d.mediaType,
    created: d.created,
    likesCount: 0,
    repostCount: 0,
    commentsCount: 0,
    flagLiked: false,
    flagOwnPost: true,
    userId: myFilesUserId,
    userProfileDetails: userProfileDetails,
    mediaItems: null,
  );
}
