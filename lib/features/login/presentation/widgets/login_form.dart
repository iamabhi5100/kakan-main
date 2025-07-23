import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/features/login/data/datasources/remote_data_source.dart';
import 'package:kakan/features/login/presentation/bloc/otp_bloc.dart';
import 'package:kakan/features/login/presentation/bloc/otp_event.dart';
import 'package:kakan/features/login/presentation/bloc/otp_state.dart';
import 'package:kakan/injection_container.dart' as di;

class LoginForm extends StatefulWidget {
  const LoginForm({Key? key}) : super(key: key);

  @override
  _LoginFormState createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _phoneController = TextEditingController();
  String? _phoneError;
  String? _checkboxError;
  bool _isAgreed = false;
  bool _isOtpRequestDisabled = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      final phone = _phoneController.text.trim();
      if (phone.isEmpty) {
        setState(() {
          _phoneError = 'Phone number is required';
        });
      } else if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
        setState(() {
          _phoneError = 'Enter a valid 10-digit phone number';
        });
      } else {
        setState(() {
          _phoneError = null;
        });
      }
    });
  }

  void _onSubmit() {
    if (_isOtpRequestDisabled) return;

    final phone = _phoneController.text.trim();
    bool hasError = false;

    if (phone.isEmpty) {
      setState(() {
        _phoneError = 'Phone number is required';
      });
      hasError = true;
    } else if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      setState(() {
        _phoneError = 'Enter a valid 10-digit phone number';
      });
      hasError = true;
    } else {
      setState(() {
        _phoneError = null;
      });
    }

    if (!_isAgreed) {
      setState(() {
        _checkboxError = 'Please agree to the Terms & Privacy Policy';
      });
      hasError = true;
    } else {
      setState(() {
        _checkboxError = null;
      });
    }

    if (hasError) return;

    final formattedPhone = '$phone';
    context.read<OtpBloc>().add(RequestOtpButtonPressed(mobile: formattedPhone));

    // Start 30-second cooldown
    setState(() {
      _isOtpRequestDisabled = true;
      _cooldownSeconds = 30;
    });

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 0) {
        setState(() {
          _isOtpRequestDisabled = false;
        });
        timer.cancel();
      } else {
        setState(() {
          _cooldownSeconds--;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Container(
          height: MediaQuery.of(context).size.height -
              MediaQuery.of(context).padding.top -
              MediaQuery.of(context).padding.bottom,
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.08,
            vertical: MediaQuery.of(context).size.height * 0.05,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🎶 \nHi, There \nLet’s get you inside the groove!',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                'Enter your phone number and we’ll send you a magic code for login.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
              ),
              const SizedBox(height: 40),
              Text(
                'Mobile No.*',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                enabled: context.watch<OtpBloc>().state is! OtpLoading,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  prefixIcon: const Icon(Icons.phone, color: Colors.grey),
                  labelText: 'Enter Your Mobile No',
                  labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[500],
                        fontSize: 16,
                      ),
                  errorStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red),
                ),
              ),
              if (_phoneError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cancel,
                        color: Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _phoneError!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    activeColor: Colors.black,
                    value: _isAgreed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: context.watch<OtpBloc>().state is OtpLoading
                        ? null
                        : (bool? value) {
                            setState(() {
                              _isAgreed = value ?? false;
                              _checkboxError = _isAgreed
                                  ? null
                                  : 'Please agree to the Terms & Privacy Policy';
                            });
                          },
                  ),
                  Expanded(
                    child: Text(
                      "By checking this box, you’re agreeing to all the T&C and Privacy Policy of our app",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                    ),
                  ),
                ],
              ),
              if (_checkboxError != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cancel,
                        color: Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _checkboxError!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: context.watch<OtpBloc>().state is OtpLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.black,
                          ),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: _isOtpRequestDisabled ? null : _onSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          _isOtpRequestDisabled
                              ? "Wait $_cooldownSeconds seconds"
                              : "Get OTP",
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }
}