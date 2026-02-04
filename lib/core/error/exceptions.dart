// lib/core/error/exceptions.dart
import 'package:kakan/core/error/app_error.dart';

class ServerException implements Exception {
  final String? message;
  final AppErrorType type;
  final int? statusCode;

  ServerException({
    this.message,
    this.type = AppErrorType.unknown,
    this.statusCode,
  });

  @override
  String toString() =>
      'ServerException(type: $type, status: $statusCode, message: ${message ?? 'Unknown error'})';
}

class CacheException implements Exception {}
