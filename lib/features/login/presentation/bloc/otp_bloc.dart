// lib/features/login/presentation/bloc/otp_bloc.dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/error/app_error.dart';
import 'package:kakan/core/error/exceptions.dart';

import 'package:kakan/core/utils/session_manager.dart';
import 'package:kakan/features/login/domain/usecases/create_profile.dart';
import 'package:kakan/features/login/domain/usecases/request_otp.dart';
import 'package:kakan/features/login/domain/usecases/verify_otp.dart';

import 'package:kakan/features/login/presentation/bloc/otp_event.dart';
import 'package:kakan/features/login/presentation/bloc/otp_state.dart';

class OtpBloc extends Bloc<OtpEvent, OtpState> {
  final RequestOtp requestOtp;
  final VerifyOtp verifyOtp;
  final CreateProfile createProfile;
  final SessionManager sessionManager;

  OtpBloc({
    required this.requestOtp,
    required this.verifyOtp,
    required this.createProfile,
    required this.sessionManager,
  }) : super(OtpInitial()) {
    on<RequestOtpButtonPressed>(_onRequestOtpButtonPressed);
    on<VerifyOtpButtonPressed>(_onVerifyOtpButtonPressed);
    on<CreateProfileButtonPressed>(_onCreateProfileButtonPressed);
  }

  // ---------- Handlers ----------

  Future<void> _onRequestOtpButtonPressed(
    RequestOtpButtonPressed event,
    Emitter<OtpState> emit,
  ) async {
    emit(OtpLoading());
    final result = await requestOtp(event.mobile);
    emit(result.fold(
      (failure) {
        final m = _mapFailure(failure);
        return OtpFailure(message: m.message, type: m.type);
      },
      (_) => OtpSuccess(phone: event.mobile),
    ));
  }

  Future<void> _onVerifyOtpButtonPressed(
    VerifyOtpButtonPressed event,
    Emitter<OtpState> emit,
  ) async {
    emit(OtpLoading());
    final result = await verifyOtp(
      VerifyOtpParams(otp: event.otp, otpToken: event.otpToken),
    );
    emit(result.fold(
      (failure) {
        final m = _mapFailure(failure);
        return OtpFailure(message: m.message, type: m.type);
      },
      (wrapper) => OtpVerified(
        token: wrapper.token,
        hasProfile: wrapper.hasProfile,
        userId: wrapper.userId,
      ),
    ));
  }

  Future<void> _onCreateProfileButtonPressed(
    CreateProfileButtonPressed event,
    Emitter<OtpState> emit,
  ) async {
    emit(OtpLoading());
    final result = await createProfile(CreateProfileParams(
      token: event.token,
      profileData: event.profileData,
    ));
    emit(result.fold(
      (failure) {
        final m = _mapFailure(failure);
        return OtpFailure(message: m.message, type: m.type);
      },
      (_) =>  ProfileCreated(),
    ));
  }

  // ---------- Failure -> (message, type) ----------

  /// Maps a domain `Failure` to a user-facing message and a structured `AppErrorType`
  /// so the UI can render context-specific screens (e.g., no internet / timeout).
  ({String message, AppErrorType type}) _mapFailure(Failure failure) {
    if (failure is ServerFailure) {
      final ServerException? ex = failure.exception;
      return (
        message: ex?.message ?? 'Server error occurred',
        type: ex?.type ?? AppErrorType.unknown,
      );
    }
    return (
      message: 'Unexpected error occurred. Please try again.',
      type: AppErrorType.unknown,
    );
    // If you also have CacheFailure or others, add cases here similarly.
  }
}
