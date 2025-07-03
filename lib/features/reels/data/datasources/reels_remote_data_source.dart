import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:kakan/config/constant_api.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/network/api_service.dart';
import 'package:kakan/features/reels/data/models/reel_model.dart';
import 'package:kakan/features/reels/data/models/share_target_model.dart';

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
}

class ReelsRemoteDataSourceImpl implements ReelsRemoteDataSource {
  final ApiService apiService;
  final DefaultCacheManager cacheManager;

  ReelsRemoteDataSourceImpl({
    required this.apiService,
    required this.cacheManager,
  });

  @override
  Future<Map<String, dynamic>> getReels({String? nextUrl}) async {
    final cacheKey = nextUrl ?? '/v${ConstantApi.apiVersion}/feeds/trims/';
    final cachedFile = await cacheManager.getFileFromCache(cacheKey);

    await cacheManager.removeFile('/v${ConstantApi.apiVersion}/posts/');

    if (cachedFile != null) {
      try {
        final data = jsonDecode(await cachedFile.file.readAsString()) as Map<String, dynamic>;
        print('DEBUG: Cached response for $cacheKey: $data');
        final age = DateTime.now().difference(cachedFile.validTill);
        if (data['results'] is List && age < const Duration(hours: 1)) {
          return {
            'results': (data['results'] as List).map((j) => ReelModel.fromJson(j)).toList(),
            'next': data['next'],
            'count': data['count'] ?? 0,
          };
        } else {
          print('DEBUG: Cache invalid or empty, fetching from server');
        }
      } catch (e) {
        print('ERROR: Failed to parse cached data: $e');
      }
    }

    try {
      final resp = await apiService.get(
        nextUrl ?? '/v${ConstantApi.apiVersion}/feeds/trims/',
        includeAuth: true,
      );
      print('DEBUG: Server response for $cacheKey: $resp');

      if (resp is Map<String, dynamic>) {
        final results = resp['results'] as List<dynamic>?;
        if (results == null) {
          print('WARNING: Server response missing results key');
          return {
            'results': [],
            'next': null,
            'count': 0,
          };
        }
        if (results.isNotEmpty) {
          await cacheManager.putFile(
            cacheKey,
            utf8.encode(jsonEncode(resp)),
            maxAge: const Duration(hours: 1),
          );
        } else {
          await cacheManager.removeFile(cacheKey);
        }

        return {
          'results': results.map((j) => ReelModel.fromJson(j)).toList(),
          'next': resp['next'],
          'count': resp['count'] ?? 0,
        };
      } else {
        throw ServerException(message: 'Invalid response format: Expected Map, got ${resp.runtimeType}');
      }
    } catch (e) {
      print('ERROR: Failed to fetch reels from server: $e');
      throw ServerException(message: 'Failed to fetch reels: $e');
    }
  }

  @override
  Future<void> likeReel({required String reelId, required bool like}) async {
    try {
      final formData = FormData.fromMap({
        'like': like.toString(),
      });

      final response = await apiService.post(
        '/v${ConstantApi.apiVersion}/posts/$reelId/like-dislike-post/',
        formData,
        includeAuth: true,
      );
      print('DEBUG: Like reel response: $response');
      await cacheManager.removeFile('/v${ConstantApi.apiVersion}/feeds/trims/');
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
        'title': title.isNotEmpty ? 'Repost of $title' : 'Repost of ${reelId.substring(0, 8)}',
        'caption': caption.isNotEmpty ? 'Reposting: $caption' : 'Reposting reel $reelId',
      });

      final response = await apiService.post(
        '/v${ConstantApi.apiVersion}/trims/$reelId/repost/',
        formData,
        includeAuth: true,
      );
      print('DEBUG: Repost reel response: $response');
      await cacheManager.removeFile('/v${ConstantApi.apiVersion}/feeds/trims/');
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
      print('DEBUG: Delete reel response for $reelId: $response');
      await cacheManager.removeFile('/v${ConstantApi.apiVersion}/feeds/trims/');
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
      print('DEBUG: Share targets response: $response');
      final results = response['results'] as List<dynamic>;
      return results.map((json) => ShareTargetModel.fromJson(json)).toList();
    } catch (e) {
      print('ERROR: Failed to fetch share targets: $e');
      throw ServerException(message: 'Failed to fetch share targets: $e');
    }
  }

  @override
  Future<void> shareReel(String reelId, String chatId, String type) async {
    try {
      final formData = FormData.fromMap({
        'reel_id': reelId,
        'content': type == 'group' ? 'Shared a reel to group' : 'Shared a reel',
        'message_type': 'url',
      });

      final endpoint = type == 'group'
          ? '/v${ConstantApi.apiVersion}/chat/group/$chatId/send/'
          : '/v${ConstantApi.apiVersion}/chat/individual/$chatId/send/';

      final response = await apiService.post(
        endpoint,
        formData,
        includeAuth: true,
      );
      print('DEBUG: Share reel response for reel $reelId to chat $chatId (type: $type): $response');
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        throw ServerException(message: 'Chat or reel not found: $reelId, $chatId');
      }
      throw ServerException(message: 'Failed to share reel: $e');
    }
  }
}