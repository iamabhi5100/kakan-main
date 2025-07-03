import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:kakan/config/constant_api.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/utils/session_manager.dart';
import 'package:path/path.dart' as path;

class YoutubeApiService {
  final Dio _dio;
  final SessionManager _sessionManager;

  YoutubeApiService({
    Dio? dio,
    required SessionManager sessionManager,
  })  : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
            )),
        _sessionManager = sessionManager;

  Future<Map<String, dynamic>> saveDownloadedVideo({
    required String title,
    required String filePath,
    required String duration,
    String? thumbnailPath,
    String mediaType = 'video', // Added mediaType parameter
    void Function(int, int)? onSendProgress,
  }) async {
    final token = await _sessionManager.getAccessToken();
    if (token == null) throw ServerException(message: 'User not authenticated');

    final file = File(filePath);
    if (!await file.exists()) throw ServerException(message: 'File not found at $filePath');

    MultipartFile? thumbnailFile;
    if (thumbnailPath != null) {
      final thumb = File(thumbnailPath);
      if (await thumb.exists()) {
        thumbnailFile = await MultipartFile.fromFile(
          thumbnailPath,
          filename: path.basename(thumbnailPath),
        );
      }
    }

    final fullUrl = '${ConstantApi.baseUrl}${ConstantApi.downloads}';

    // Build the form data with media_type
    final formData = FormData.fromMap({
      'media_type': mediaType, // Use the provided mediaType
      'media_file': await MultipartFile.fromFile(
        filePath,
        filename: path.basename(filePath),
      ),
      'title': title,
      'duration': duration,
      if (thumbnailFile != null) 'thumbnail': thumbnailFile,
    });

    try {
      final response = await _dio.post(
        fullUrl,
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
        onSendProgress: onSendProgress,
      );

      print('[YoutubeApiService] Upload response: ${response.statusCode}, data: ${response.data}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Map<String, dynamic>.from(response.data);
      }
      throw ServerException(message: 'Upload failed with status code ${response.statusCode}');
    } on DioException catch (e) {
      print('[YoutubeApiService] DioException: $e, ${e.response?.data}');
      throw ServerException(
        message: e.response?.data.toString() ?? 'Network error occurred',
      );
    } catch (e, st) {
      print('[YoutubeApiService] Unknown error: $e\n$st');
      throw ServerException(message: 'Unexpected error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getDownloadedVideos() async {
    final token = await _sessionManager.getAccessToken();
    if (token == null) throw ServerException(message: 'User not authenticated');

    final fullUrl = '${ConstantApi.baseUrl}${ConstantApi.downloads}';

    try {
      print('[YoutubeApiService] Fetching downloads from: $fullUrl');
      final response = await _dio.get(
        fullUrl,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (response.statusCode == 200) {
        if (response.data is List) {
          return List<Map<String, dynamic>>.from(response.data);
        }
        if (response.data is Map && response.data['results'] is List) {
          return List<Map<String, dynamic>>.from(response.data['results']);
        }
        throw ServerException(message: 'Unexpected response structure');
      }
      throw ServerException(message: 'Failed to fetch downloads: ${response.statusMessage}');
    } on DioException catch (e) {
      throw ServerException(
        message: e.response?.data.toString() ?? 'Network error',
      );
    } catch (e) {
      throw ServerException(message: 'Unexpected error: $e');
    }
  }
}
