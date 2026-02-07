// lib/core/network/models/request_otp_response.dart
class RequestOtpResponse {
  final String otpToken;

  RequestOtpResponse({required this.otpToken});

  factory RequestOtpResponse.fromJson(Map<String, dynamic> json) {
    return RequestOtpResponse(otpToken: json['otp_token']);
  }
}