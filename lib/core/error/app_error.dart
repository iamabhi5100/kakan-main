// lib/core/error/app_error.dart
enum AppErrorType {
  noInternet,
  serverTimeout,
  serverMaintenance, // 502/503 or maintenance messages
  forbidden,         // 403
  tooManyRequests,   // 429
  unauthorized,      // 401
  notFound,          // 404
  badRequest,        // 400 / validation
  payloadTooLarge,   // 413
  unknown,
}
