import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http_parser/http_parser.dart';
import 'package:kakan/config/constant_api.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/network/api_service.dart';
import 'package:kakan/features/reels/data/models/reel_model.dart';
import 'package:kakan/features/reels/data/models/share_target_model.dart';
import 'package:kakan/features/home/data/models/comment_model.dart';

abstract class ReelsRemoteDataSource {
  Future<Map<String, dynamic>> getReels({String? nextUrl});
  Future<void> likeReel({required String reelId, required bool like});
  Future<void> repostReel({
    required String reelId,
    required String mediaType,
    required String title,
    required String caption,
  });
  Future<void> deleteReel(String reelId);
  Future<List<ShareTargetModel>> getShareTargets();
  Future<void> shareReel(String reelId, String chatId, String type);

  // comments
  Future<List<CommentModel>> getComments(String reelId);
  Future<void> addComment(String reelId, String content);
  Future<void> deleteComment(String commentId);
}

class ReelsRemoteDataSourceImpl implements ReelsRemoteDataSource {
  final ApiService apiService;
  final DefaultCacheManager cacheManager;

  ReelsRemoteDataSourceImpl({
    required this.apiService,
    required this.cacheManager,
  });

  static const _feedPath = '/v${ConstantApi.apiVersion}/feeds/trims/';

  @override
  Future<Map<String, dynamic>> getReels({String? nextUrl}) async {
    final cacheKey = nextUrl ?? _feedPath;

    // ---------- Try cache first ----------
    try {
      final cached = await cacheManager.getFileFromCache(cacheKey);
      if (cached != null && cached.validTill.isAfter(DateTime.now())) {
        final raw = await cached.file.readAsString();
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final results = (data['results'] as List? ?? const []);
        final models = <ReelModel>[];
        for (final item in results) {
          try {
            if (item is Map<String, dynamic>) {
              models.add(ReelModel.fromJsonSafe(item));
            }
          } catch (e) {
            // Skip bad item but continue
            // ignore: avoid_print
            print('WARN: Skipping invalid cached reel item: $e');
          }
        }
        if (models.isNotEmpty) {
          return {
            'results': models,
            'next': data['next'],
            'count': data['count'] ?? models.length,
          };
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('ERROR: Failed to parse cached data: $e');
    }

    // ---------- Fetch from server ----------
    try {
      final resp = await apiService.get(nextUrl ?? _feedPath, includeAuth: true);

      if (resp is! Map<String, dynamic>) {
        throw ServerException(message: 'Invalid response: ${resp.runtimeType}');
      }

      final results = (resp['results'] as List? ?? const []);
      final models = <ReelModel>[];

      for (final item in results) {
        try {
          if (item is Map<String, dynamic>) {
            models.add(ReelModel.fromJsonSafe(item));
          }
        } catch (e) {
          // ignore: avoid_print
          print('WARN: Skipping invalid server reel item: $e');
        }
      }

      // Refresh cache only when we have something meaningful
      try {
        if (results.isNotEmpty) {
          await cacheManager.putFile(
            cacheKey,
            utf8.encode(jsonEncode(resp)),
            maxAge: const Duration(hours: 1),
          );
        } else {
          await cacheManager.removeFile(cacheKey);
        }
      } catch (_) {}

      return {
        'results': models,
        'next': resp['next'],
        'count': resp['count'] ?? models.length,
      };
    } catch (e) {
      // ignore: avoid_print
      print('ERROR: Failed to fetch reels from server: $e');
      throw ServerException(message: 'Failed to fetch reels: $e');
    }
  }

  @override
  Future<void> likeReel({required String reelId, required bool like}) async {
    try {
      final formData = FormData.fromMap({'like': like.toString()});
      final response = await apiService.post(
        '/v${ConstantApi.apiVersion}/posts/$reelId/like-dislike-post/',
        formData,
        includeAuth: true,
      );
      // ignore: avoid_print
      print('DEBUG: Like reel response: $response');
      // Invalidate feed cache
      await cacheManager.removeFile(_feedPath);
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        throw ServerException(message: 'Post not found for reel: $reelId');
      }
      throw ServerException(message: 'Failed to like reel: $e');
    }
  }

  @override
  Future<void> repostReel({
    required String reelId,
    required String mediaType,
    required String title,
    required String caption,
  }) async {
    try {
      final formData = FormData.fromMap({
        'media_type': mediaType,
        'title': (title.isNotEmpty ? 'Repost of $title' : 'Repost of ${reelId.substring(0, 8)}'),
        'caption': (caption.isNotEmpty ? 'Reposting: $caption' : 'Reposting reel $reelId'),
      });

      final response = await apiService.post(
        '/v${ConstantApi.apiVersion}/trims/$reelId/repost/',
        formData,
        includeAuth: true,
      );
      // ignore: avoid_print
      print('DEBUG: Repost reel response: $response');
      await cacheManager.removeFile(_feedPath);
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        throw ServerException(message: 'Reel not found for repost: $reelId');
      }
      throw ServerException(message: 'Failed to repost reel: $e');
    }
  }

