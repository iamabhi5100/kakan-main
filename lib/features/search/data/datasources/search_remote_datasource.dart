import 'package:kakan/config/constant_api.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/network/api_service.dart';
import 'package:kakan/features/home/data/models/feed_model.dart';
import 'package:kakan/features/search/domain/entities/search_media_item.dart';
import '../models/search_result_model.dart';

abstract class SearchRemoteDataSource {
  Future<List<SearchResultModel>> searchPeople(String query);
  Future<List<SearchResultModel>> searchSongs(String query);
  Future<List<SearchResultModel>> searchVideos(String query);
}

class SearchRemoteDataSourceImpl implements SearchRemoteDataSource {
  final ApiService apiService;

  SearchRemoteDataSourceImpl(this.apiService);

  @override
  Future<List<SearchResultModel>> searchPeople(String query) async {
    try {
      final response = await apiService.get(
        ConstantApi.searchUsers.replaceFirst('%s', query),
        includeAuth: true,
      );
      final results = response['results'] as List<dynamic>;
      return results.map((json) => SearchResultModel.fromUserJson(json)).toList();
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<SearchResultModel>> searchSongs(String query) async {
    try {
      final response = await apiService.get(
        '/v${ConstantApi.apiVersion}/feeds/?search=$query',
        includeAuth: true,
      );
      if (response is! Map<String, dynamic> || !response.containsKey('results')) {
        throw ServerException(message: 'Invalid response format');
      }
      final resultsRaw = response['results'];
      final results = resultsRaw is List<dynamic> ? resultsRaw : <dynamic>[];
      final list = <SearchResultModel>[];
      for (final e in results) {
        if (e == null || e is! Map<String, dynamic>) continue;
        try {
          final feed = FeedModel.fromJson(e);
          if (feed.mediaType != 'audio') continue;
          // Use thumbnail when set; otherwise creator profile image for list display
          String? thumb = feed.thumbnail;
          if ((thumb == null || thumb.isEmpty) && feed.userProfileDetails.profileImage != null && feed.userProfileDetails.profileImage!.isNotEmpty) {
            thumb = feed.userProfileDetails.profileImage;
          }
          list.add(SearchResultModel(
            id: feed.id,
            username: feed.userProfileDetails.username,
            name: feed.title ?? feed.userProfileDetails.name,
            description: feed.caption,
            thumbnail: thumb,
            mediaFile: feed.mediaFile,
            mediaType: feed.mediaType,
            created: feed.created,
            likesCount: feed.likesCount,
            repostCount: feed.repostCount,
            flagLiked: feed.flagLiked,
            profileImage: feed.userProfileDetails.profileImage,
          ));
        } catch (_) {
          continue;
        }
      }
      return list;
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<SearchResultModel>> searchVideos(String query) async {
    try {
      final response = await apiService.get(
        '/v${ConstantApi.apiVersion}/feeds/?search=$query',
        includeAuth: true,
      );
      if (response is! Map<String, dynamic> || !response.containsKey('results')) {
        throw ServerException(message: 'Invalid response format');
      }
      final resultsRaw = response['results'];
      final results = resultsRaw is List<dynamic> ? resultsRaw : <dynamic>[];
      final list = <SearchResultModel>[];
      for (final e in results) {
        if (e == null || e is! Map<String, dynamic>) continue;
        try {
          final feed = FeedModel.fromJson(e);
          final isVideo = feed.mediaType == 'video';
          final isImage = feed.mediaType == 'image';
          final isCarousel = feed.mediaItems != null && feed.mediaItems!.isNotEmpty;
          if (!isVideo && !isImage && !isCarousel) continue;
          // Use thumbnail when set; for image use mediaFile; for carousel use first image
          String? thumb = feed.thumbnail;
          if ((thumb == null || thumb.isEmpty) && isImage && feed.mediaFile.isNotEmpty) {
            thumb = feed.mediaFile;
          } else if ((thumb == null || thumb.isEmpty) && feed.mediaItems != null) {
            for (final m in feed.mediaItems!) {
              if (m.type == 'image' && m.mediaFile.isNotEmpty) {
                thumb = m.mediaFile;
                break;
              }
            }
            if ((thumb == null || thumb.isEmpty) && feed.mediaItems!.isNotEmpty) {
              final first = feed.mediaItems!.first;
              if (first.thumbnail != null && first.thumbnail!.isNotEmpty) thumb = first.thumbnail;
            }
          }
          list.add(SearchResultModel(
            id: feed.id,
            username: feed.userProfileDetails.username,
            name: feed.title ?? feed.userProfileDetails.name,
            description: feed.caption,
            thumbnail: thumb,
            mediaFile: feed.mediaFile,
            mediaType: feed.mediaType,
            created: feed.created,
            likesCount: feed.likesCount,
            repostCount: feed.repostCount,
            flagLiked: feed.flagLiked,
            profileImage: feed.userProfileDetails.profileImage,
            mediaItems: feed.mediaItems
                ?.map((m) => SearchMediaItem(
                      type: m.type,
                      mediaFile: m.mediaFile,
                      thumbnail: m.thumbnail,
                    ))
                .toList(),
          ));
        } catch (_) {
          continue;
        }
      }
      return list;
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}