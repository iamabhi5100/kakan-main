import 'package:equatable/equatable.dart';

abstract class OtpEvent extends Equatable {
  const OtpEvent();
  @override
  List<Object> get props => [];
}

class RequestOtpButtonPressed extends OtpEvent {
  final String mobile;
  const RequestOtpButtonPressed({required this.mobile});
  @override
  List<Object> get props => [mobile];
}

class VerifyOtpButtonPressed extends OtpEvent {
  final String otp;
  final String otpToken;

  const VerifyOtpButtonPressed({required this.otp, required this.otpToken});

  @override
  List<Object> get props => [otp, otpToken];
}

class CreateProfileButtonPressed extends OtpEvent {
  final String token;
  final Map<String, dynamic> profileData;

  const CreateProfileButtonPressed({required this.token, required this.profileData});

  @override
  List<Object> get props => [token, profileData];
}