// lib/features/login/presentation/bloc/otp_state.dart
import 'package:equatable/equatable.dart';
import 'package:kakan/core/error/app_error.dart';

abstract class OtpState extends Equatable {
  const OtpState();
  @override
  List<Object?> get props => [];
}

class OtpInitial extends OtpState {}

class OtpLoading extends OtpState {}

class OtpSuccess extends OtpState {
  final String? phone;
  const OtpSuccess({this.phone});
  @override
  List<Object?> get props => [phone];
}

class OtpVerified extends OtpState {
  final String token;
  final bool hasProfile;
  final String userId;
  const OtpVerified({
    required this.token,
    required this.hasProfile,
    required this.userId,
  });
  @override
  List<Object> get props => [token, hasProfile, userId];
}

class ProfileCreated extends OtpState {}

class OtpFailure extends OtpState {
  final String message;
  final AppErrorType type;
  const OtpFailure({
    required this.message,
    this.type = AppErrorType.unknown,
  });
  @override
  List<Object> get props => [message, type];
}
