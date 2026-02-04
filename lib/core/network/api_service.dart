// lib/core/network/api_service.dart
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:kakan/config/constant_api.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/error/app_error.dart';
import 'package:kakan/core/utils/session_manager.dart';
import 'package:kakan/core/network/models/refresh_token_request.dart';
import 'package:kakan/core/network/models/refresh_token_response.dart';
import 'package:path/path.dart' as path;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'dart:convert';

class ApiService {
  final Dio _dio;
  final SessionManager sessionManager;

  ApiService({required this.sessionManager})
      : _dio = Dio(
          BaseOptions(
            baseUrl: ConstantApi.baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            headers: {'Content-Type': 'application/json'},
          ),
        ) {
    _dio.interceptors.addAll([
      // (Optional) request/response logging
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
        logPrint: (message) => debugPrint(message.toString()),
      ),

      // Auth injection + auto refresh on 401
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.headers.containsKey('Authorization') &&
              options.headers['Authorization'] == true) {
            final accessToken = await sessionManager.getAccessToken();
            if (accessToken != null) {
              options.headers['Authorization'] = 'Bearer $accessToken';
            } else {
              debugPrint('No access token available');
              options.headers.remove('Authorization');
            }
          }
          debugPrint('Request headers: ${options.headers}');
          return handler.next(options);
        },
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          debugPrint(
            'Request error: method=${error.requestOptions.method}, '
            'uri=${error.requestOptions.uri}, error=$error',
          );

          final hadBearer = error.requestOptions.headers['Authorization']
                  ?.toString()
                  .startsWith('Bearer ') ==
              true;

          // Try token refresh only when 401 arrived after using a Bearer token
          if (error.response?.statusCode == 401 && hadBearer) {
            try {
              final newTokens = await _refreshToken();
              if (newTokens != null) {
                // retry the original request with new token
                error.requestOptions.headers['Authorization'] =
                    'Bearer ${newTokens.accessToken}';
                final retryResponse = await _dio.fetch(error.requestOptions);
                return handler.resolve(retryResponse);
              }
            } catch (e, st) {
              debugPrint('Token refresh failed: $e\n$st');
              // fall through to the original error
            }
          }

