// lib/core/network/models/verify_otp_response.dart
import 'package:kakan/core/network/models/user_details.dart';

class VerifyOtpResponse {
  final String accessToken;
  final String refreshToken;
  final bool isExisted;
  final UserDetails? userDetails;

  VerifyOtpResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.isExisted,
    this.userDetails,
  });

  factory VerifyOtpResponse.fromJson(Map<String, dynamic> json) {
    return VerifyOtpResponse(
      accessToken: json['access_token'] ?? '',
      refreshToken: json['refresh_token'] ?? '',
      isExisted: json['is_existed'] ?? false,
      userDetails: json['user_details'] != null ? UserDetails.fromJson(json['user_details']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'is_existed': isExisted,
      'user_details': userDetails?.toJson(),
    };
  }
}