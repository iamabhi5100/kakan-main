// lib/core/network/models/verify_otp_request.dart
class VerifyOtpRequest {
  final String otp;
  final String otpToken;

  VerifyOtpRequest({required this.otp, required this.otpToken});

  Map<String, dynamic> toJson() => {'otp': otp, 'otp_token': otpToken};
}