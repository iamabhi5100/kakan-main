import 'package:dio/dio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:kakan/config/constant_api.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/network/api_service.dart';
import 'package:kakan/features/home/data/models/share_models.dart';
import 'package:kakan/injection_container.dart' as di;

abstract class ShareRemoteDataSource {
  Future<List<ShareItem>> getUsersToShare();
  Future<void> sendMessage({
    required String chatId,
    required String type,
    required String content,
    required String messageType,
    String? mediaFileUrl,
  });
}

class ShareRemoteDataSourceImpl implements ShareRemoteDataSource {
  final ApiService apiService;
  final DefaultCacheManager cacheManager;
  final Dio _dio = Dio();

  ShareRemoteDataSourceImpl({
    required this.apiService,
    required this.cacheManager,
  });

  @override
  Future<List<ShareItem>> getUsersToShare() async {
    await cacheManager.removeFile('/v${ConstantApi.apiVersion}/chat/individual/users-to-share/');
    List<ShareItem> allItems = [];
    String? nextUrl = '/v${ConstantApi.apiVersion}/chat/individual/users-to-share/';

    try {
      while (nextUrl != null) {
        final response = await apiService.get(
          nextUrl,
          includeAuth: true,
        );
        if (response is Map<String, dynamic> && response.containsKey('results')) {
          final results = response['results'] as List<dynamic>;
          allItems.addAll(results.map((json) => ShareItem.fromJson(json)).toList());
          nextUrl = response['next']?.toString();
        } else {
          throw ServerException(message: 'Invalid response format');
        }
      }
      return allItems;
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> sendMessage({
    required String chatId,
    required String type,
    required String content,
    required String messageType,
    String? mediaFileUrl,
  }) async {
    try {
      final formData = FormData.fromMap({
        'content': content,
        'message_type': messageType,
      });

      if (mediaFileUrl != null && mediaFileUrl.isNotEmpty) {
        final response = await _dio.get(
          mediaFileUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        final fileName = mediaFileUrl.split('/').last;
        formData.files.add(MapEntry(
          'media_file',
          MultipartFile.fromBytes(
            response.data as List<int>,
            filename: fileName,
          ),
        ));
      }

      final endpoint = type == 'user'
          ? '/v${ConstantApi.apiVersion}/chat/individual/$chatId/send/'
          : '/v${ConstantApi.apiVersion}/chat/group/$chatId/send/';

      await apiService.post(
        endpoint,
        formData,
        includeAuth: true,
      );
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 404) {
          throw ServerException(message: 'Chat not found: $chatId');
        } else if (e.response?.statusCode == 400) {
          throw ServerException(message: 'Invalid request: ${e.response?.data.toString()}');
        } else if (e.response?.statusCode == 403) {
          throw ServerException(message: 'Forbidden: You lack permission to send this message');
        }
      }
      throw ServerException(message: 'Failed to send message: $e');
    }
  }
}