  @override
  Future<void> deleteReel(String reelId) async {
    try {
      final response = await apiService.delete(
        '/v${ConstantApi.apiVersion}/posts/$reelId/',
        includeAuth: true,
      );
      // ignore: avoid_print
      print('DEBUG: Delete reel response for $reelId: $response');
      await cacheManager.removeFile(_feedPath);
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        throw ServerException(message: 'Reel not found: $reelId');
      }
      throw ServerException(message: 'Failed to delete reel: $e');
    }
  }

  @override
  Future<List<ShareTargetModel>> getShareTargets() async {
    try {
      final response = await apiService.get(
        '/v${ConstantApi.apiVersion}/chat/individual/users-to-share/',
        includeAuth: true,
      );
      // ignore: avoid_print
      print('DEBUG: Share targets response: $response');
      final results = (response['results'] as List? ?? const []);
      return results
          .whereType<Map<String, dynamic>>()
          .map((json) => ShareTargetModel.fromJsonSafe(json))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('ERROR: Failed to fetch share targets: $e');
      throw ServerException(message: 'Failed to fetch share targets: $e');
    }
  }

  @override
  Future<void> shareReel(String reelId, String chatId, String type) async {
    try {
      // NOTE: Ideally there should be a direct endpoint to fetch a single reel by ID.
      // For now we scan the feed.
      final feed = await apiService.get(_feedPath, includeAuth: true);
      final results = (feed is Map && feed['results'] is List) ? feed['results'] as List : const [];
      final reels = results.whereType<Map<String, dynamic>>().map((j) => ReelModel.fromJsonSafe(j)).toList();
      final reel = reels.firstWhere(
        (r) => r.id == reelId,
        orElse: () => throw ServerException(message: 'Reel not found: $reelId'),
      );

      // Download the media
      final videoResponse = await Dio().get(
        reel.mediaFile,
        options: Options(responseType: ResponseType.bytes),
      );
      final videoBytes = videoResponse.data;

      final formData = FormData.fromMap({
        'content': type == 'group' ? 'Shared a reel to group' : 'Shared a reel',
        'message_type': 'video',
        'media_file': MultipartFile.fromBytes(
          videoBytes,
          filename: 'reel_$reelId.mp4',
          contentType: MediaType('video', 'mp4'),
        ),
      });

      final endpoint = type == 'group'
          ? '/v${ConstantApi.apiVersion}/chat/group/$chatId/send/'
          : '/v${ConstantApi.apiVersion}/chat/individual/$chatId/send/';

      final res = await apiService.post(endpoint, formData, includeAuth: true);
      // ignore: avoid_print
      print('DEBUG: Share reel response $res');
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        throw ServerException(message: 'Chat or reel not found: $reelId, $chatId');
      }
      // ignore: avoid_print
      print('ERROR: Failed to share reel: $e');
      throw ServerException(message: 'Failed to share reel: $e');
    }
  }

  // -------- Comments --------

  @override
  Future<void> addComment(String reelId, String content) async {
    try {
      final formData = FormData.fromMap({'content': content});
      final response = await apiService.post(
        '/v${ConstantApi.apiVersion}/feeds/$reelId/comment/',
        formData,
        includeAuth: true,
      );
      if (response is! Map<String, dynamic> || !response.containsKey('comment_id')) {
        throw ServerException(message: 'Failed to add comment: Invalid response format');
      }
    } catch (e) {
      throw ServerException(message: 'Failed to add comment: $e');
    }
  }

  @override
  Future<List<CommentModel>> getComments(String reelId) async {
    try {
      final response = await apiService.get(
        '/v${ConstantApi.apiVersion}/posts/comment/?post=$reelId',
        includeAuth: true,
      );
      final results = (response is Map && response['results'] is List) ? response['results'] as List : const [];
      return results.whereType<Map<String, dynamic>>().map(CommentModel.fromJson).toList();
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
      if (e is DioException && e.response?.statusCode == 403) {
        throw ServerException(message: 'Forbidden: You cannot delete this comment');
      }
      throw ServerException(message: 'Failed to delete comment: $e');
    }
  }
}
