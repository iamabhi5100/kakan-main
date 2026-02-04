import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kakan/config/theme.dart';
import 'package:kakan/core/utils/session_manager.dart';
import 'package:kakan/features/login/data/datasources/remote_data_source.dart';
import 'package:kakan/features/login/presentation/bloc/otp_bloc.dart';
import 'package:kakan/features/login/presentation/bloc/otp_event.dart';
import 'package:kakan/features/login/presentation/bloc/otp_state.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:fluttertoast/fluttertoast.dart';

class OTPForm extends StatefulWidget {
  final String phone;
  final RemoteDataSource remoteDataSource;

  const OTPForm({
    required this.phone,
    required this.remoteDataSource,
    super.key,
  });

  @override
  State<OTPForm> createState() => _OTPFormState();
}

class _OTPFormState extends State<OTPForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _otpController = TextEditingController();
  final SessionManager _sessionManager = SessionManager();
  String? _otpError;
  int _resendSeconds = 15;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    Fluttertoast.cancel(); // Cancel any existing toasts
    _startResendTimer();
  }

  void _startResendTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _onSubmitOTP() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      setState(() => _otpError = 'OTP is required');
      return;
    }
    if (otp.length != 6) {
      setState(() => _otpError = 'OTP must be 6 digits');
      return;
    }
    setState(() => _otpError = null);

    final otpToken = await _sessionManager.getOtpToken();
    if (otpToken == null) {
      Fluttertoast.showToast(
        msg: 'OTP token is missing',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }
    context.read<OtpBloc>().add(VerifyOtpButtonPressed(otp: otp, otpToken: otpToken));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.08,
                  vertical: MediaQuery.of(context).size.height * 0.05,
                ),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🎶', style: TextStyle(fontSize: 28)),
                          Text(
                            'Tune In – Just Verify & Play!',
                            style: appTheme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                              height: 1.3,
                            ),
                          ),
                          const Gap(16),
                          Text(
                            'We just sent a 6-digit code to your number. Enter it below to verify!',
                            style: appTheme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.normal,
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          const Gap(16),
                          Row(
                            children: [
                              const Icon(
                                Icons.phone_android,
                                color: Color.fromRGBO(88, 86, 214, 1),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.phone,
                                style: appTheme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () => context.go('/login'),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.edit,
                                      color: Color.fromRGBO(88, 86, 214, 1),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Edit',
                                      style: TextStyle(
                                        color: Color.fromRGBO(88, 86, 214, 1),
                                        decoration: TextDecoration.underline,
                                        decorationThickness: 2,
                                        decorationColor:
                                            Color.fromRGBO(88, 86, 214, 1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Gap(40),
                          PinCodeTextField(
                            appContext: context,
                            length: 6,
                            controller: _otpController,
                            autoDisposeControllers: false,
                            keyboardType: TextInputType.number,
                            enabled:
                                !(context.watch<OtpBloc>().state is OtpLoading),
                            animationType: AnimationType.fade,
                            pinTheme: PinTheme(
                              shape: PinCodeFieldShape.box,
                              borderRadius: BorderRadius.circular(8),
                              fieldHeight: 50,
                              fieldWidth: 40,
                              activeColor: Colors.black,
                              inactiveColor: Colors.grey[300]!,
                              selectedColor: Colors.black,
                              activeFillColor: Colors.grey[100]!,
                              inactiveFillColor: Colors.grey[100]!,
                              selectedFillColor: Colors.grey[100]!,
                            ),
                            animationDuration:
                                const Duration(milliseconds: 300),
                            enableActiveFill: true,
                            boxShadows: const [
                              BoxShadow(
                                  offset: Offset(0, 1),
                                  color: Colors.black12,
                                  blurRadius: 4),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _otpError = value.length == 6
                                    ? null
                                    : value.isEmpty
                                        ? 'OTP is required'
                                        : 'OTP must be 6 digits';
                              });
                            },
                          ),
                          if (_otpError != null)
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 8, left: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.cancel,
                                      color: Colors.red, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    _otpError!,
                                    style: appTheme.textTheme.bodyMedium
                                        ?.copyWith(
                                          color: Colors.red,
                                          fontSize: 14,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          const Gap(16),
                          Row(
                            children: [
                              Text(
                                "Didn't receive it? ",
                                style: appTheme.textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                              ),
                              TextButton(
                                onPressed: _resendSeconds == 0
                                    ? () {
                                        setState(() {
                                          _resendSeconds = 15;
                                          _startResendTimer();
                                        });
                                        context.read<OtpBloc>().add(
                                            RequestOtpButtonPressed(
                                                mobile: widget.phone));
                                      }
                                    : null,
                                child: Text(
                                  _resendSeconds == 0
                                      ? 'Resend OTP'
                                      : 'Resend OTP in ${_resendSeconds}s',
                                  style: TextStyle(
                                    color: Color.fromRGBO(88, 86, 214, 1),
                                    decorationThickness: 2,
                                    decorationColor:
                                        Color.fromRGBO(88, 86, 214, 1),
                                    decoration: _resendSeconds == 0
                                        ? TextDecoration.underline
                                        : null,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Gap(40),
                        ],
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: BlocBuilder<OtpBloc, OtpState>(
                          builder: (context, state) {
                            if (state is OtpLoading) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color.fromRGBO(88, 86, 214, 1),
                                  ),
                                ),
                              );
                            }
                            return ElevatedButton(
                              onPressed: _onSubmitOTP,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: Text(
                                'Submit',
                                style: appTheme.textTheme.titleMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        );
  }),
      );
  }
}