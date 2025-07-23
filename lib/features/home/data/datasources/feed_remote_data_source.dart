import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:kakan/config/constant_api.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/network/api_service.dart';
import 'package:kakan/features/home/data/models/feed_model.dart';
import 'package:kakan/core/utils/session_manager.dart';
import 'package:kakan/injection_container.dart' as di;

abstract class FeedRemoteDataSource {
  Future<List<FeedModel>> getFeeds();
  Future<void> likeDislikePost(String postId);
  Future<String> repost({
    required String postId,
    required String title,
    required String caption,
  });
  Future<void> deleteFeed(String feedId);
}

class FeedRemoteDataSourceImpl implements FeedRemoteDataSource {
  final ApiService apiService;
  final DefaultCacheManager cacheManager;
  final SessionManager sessionManager = di.sl<SessionManager>();
  final Dio _dio = Dio(); // For downloading media file

  FeedRemoteDataSourceImpl({
    required this.apiService,
    required this.cacheManager,
  });

  @override
  Future<List<FeedModel>> getFeeds() async {
    try {
      final response = await apiService.get(
        '/v${ConstantApi.apiVersion}/feeds/',
        includeAuth: true,
      );
      if (response is Map<String, dynamic> && response.containsKey('results')) {
        final results = response['results'] as List<dynamic>;
        return results.map((json) => FeedModel.fromJson(json)).toList();
      } else {
        throw ServerException(message: 'Invalid response format');
      }
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> likeDislikePost(String postId) async {
    try {
      final formData = FormData.fromMap({}); // Empty form-data as per API spec
      await apiService.post(
        '/v${ConstantApi.apiVersion}/posts/$postId/like-dislike-post/',
        formData,
        includeAuth: true,
      );
      await cacheManager.removeFile('/v${ConstantApi.apiVersion}/feeds/');
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        throw ServerException(message: 'Post not found: $postId');
      }
      throw ServerException(message: 'Failed to like/dislike post: $e');
    }
  }

  @override
  Future<String> repost({
    required String postId,
    required String title,
    required String caption,
  }) async {
    try {
      // Fetch feed details to get media_file, thumbnail, and media_type
      final feedResponse = await apiService.get(
        '/v${ConstantApi.apiVersion}/feeds/',
        includeAuth: true,
      );
      if (feedResponse is! Map<String, dynamic> || feedResponse['results'] == null) {
        throw ServerException(message: 'Invalid feed data format');
      }

      final feeds = (feedResponse['results'] as List<dynamic>)
          .map((json) => FeedModel.fromJson(json as Map<String, dynamic>))
          .toList();
      final feed = feeds.firstWhere(
        (f) => f.id == postId,
        orElse: () => throw ServerException(message: 'Feed not found: $postId'),
      );

      // Determine media_type based on media_file extension
      String mediaType = feed.mediaType ?? 'text';
      if (feed.mediaFile != null && feed.mediaFile!.isNotEmpty) {
        final extension = feed.mediaFile!.toLowerCase().split('.').last;
        if (['mp4', 'mov', 'avi'].contains(extension)) {
          mediaType = 'video';
        } else if (['jpg', 'jpeg', 'png'].contains(extension)) {
          mediaType = 'image';
        } else if (['mp3', 'wav'].contains(extension)) {
          mediaType = 'audio';
        }
      }

      // Prepare form-data for repost
      final formData = FormData.fromMap({
        'media_type': mediaType,
        'title': title.isNotEmpty ? 'Repost of $title' : 'Repost of ${postId.substring(0, 8)}',
        'caption': caption.isNotEmpty ? 'Reposting: $caption' : 'Reposting post $postId',
      });

      // Download and include media_file if available
      if (feed.mediaFile != null && feed.mediaFile!.isNotEmpty) {
        try {
          final response = await _dio.get(
            feed.mediaFile!,
            options: Options(responseType: ResponseType.bytes),
          );
          final fileName = feed.mediaFile!.split('/').last;
          formData.files.add(MapEntry(
            'media_file',
            MultipartFile.fromBytes(
              response.data as List<int>,
              filename: fileName,
            ),
          ));
        } catch (e) {
          throw ServerException(message: 'Failed to download media file: $e');
        }
      }

      // Download and include thumbnail if available
      if (feed.thumbnail != null && feed.thumbnail!.isNotEmpty) {
        try {
          final response = await _dio.get(
            feed.thumbnail!,
            options: Options(responseType: ResponseType.bytes),
          );
          final fileName = feed.thumbnail!.split('/').last;
          formData.files.add(MapEntry(
            'thumbnail',
            MultipartFile.fromBytes(
              response.data as List<int>,
              filename: fileName,
            ),
          ));
        } catch (e) {
          throw ServerException(message: 'Failed to download thumbnail: $e');
        }
      }

      // Log the FormData for debugging
      if (kDebugMode) {
        print('Repost payload for postId $postId:');
        print('FormData fields: ${formData.fields}');
        print('FormData files: ${formData.files.map((e) => e.key).toList()}');
      }

      // Send the repost request
      final response = await apiService.post(
        '/v${ConstantApi.apiVersion}/posts/$postId/repost/',
        formData,
        includeAuth: true,
      );

      // Clear cache
      await cacheManager.removeFile('/v${ConstantApi.apiVersion}/feeds/');

      // Validate and return post_id
      if (response is Map<String, dynamic> && response.containsKey('post_id')) {
        return response['post_id'] as String;
      } else {
        throw ServerException(message: 'Invalid response format');
      }
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 404) {
          throw ServerException(message: 'Post not found for repost: $postId');
        } else if (e.response?.statusCode == 400) {
          throw ServerException(message: 'Invalid request: ${e.response?.data.toString() ?? e.message}');
        } else if (e.response?.statusCode == 403) {
          throw ServerException(message: 'Forbidden: You lack permission to repost this feed');
        }
      }
      throw ServerException(message: 'Failed to repost: $e');
    }
  }

  @override
  Future<void> deleteFeed(String feedId) async {
    try {
      await apiService.delete(
        '/v${ConstantApi.apiVersion}/posts/$feedId/',
        includeAuth: true,
      );
      await cacheManager.removeFile('/v${ConstantApi.apiVersion}/feeds/');
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 404) {
          throw ServerException(message: 'Feed not found: $feedId');
        } else if (e.response?.statusCode == 403) {
          throw ServerException(message: 'Forbidden: You lack permission to delete this feed');
        }
      }
      throw ServerException(message: 'Failed to delete feed: $e');
    }
  }
}