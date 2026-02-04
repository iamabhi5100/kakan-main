import 'package:dio/dio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:kakan/config/constant_api.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/network/api_service.dart';
import 'package:kakan/core/utils/session_manager.dart';
import 'package:kakan/features/home/data/models/comment_model.dart';
import 'package:kakan/features/home/data/models/feed_model.dart';
import 'package:kakan/injection_container.dart' as di;

abstract class FeedRemoteDataSource {
  /// Reels-style: returns {'results': List<FeedModel>, 'next': String?, 'count': int}
  Future<Map<String, dynamic>> getFeeds({String? nextUrl, int pageSize = 10});

  Future<void> likeDislikePost(String postId);

  /// Returns the **new post id** that was created by the backend.
  Future<String> repost({
    required String postId,
    required String title,
    required String caption,
  });

  Future<void> deleteFeed(String feedId);

  Future<void> addComment(String postId, String content);
  Future<List<CommentModel>> getComments(String postId);
  Future<void> deleteComment(String commentId);
}

class FeedRemoteDataSourceImpl implements FeedRemoteDataSource {
  final ApiService apiService;
  final DefaultCacheManager cacheManager;
  final SessionManager sessionManager = di.sl<SessionManager>();

  FeedRemoteDataSourceImpl({
    required this.apiService,
    required this.cacheManager,
  });

  @override
  Future<Map<String, dynamic>> getFeeds({String? nextUrl, int pageSize = 10}) async {
    try {
      final String url = nextUrl ?? '/v${ConstantApi.apiVersion}/feeds/?page_size=$pageSize';
      final response = await apiService.get(url, includeAuth: true);

      if (response is Map<String, dynamic> && response.containsKey('results')) {
        final results = response['results'] as List<dynamic>;
        final list = results
            .map((json) => FeedModel.fromJson(json as Map<String, dynamic>))
            .toList();
        return {
          'results': list,
          'next': response['next'],
          'count': response['count'] ?? list.length,
        };
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
      final formData = FormData.fromMap({});
      await apiService.post(
        '/v${ConstantApi.apiVersion}/posts/$postId/like-dislike-post/',
        formData,
        includeAuth: true,
      );
      // Best-effort cache bust
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
      // ✅ IMPORTANT: Most backends expect only title/caption on a repost endpoint.
      // No media re-upload. Keep it simple (this was breaking earlier).
      final formData = FormData.fromMap({
        'title': title,
        'caption': caption,
      });

      final response = await apiService.post(
        '/v${ConstantApi.apiVersion}/posts/$postId/repost/',
        formData,
        includeAuth: true,
      );

      // Best-effort cache bust
      await cacheManager.removeFile('/v${ConstantApi.apiVersion}/feeds/');

      if (response is Map<String, dynamic>) {
        if (response['post_id'] != null) return response['post_id'].toString();
        if (response['id'] != null) return response['id'].toString();
      }
      throw ServerException(message: 'Invalid response format');
    } catch (e) {
      if (e is DioException) {
        final code = e.response?.statusCode;
        if (code == 404) {
          throw ServerException(message: 'Post not found for repost: $postId');
        } else if (code == 400) {
          throw ServerException(message: 'Invalid request: ${e.response?.data.toString() ?? e.message}');
        } else if (code == 403) {
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

  @override
  Future<void> addComment(String postId, String content) async {
    try {
      final formData = FormData.fromMap({'content': content});
      final response = await apiService.post(
        '/v${ConstantApi.apiVersion}/feeds/$postId/comment/',
        formData,
        includeAuth: true,
      );
      if (response is Map<String, dynamic> && response.containsKey('comment_id')) {
        return;
      } else {
        throw ServerException(message: 'Invalid response format after adding comment.');
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: 'Failed to add comment: $e');
    }
  }

  @override
  Future<List<CommentModel>> getComments(String postId) async {
    try {
      final response = await apiService.get(
        '/v${ConstantApi.apiVersion}/posts/comment/?post=$postId',
        includeAuth: true,
      );
      if (response is Map<String, dynamic> && response.containsKey('results')) {
        final results = response['results'] as List<dynamic>;
        return results.map((json) => CommentModel.fromJson(json)).toList();
      } else {
        throw ServerException(message: 'Invalid response format');
      }
    } catch (e) {
      throw ServerException(message: 'Failed to fetch comments: $e');
    }
  }

  @override
  Future<void> deleteComment(String commentId) async {
    try {
      await apiService.delete(
        '/v${ConstantApi.apiVersion}/posts/comment/$commentId/',
        includeAuth: true,
      );
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 404) {
          throw ServerException(message: 'Comment not found: $commentId');
        } else if (e.response?.statusCode == 403) {
          throw ServerException(message: 'Forbidden: You lack permission to delete this comment');
        }
      }
      throw ServerException(message: 'Failed to delete comment: $e');
    }
  }
}
