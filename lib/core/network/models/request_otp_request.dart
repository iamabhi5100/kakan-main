// lib/core/network/models/request_otp_request.dart
class RequestOtpRequest {
  final String phone;

  RequestOtpRequest({required this.phone});

  Map<String, dynamic> toJson() => {'phone': phone};
}
