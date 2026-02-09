// lib/features/search/domain/entities/search_result.dart

import 'search_media_item.dart';

class SearchResult {
  final String id;
  final String? username;      // for people or post author
  final String? name;          // full name (people) or title (media)
  final String? description;   // post caption, song/video description
  final String? thumbnail;     // preview image URL
  final String? mediaFile;     // audio/video file URL
  final String? mediaType;     // "audio" | "video" | "image" | "carousel"
  final String? created;       // timestamp from API, e.g. "30/06/2025, 01:04 PM"
  final int? likesCount;
  final int? repostCount;
  final bool? flagLiked;
  final String? profileImage;  // people-only avatar
  final int? followersCount;   // people-only follower count
  final bool? isFollowed;      // people-only follow flag
  /// For carousel posts, all media in order; null for single-media.
  final List<SearchMediaItem>? mediaItems;

  const SearchResult({
    required this.id,
    this.username,
    this.name,
    this.description,
    this.thumbnail,
    this.mediaFile,
    this.mediaType,
    this.created,
    this.likesCount,
    this.repostCount,
    this.flagLiked,
    this.profileImage,
    this.followersCount,
    this.isFollowed,
    this.mediaItems,
  });
}
