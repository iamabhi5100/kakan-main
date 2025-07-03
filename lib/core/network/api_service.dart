import 'package:chucker_flutter/chucker_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:kakan/config/chucker_config.dart';
import 'package:kakan/config/constant_api.dart';
import 'package:kakan/core/error/exceptions.dart';
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
      if (ChuckerConfig.isEnabled) ChuckerDioInterceptor(),
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
        logPrint: (message) => print(message.toString()),
      ),
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.headers.containsKey('Authorization') &&
              options.headers['Authorization'] == true) {
            final accessToken = await sessionManager.getAccessToken();
            if (accessToken != null) {
              options.headers['Authorization'] = 'Bearer $accessToken';
            } else {
              print('No access token available');
              options.headers.remove('Authorization');
            }
          }
          print('Request headers: ${options.headers}');
          return handler.next(options);
        },
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          print(
            'Request error: method=${error.requestOptions.method}, uri=${error.requestOptions.uri}, error=$error',
          );
          if (error.response?.statusCode == 401 &&
              error.requestOptions.headers['Authorization']?.startsWith('Bearer ') == true) {
            try {
              final newTokens = await _refreshToken();
              if (newTokens != null) {
                error.requestOptions.headers['Authorization'] = 'Bearer ${newTokens.accessToken}';
                return handler.resolve(await _dio.fetch(error.requestOptions));
              }
            } catch (e, stackTrace) {
              print('Token refresh failed: $e\nStack trace: $stackTrace');
              return handler.next(error);
            }
          }
          return handler.next(error);
        },
      ),
    ]);
  }

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
      print('GET $endpoint Response: ${response.data}');
      return response.data;
    } on DioException catch (e, stackTrace) {
      print('GET $endpoint DioException: $e\nStack trace: $stackTrace');
      if (e.type == DioExceptionType.cancel) {
        throw ServerException(message: 'Request was cancelled');
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw ServerException(message: 'Request timed out. Please try again.');
      }
      if (e.type == DioExceptionType.connectionError) {
        throw ServerException(message: 'No internet connection');
      }
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final body = e.response!.data.toString();
        switch (statusCode) {
          case 400:
            try {
              final errorJson = jsonDecode(body);
              final errorMessage =
                  errorJson['error'] ?? errorJson['detail'] ?? 'Invalid request';
              throw ServerException(message: errorMessage);
            } catch (_) {
              throw ServerException(message: 'Invalid request');
            }
          case 401:
            throw ServerException(
              message: 'Authentication failed. Please log in again.',
            );
          case 403:
            throw ServerException(message: 'Forbidden: You lack permission.');
          case 404:
            throw ServerException(message: 'Resource not found.');
          case 429:
            throw ServerException(message: 'Too many requests. Please wait.');
          case 500:
            throw ServerException(message: 'Server error');
          case 502:
          case 503:
            throw ServerException(
              message: 'Service unavailable. Please try again.',
            );
          default:
            throw ServerException(
              message: 'Unexpected error (Status $statusCode)',
            );
        }
      }
      throw ServerException(message: 'Network error: ${e.message}');
    } catch (e, stackTrace) {
      print('GET $endpoint Unexpected error: $e\nStack trace: $stackTrace');
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
      print('POST $endpoint Response: ${response.data}');
      return response.data;
    } on DioException catch (e, stackTrace) {
      print(
        'POST $endpoint DioException: statusCode=${e.response?.statusCode}, data=${e.response?.data}, message=${e.message}, stackTrace=$stackTrace',
      );
      if (e.type == DioExceptionType.cancel) {
        throw ServerException(message: 'Request was cancelled');
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw ServerException(message: 'Request timed out. Please try again.');
      }
      if (e.type == DioExceptionType.connectionError) {
        throw ServerException(message: 'No internet connection');
      }
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final body = e.response!.data.toString();
        switch (statusCode) {
          case 400:
            try {
              final errorJson = jsonDecode(body);
              final errorMessage =
                  errorJson['non_field_errors']?.join(' ') ??
                  errorJson['error'] ??
                  errorJson['detail'] ??
                  'Invalid request';
              throw ServerException(message: errorMessage);
            } catch (_) {
              throw ServerException(message: 'Invalid request');
            }
          case 401:
            throw ServerException(
              message: 'Authentication failed. Please request a new OTP.',
            );
          case 403:
            throw ServerException(message: 'Forbidden: You lack permission.');
          case 404:
            throw ServerException(message: 'Resource not found.');
          case 429:
            throw ServerException(message: 'Too many requests. Please wait.');
          case 500:
            if (body.contains('IntegrityError') &&
                body.contains('users_userprofile_username_085fa49f_uniq')) {
              throw ServerException(
                message: 'Username conflict. Please try a different username.',
              );
            }
            if (body.contains('IntegrityError')) {
              throw ServerException(
                message:
                    'Phone number already exists. Please use a different number.',
              );
            }
            throw ServerException(message: 'Server error');
          case 502:
          case 503:
            throw ServerException(
              message: 'Service unavailable. Please try again.',
            );
          case 413:
            throw ServerException(message: 'Request Entity Too Large');
          default:
            throw ServerException(
              message: 'Unexpected error (Status $statusCode)',
            );
        }
      }
      throw ServerException(message: 'Network error: ${e.message}');
    } catch (e, stackTrace) {
      print('POST $endpoint Unexpected error: $e\nStack trace: $stackTrace');
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
      print('PATCH $endpoint Response: ${response.data}');
      return response.data;
    } on DioException catch (e, stackTrace) {
      print('PATCH $endpoint DioException: $e\nStack trace: $stackTrace');
      if (e.type == DioExceptionType.cancel) {
        throw ServerException(message: 'Request was cancelled');
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw ServerException(message: 'Request timed out. Please try again.');
      }
      if (e.type == DioExceptionType.connectionError) {
        throw ServerException(message: 'No internet connection');
      }
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final body = e.response!.data.toString();
        switch (statusCode) {
          case 400:
            try {
              final errorJson = jsonDecode(body);
              final errorMessage =
                  errorJson['user']?.first ??
                  errorJson['error'] ??
                  errorJson['detail'] ??
                  'Invalid request';
              throw ServerException(message: errorMessage);
            } catch (_) {
              throw ServerException(message: 'Invalid request');
            }
          case 401:
            throw ServerException(
              message: 'Authentication failed. Please log in again.',
            );
          case 403:
            throw ServerException(message: 'Forbidden: You lack permission.');
          case 404:
            throw ServerException(message: 'Resource not found.');
          case 429:
            throw ServerException(message: 'Too many requests. Please wait.');
          case 500:
            throw ServerException(message: 'Server error');
          case 502:
          case 503:
            throw ServerException(
              message: 'Service unavailable. Please try again.',
            );
          default:
            throw ServerException(
              message: 'Unexpected error (Status $statusCode)',
            );
        }
      }
      throw ServerException(message: 'Network error: ${e.message}');
    } catch (e, stackTrace) {
      print('PATCH $endpoint Unexpected error: $e\nStack trace: $stackTrace');
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
      print('DELETE $endpoint Response: ${response.data}');
      return response.data;
    } on DioException catch (e, stackTrace) {
      print('DELETE $endpoint DioException: $e\nStack trace: $stackTrace');
      if (e.type == DioExceptionType.cancel) {
        throw ServerException(message: 'Request was cancelled');
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw ServerException(message: 'Request timed out. Please try again.');
      }
      if (e.type == DioExceptionType.connectionError) {
        throw ServerException(message: 'No internet connection');
      }
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final body = e.response!.data.toString();
        switch (statusCode) {
          case 400:
            try {
              final errorJson = jsonDecode(body);
              final errorMessage =
                  errorJson['error'] ??
                  errorJson['detail'] ??
                  'Invalid request';
              throw ServerException(message: errorMessage);
            } catch (_) {
              throw ServerException(message: 'Invalid request');
            }
          case 401:
            throw ServerException(
              message: 'Authentication failed. Please log in again.',
            );
          case 403:
            throw ServerException(message: 'Forbidden: You lack permission.');
          case 404:
            throw ServerException(message: 'Resource not found.');
          case 429:
            throw ServerException(message: 'Too many requests. Please wait.');
          case 500:
            throw ServerException(message: 'Server error');
          case 502:
          case 503:
            throw ServerException(
              message: 'Service unavailable. Please try again.',
            );
          default:
            throw ServerException(
              message: 'Unexpected error (Status $statusCode)',
            );
        }
      }
      throw ServerException(message: 'Network error: ${e.message}');
    } catch (e, stackTrace) {
      print('DELETE $endpoint Unexpected error: $e\nStack trace: $stackTrace');
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
          contentType: lookupMimeType(filePath) != null
              ? MediaType.parse(lookupMimeType(filePath)!)
              : MediaType('application', 'octet-stream'),
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
      print('POST $endpoint Response: ${response.data}');
      return response.data;
    } on DioException catch (e, stackTrace) {
      print(
        'POST $endpoint DioException: statusCode=${e.response?.statusCode}, data=${e.response?.data}, message=${e.message}, stackTrace=$stackTrace',
      );
      if (e.type == DioExceptionType.cancel) {
        throw ServerException(message: 'Request was cancelled');
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw ServerException(message: 'Request timed out. Please try again.');
      }
      if (e.type == DioExceptionType.connectionError) {
        throw ServerException(message: 'No internet connection');
      }
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final body = e.response!.data.toString();
        switch (statusCode) {
          case 400:
            try {
              final errorJson = jsonDecode(body);
              final errorMessage =
                  errorJson['non_field_errors']?.join(' ') ??
                  errorJson['error'] ??
                  errorJson['detail'] ??
                  'Invalid request';
              throw ServerException(message: errorMessage);
            } catch (_) {
              throw ServerException(message: 'Invalid request');
            }
          case 401:
            throw ServerException(
              message: 'Authentication failed. Please request a new OTP.',
            );
          case 403:
            throw ServerException(message: 'Forbidden: You lack permission.');
          case 404:
            throw ServerException(message: 'Resource not found.');
          case 429:
            throw ServerException(message: 'Too many requests. Please wait.');
          case 500:
            throw ServerException(message: 'Server error');
          case 502:
          case 503:
            throw ServerException(
              message: 'Service unavailable. Please try again.',
            );
          case 413:
            throw ServerException(message: 'Request Entity Too Large');
          default:
            throw ServerException(
              message: 'Unexpected error (Status $statusCode)',
            );
        }
      }
      throw ServerException(message: 'Network error: ${e.message}');
    } catch (e, stackTrace) {
      print('POST $endpoint Unexpected error: $e\nStack trace: $stackTrace');
      throw ServerException(message: 'Unexpected error: $e');
    }
  }

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
      print('Token refresh error: $e\nStack trace: $stackTrace');
      await sessionManager.clearTokens();
      throw ServerException(message: 'Failed to refresh token');
    }
  }
}