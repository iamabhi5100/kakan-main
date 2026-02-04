// lib/features/search/data/models/search_result_model.dart

import '../../domain/entities/search_result.dart';

class SearchResultModel extends SearchResult {
  const SearchResultModel({
    required String id,
    String? username,
    String? name,
    String? description,
    String? thumbnail,
    String? mediaFile,
    String? mediaType,
    String? created,
    int? likesCount,
    int? repostCount,
    bool? flagLiked,
    String? profileImage,
    int? followersCount,
    bool? isFollowed,
  }) : super(
          id: id,
          username: username,
          name: name,
          description: description,
          thumbnail: thumbnail,
          mediaFile: mediaFile,
          mediaType: mediaType,
          created: created,
          likesCount: likesCount,
          repostCount: repostCount,
          flagLiked: flagLiked,
          profileImage: profileImage,
          followersCount: followersCount,
          isFollowed: isFollowed,
        );

  /// When you get a `/v1/user/` result
  factory SearchResultModel.fromUserJson(Map<String, dynamic> json) {
    return SearchResultModel(
      id: json['id'] as String,
      username: json['username'] as String?,
      name: json['name'] as String? ?? json['username'] as String?,
      profileImage: json['profile_image'] as String?,
      followersCount: json['followers_count'] as int?,
      isFollowed: json['is_followed'] as bool?,
      // we leave all media‐related fields null
    );
  }

  /// When you get a `/v1/posts/` result
  factory SearchResultModel.fromPostJson(Map<String, dynamic> json) {
    return SearchResultModel(
      id: json['id'] as String,
      name: (json['title'] as String?) ?? '',
      description: json['caption'] as String?,
      thumbnail: json['thumbnail'] as String?,
      mediaFile: json['media_file'] as String?,
      mediaType: json['media_type'] as String?,
      created: json['created'] as String?,
      likesCount: json['likes_count'] as int?,
      repostCount: json['repost_count'] as int?,
      flagLiked: json['flag_liked'] as bool?,
      // people‐fields stay null
    );
  }
}
