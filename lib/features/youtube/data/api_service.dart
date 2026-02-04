import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
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
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 30),
              ),
            ),
        _sessionManager = sessionManager {
    // Add very verbose interceptor for debugging uploads
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (o, handler) {
        print('[YT_UPLOAD][REQ] ${o.method} ${o.uri}');
        print('[YT_UPLOAD][REQ][HDR] ${o.headers}');
        handler.next(o);
      },
      onResponse: (r, handler) {
        print('[YT_UPLOAD][RES] code=${r.statusCode} uri=${r.realUri}');
        final dataStr = _safeBody(r.data);
        print('[YT_UPLOAD][RES][BODY] $dataStr');
        handler.next(r);
      },
      onError: (e, handler) {
        print('[YT_UPLOAD][ERR] ${e.message} uri=${e.requestOptions.uri}');
        print('[YT_UPLOAD][ERR][DATA] ${_safeBody(e.response?.data)}');
        handler.next(e);
      },
    ));
  }

  Future<Map<String, dynamic>> saveDownloadedVideo({
    required String title,
    required String filePath,
    required String duration,
    String? thumbnailPath,
    String mediaType = 'video',
    void Function(int, int)? onSendProgress,
  }) async {
    final token = await _sessionManager.getAccessToken();
    if (token == null) throw ServerException(message: 'User not authenticated');

    final mediaFile = File(filePath);
    if (!await mediaFile.exists()) {
      throw ServerException(message: 'File not found at $filePath');
    }

    final videoExt = _sanitizeExt(path.extension(filePath), fallback: '.mp4');
    final videoSubtype = _inferVideoSubtype(videoExt);
    final videoFilename = _buildSafeFilename(prefix: 'media', ext: videoExt);

    MultipartFile? thumbnailFile;
    if (thumbnailPath != null) {
      final thumb = File(thumbnailPath);
      if (await thumb.exists()) {
        final tExt = _sanitizeExt(path.extension(thumbnailPath), fallback: '.jpg');
        final tSubtype = _inferImageSubtype(tExt);
        final tFilename = _buildSafeFilename(prefix: 'thumb', ext: tExt);
        thumbnailFile = await MultipartFile.fromFile(
          thumbnailPath,
          filename: tFilename,
          contentType: MediaType('image', tSubtype),
        );
      }
    }

    final fullUrl = '${ConstantApi.baseUrl}${ConstantApi.downloads}';
    print('[YT_UPLOAD] POST $fullUrl');

    final formData = FormData.fromMap({
      'media_type': mediaType,
      'media_file': await MultipartFile.fromFile(
        filePath,
        filename: videoFilename,
        contentType: MediaType(mediaType == 'audio' ? 'audio' : 'video', videoSubtype),
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
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
        onSendProgress: (sent, total) {
          if (onSendProgress != null) onSendProgress(sent, total);
          if (total > 0) {
            final pct = (sent / total * 100).toStringAsFixed(1);
            print('[YT_UPLOAD][PROG] $sent/$total ($pct%)');
          }
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final map = Map<String, dynamic>.from(response.data);
        print('[YT_UPLOAD] OK ${response.statusCode}');
        return map;
      }
      throw ServerException(message: 'Upload failed with status ${response.statusCode}');
    } on DioException catch (e) {
      final msg = e.response?.data?.toString() ?? e.message ?? 'Network error';
      print('[YT_UPLOAD] DioException: $msg');
      throw ServerException(message: msg);
    } catch (e, st) {
      print('[YT_UPLOAD] Unknown error: $e\n$st');
      throw ServerException(message: 'Unexpected error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getDownloadedVideos() async {
    final token = await _sessionManager.getAccessToken();
    if (token == null) throw ServerException(message: 'User not authenticated');

    final fullUrl = '${ConstantApi.baseUrl}${ConstantApi.downloads}';
    print('[YT_UPLOAD] GET $fullUrl');
    try {
      final response = await _dio.get(
        fullUrl,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        if (data is Map && data['results'] is List) {
          return List<Map<String, dynamic>>.from(data['results']);
        }
        throw ServerException(message: 'Unexpected response structure');
      }
      throw ServerException(message: 'Failed to fetch downloads: ${response.statusMessage}');
    } on DioException catch (e) {
      throw ServerException(message: e.response?.data.toString() ?? 'Network error');
    } catch (e) {
      throw ServerException(message: 'Unexpected error: $e');
    }
  }

  // -------- helpers --------

  String _buildSafeFilename({required String prefix, required String ext}) {
    final base = '${prefix}_${DateTime.now().millisecondsSinceEpoch}';
    final maxLen = 100;
    final remaining = maxLen - ext.length;
    final safeBase = base.length <= remaining ? base : base.substring(0, remaining);
    return '$safeBase$ext';
    }

  String _sanitizeExt(String ext, {required String fallback}) {
    final e = (ext.isEmpty ? fallback : ext).toLowerCase();
    final clean = e.replaceAll(RegExp(r'[^.a-z0-9]'), '');
    return clean.isEmpty ? fallback : clean;
  }

  String _inferVideoSubtype(String ext) {
    switch (ext) {
      case '.mp4':
      case '.m4v':
        return 'mp4';
      case '.webm':
        return 'webm';
      case '.mov':
        return 'quicktime';
      case '.mkv':
        return 'x-matroska';
      case '.m4a':
        return 'mp4';
      default:
        return 'mp4';
    }
  }

  String _inferImageSubtype(String ext) {
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'jpeg';
      case '.png':
        return 'png';
      case '.webp':
        return 'webp';
      default:
        return 'jpeg';
    }
  }

  String _safeBody(Object? data, {int limit = 2000}) {
    final s = data?.toString() ?? '';
    if (s.length <= limit) return s;
    return s.substring(0, limit) + ' ...<truncated>';
  }
}
