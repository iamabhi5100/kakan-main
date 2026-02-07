// lib/core/network/models/refresh_token_request.dart
class RefreshTokenRequest {
  final String refreshToken;

  RefreshTokenRequest({required this.refreshToken});

  Map<String, dynamic> toJson() => {'refresh_token': refreshToken};
}
