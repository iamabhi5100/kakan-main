import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/utils/session_manager.dart';
import 'package:kakan/features/login/domain/usecases/create_profile.dart';
import 'package:kakan/features/login/domain/usecases/request_otp.dart';
import 'package:kakan/features/login/domain/usecases/verify_otp.dart';
import 'package:kakan/features/login/presentation/bloc/otp_event.dart';
import 'package:kakan/features/login/presentation/bloc/otp_state.dart';

// part 'otp_event.dart';
// part 'otp_state.dart';

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

  Future<void> _onRequestOtpButtonPressed(
    RequestOtpButtonPressed event,
    Emitter<OtpState> emit,
  ) async {
    emit(OtpLoading());
    final result = await requestOtp(event.mobile);
    emit(result.fold(
      (failure) => OtpFailure(message: _mapFailureToMessage(failure)),
      (_) => OtpSuccess(phone: event.mobile),
    ));
  }

Future<void> _onVerifyOtpButtonPressed(
  VerifyOtpButtonPressed event,
  Emitter<OtpState> emit,
) async {
  emit(OtpLoading());
  final result = await verifyOtp(VerifyOtpParams(otp: event.otp, otpToken: event.otpToken));
  emit(result.fold(
    (failure) => OtpFailure(message: _mapFailureToMessage(failure)),
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
      (failure) => OtpFailure(message: _mapFailureToMessage(failure)),
      (_) => ProfileCreated(),
    ));
  }

  String _mapFailureToMessage(Failure failure) {
    if (failure is ServerFailure) {
      return failure.exception?.message ?? 'Server error occurred';
    }
    return 'Unexpected error occurred. Please try again.';
  }
}