          return handler.next(error);
        },
      ),
    ]);
  }

  // ---------------------------
  // Centralized error mapping ✅
  // ---------------------------

  // ADD THESE TWO METHODS *INSIDE* class ApiService
  ServerException _mapDioToServerException(DioException e) {
    final sc = e.response?.statusCode;
    final raw = e.response?.data?.toString() ?? e.message ?? '';

    // Timeouts
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return ServerException(
        type: AppErrorType.serverTimeout,
        message: 'Request timed out. Please try again.',
        statusCode: sc,
      );
    }

    // No internet / connection error
    if (e.type == DioExceptionType.connectionError) {
      return ServerException(
        type: AppErrorType.noInternet,
        message: 'No internet connection',
        statusCode: sc,
      );
    }

    // HTTP status mapping
    switch (sc) {
      case 400:
        return ServerException(
          type: AppErrorType.badRequest,
          message: _extractMessage(raw) ?? 'Invalid request',
          statusCode: sc,
        );
      case 401:
        return ServerException(
          type: AppErrorType.unauthorized,
          message: 'Authentication failed. Please log in again.',
          statusCode: sc,
        );
      case 403:
        return ServerException(
          type: AppErrorType.forbidden,
          message: 'Forbidden: You lack permission.',
          statusCode: sc,
        );
      case 404:
        return ServerException(
          type: AppErrorType.notFound,
          message: 'Resource not found.',
          statusCode: sc,
        );
      case 413:
        return ServerException(
          type: AppErrorType.payloadTooLarge,
          message: 'Request Entity Too Large',
          statusCode: sc,
        );
      case 429:
        return ServerException(
          type: AppErrorType.tooManyRequests,
          message: 'Too many requests. Please wait.',
          statusCode: sc,
        );
      case 500:
        return ServerException(
          type: AppErrorType.unknown,
          message: 'Server error',
          statusCode: sc,
        );
      case 502:
      case 503:
        return ServerException(
          type: AppErrorType.serverMaintenance,
          message: 'Service unavailable. Please try again.',
          statusCode: sc,
        );
      default:
        // Dio cancelled case (user action)
        if (e.type == DioExceptionType.cancel) {
          return ServerException(
            type: AppErrorType.unknown,
            message: 'Request was cancelled',
            statusCode: sc,
          );
        }
        // Fallback
        return ServerException(
          type: AppErrorType.unknown,
          message: 'Unexpected error${sc != null ? ' (Status $sc)' : ''}',
          statusCode: sc,
        );
    }
  }

  /// Try pulling a nice message out of a raw string/json-ish body
  String? _extractMessage(String raw) {
    if (raw.trim().isEmpty) return null;
    return raw;
  }

  // --------------
  // HTTP methods
  // --------------

  Future<dynamic> get(
    String endpoint, {
    bool includeAuth = true,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        endpoint,
        cancelToken: cancelToken,
        options: Options(headers: includeAuth ? {'Authorization': true} : null),
      );
      debugPrint('GET $endpoint Response: ${response.data}');
      return response.data;
    } on DioException catch (e, stackTrace) {
      debugPrint('GET $endpoint DioException: $e\nStack trace: $stackTrace');
      throw _mapDioToServerException(e);
    } catch (e, stackTrace) {
      debugPrint('GET $endpoint Unexpected error: $e\nStack trace: $stackTrace');
      throw ServerException(message: 'Unexpected error: $e');
    }
  }

  Future<dynamic> post(
    String endpoint,
    dynamic body, {
    bool includeAuth = true,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
  }) async {
    try {
      final response = await _dio.post(
        endpoint,
        data: body,
        cancelToken: cancelToken,
        options: Options(headers: includeAuth ? {'Authorization': true} : null),
        onSendProgress: onSendProgress,
      );
      debugPrint('POST $endpoint Response: ${response.data}');
      return response.data;
    } on DioException catch (e, stackTrace) {
      debugPrint('POST $endpoint DioException: $e\nStack trace: $stackTrace');

      // (Optional) keep your special IntegrityError handling
      final rawBody = e.response?.data?.toString() ?? '';
      if (e.response?.statusCode == 500) {
        if (rawBody.contains('IntegrityError') &&
            rawBody.contains('users_userprofile_username_085fa49f_uniq')) {
          throw ServerException(
            type: AppErrorType.badRequest,
            message: 'Username conflict. Please try a different username.',
            statusCode: e.response?.statusCode,
          );
        }
        if (rawBody.contains('IntegrityError')) {
          throw ServerException(
            type: AppErrorType.badRequest,
            message:
                'Phone number already exists. Please use a different number.',
            statusCode: e.response?.statusCode,
          );
        }
      }

      throw _mapDioToServerException(e);
    } catch (e, stackTrace) {
      debugPrint('POST $endpoint Unexpected error: $e\nStack trace: $stackTrace');
      throw ServerException(message: 'Unexpected error: $e');
    }
  }

  Future<dynamic> patch(
    String endpoint,
    dynamic body, {
    bool includeAuth = true,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.patch(
        endpoint,
        data: body,
        cancelToken: cancelToken,
        options: Options(headers: includeAuth ? {'Authorization': true} : null),
      );
      debugPrint('PATCH $endpoint Response: ${response.data}');
      return response.data;
    } on DioException catch (e, stackTrace) {
      debugPrint('PATCH $endpoint DioException: $e\nStack trace: $stackTrace');
      throw _mapDioToServerException(e);
    } catch (e, stackTrace) {
      debugPrint('PATCH $endpoint Unexpected error: $e\nStack trace: $stackTrace');
      throw ServerException(message: 'Unexpected error: $e');
    }
  }

  Future<dynamic> delete(
    String endpoint, {
    bool includeAuth = true,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.delete(
        endpoint,
        cancelToken: cancelToken,
        options: Options(headers: includeAuth ? {'Authorization': true} : null),
      );
      debugPrint('DELETE $endpoint Response: ${response.data}');
      return response.data;
    } on DioException catch (e, stackTrace) {
      debugPrint('DELETE $endpoint DioException: $e\nStack trace: $stackTrace');
      throw _mapDioToServerException(e);
    } catch (e, stackTrace) {
      debugPrint('DELETE $endpoint Unexpected error: $e\nStack trace: $stackTrace');
      throw ServerException(message: 'Unexpected error: $e');
    }
  }

  Future<dynamic> uploadFile(
    String endpoint, {
    required String filePath,
    required String fileKey,
    bool includeAuth = true,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        fileKey: await MultipartFile.fromFile(
          filePath,
          filename: path.basename(filePath),
          contentType: (() {
            final mime = lookupMimeType(filePath);
            return mime != null ? MediaType.parse(mime) : MediaType('application', 'octet-stream');
          })(),
        ),
      });

      final response = await _dio.post(
        endpoint,
        data: formData,
        cancelToken: cancelToken,
        options: Options(
          headers: includeAuth ? {'Authorization': true} : null,
          contentType: 'multipart/form-data',
        ),
        onSendProgress: onSendProgress,
      );
      debugPrint('UPLOAD $endpoint Response: ${response.data}');
      return response.data;
    } on DioException catch (e, stackTrace) {
      debugPrint('UPLOAD $endpoint DioException: $e\nStack trace: $stackTrace');
      throw _mapDioToServerException(e);
    } catch (e, stackTrace) {
      debugPrint('UPLOAD $endpoint Unexpected error: $e\nStack trace: $stackTrace');
      throw ServerException(message: 'Unexpected error: $e');
    }
  }

  // -------------------
  // Token refresh flow
  // -------------------
  Future<RefreshTokenResponse?> _refreshToken() async {
    final refreshToken = await sessionManager.getRefreshToken();
    if (refreshToken == null) {
      throw ServerException(message: 'No refresh token available');
    }
    try {
      final response = await post(
        ConstantApi.refreshToken,
        RefreshTokenRequest(refreshToken: refreshToken).toJson(),
        includeAuth: false,
      );

      if (response is Map<String, dynamic> &&
          response.containsKey('access_token') &&
          response.containsKey('refresh_token')) {
        final refreshResponse = RefreshTokenResponse.fromJson(response);
        await sessionManager.saveTokens(
          accessToken: refreshResponse.accessToken,
          refreshToken: refreshResponse.refreshToken,
        );
        return refreshResponse;
      } else {
        throw ServerException(message: 'Invalid refresh token response');
      }
    } catch (e, stackTrace) {
      debugPrint('Token refresh error: $e\nStack trace: $stackTrace');
      await sessionManager.clearTokens();
      throw ServerException(message: 'Failed to refresh token');
    }
  }
}
