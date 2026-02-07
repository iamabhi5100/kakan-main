// lib/core/network/models/refresh_token_response.dart
class RefreshTokenResponse {
  final String accessToken;
  final String refreshToken;

  RefreshTokenResponse({required this.accessToken, required this.refreshToken});

  factory RefreshTokenResponse.fromJson(Map<String, dynamic> json) {
    return RefreshTokenResponse(
      accessToken: json['access_token'],
      refreshToken: json['refresh_token'],
    );
  }
}