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
import 'package:kakan/injection_container.dart' as di;

class OnboardingForm extends StatefulWidget {
  final String token;
  final RemoteDataSource remoteDataSource;

  const OnboardingForm({
    required this.token,
    required this.remoteDataSource,
    super.key,
  });

  @override
  State<OnboardingForm> createState() => _OnboardingFormState();
}

class _OnboardingFormState extends State<OnboardingForm>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final SessionManager _sessionManager = SessionManager();

  String? _usernameStatus;
  bool _isUsernameAvailable = false;
  bool _isCheckingUsername = false;
  late AnimationController _rotationController;

  String? _fullNameError;
  String? _emailError;
  String? _usernameSpaceError;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _fullNameController.addListener(_debouncedValidateFullName);
    _emailController.addListener(_debouncedValidateEmail);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  void _debouncedValidateFullName() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _validateFullName(_fullNameController.text);
      setState(() {}); // refresh button state
    });
  }

  void _debouncedValidateEmail() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _validateEmail(_emailController.text);
      setState(() {}); // refresh button state
    });
  }

  Future<void> _checkUsername(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length < 5) {
      setState(() {
        _usernameStatus = null;
        _isUsernameAvailable = false;
        _isCheckingUsername = false;
        _rotationController.stop();
        _usernameSpaceError = null;
      });
      return;
    }

    if (trimmed.contains(' ')) {
      setState(() {
        _usernameStatus = null;
        _isUsernameAvailable = false;
        _isCheckingUsername = false;
        _rotationController.stop();
        _usernameSpaceError = 'Username cannot contain spaces';
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _rotationController.repeat();
      _usernameSpaceError = null;
    });

    try {
      final isAvailable =
          await widget.remoteDataSource.checkUsername(trimmed);
      setState(() {
        _usernameStatus =
            isAvailable ? 'Username is available' : 'Username is not available';
        _isUsernameAvailable = isAvailable;
      });
    } catch (_) {
      setState(() {
        _usernameStatus = 'Username already exists';
        _isUsernameAvailable = false;
      });
    } finally {
      setState(() {
        _isCheckingUsername = false;
        _rotationController.stop();
      });
    }
  }

  Future<void> _onRefreshUsername() async =>
      await _checkUsername(_usernameController.text);

  void _validateFullName(String value) {
    if (value.trim().isEmpty) {
      _fullNameError = 'Full Name is required';
    } else {
      _fullNameError = null;
    }
  }

  void _validateEmail(String value) {
    if (value.trim().isNotEmpty &&
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
            .hasMatch(value.trim())) {
      _emailError = 'Enter a valid email address';
    } else {
      _emailError = null;
    }
  }

  bool get _canSubmit {
    final nameValid = _fullNameController.text.trim().isNotEmpty &&
        _fullNameError == null;
    final emailValid = _emailController.text.trim().isEmpty ||
        _emailError == null;
    final usernameValid = _isUsernameAvailable && _usernameSpaceError == null;
    return usernameValid && nameValid && emailValid;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => di.sl<OtpBloc>(),
      child: BlocListener<OtpBloc, OtpState>(
        listener: (context, state) {
          if (state is ProfileCreated) {
            _sessionManager.saveTokens(accessToken: widget.token);
            context.go('/successful-login');
          } else if (state is OtpFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Form(
                        key: _formKey,
                        autovalidateMode:
                            AutovalidateMode.onUserInteraction,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            // Heading
                            Text(
                              '💫\nAlmost there! Let’s set up your unique user id.',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const Gap(20),
                            Text(
                              'Just a quick setup and you’re ready to rock!',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.normal,
                                    color: Colors.grey[600],
                                    fontSize: 17,
                                  ),
                            ),
                            const Gap(50),

                            // Username
                            Text('Username *',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge),
                            TextFormField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                suffixIcon: IconButton(
                                  onPressed: _isCheckingUsername || _usernameSpaceError != null
                                      ? null
                                      : _onRefreshUsername,
                                  icon: RotationTransition(
                                    turns: Tween(begin: 0.0, end: 1.0)
                                        .animate(_rotationController),
                                    child: Icon(
                                      Icons.autorenew,
                                      color: _isCheckingUsername
                                          ? Colors.grey
                                          : Colors.green,
                                    ),
                                  ),
                                ),
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.never,
                                labelText:
                                    'What should we call you in the spotlight?',
                                border: const OutlineInputBorder(),
                                labelStyle:
                                    const TextStyle(color: Colors.grey),
                              ),
                              onChanged: (value) {
                                if (_debounce?.isActive ?? false)
                                  _debounce!.cancel();
                                _debounce = Timer(
                                    const Duration(milliseconds: 500), () {
                                  _checkUsername(value);
                                  setState(() {}); // update button
                                });
                              },
                              enabled: context.watch<OtpBloc>().state
                                  is! OtpLoading,
                            ),
                            if (_usernameStatus != null || _usernameSpaceError != null) ...[
                              const Gap(8),
                              Row(
                                children: [
                                  Icon(
                                    _isUsernameAvailable && _usernameSpaceError == null
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: _isUsernameAvailable && _usernameSpaceError == null
                                        ? Colors.green
                                        : Colors.red,
                                    size: 20,
                                  ),
                                  const Gap(5),
                                  Text(
                                    _usernameSpaceError ?? _usernameStatus!,
                                    style: TextStyle(
                                      color: _isUsernameAvailable && _usernameSpaceError == null
                                          ? Colors.green
                                          : Colors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const Gap(20),

                            // Full Name
                            Text('Full Name *',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge),
                            TextFormField(
                              controller: _fullNameController,
                              decoration: const InputDecoration(
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.never,
                                labelText: 'Enter your Full Name',
                                border: OutlineInputBorder(),
                                labelStyle: TextStyle(color: Colors.grey),
                              ),
                              onChanged: (_) => setState(() {}),
                              enabled: context.watch<OtpBloc>().state
                                  is! OtpLoading,
                            ),
                            if (_fullNameError != null) ...[
                              const Gap(8),
                              Row(
                                children: [
                                  const Icon(Icons.cancel,
                                      color: Colors.red, size: 20),
                                  const Gap(5),
                                  Text(
                                    _fullNameError!,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.red,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ],
                            const Gap(20),

                            // Email
                            Text('Email',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge),
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.never,
                                labelText: 'Enter your mail ID',
                                border: OutlineInputBorder(),
                                labelStyle: TextStyle(color: Colors.grey),
                              ),
                              onChanged: (_) => setState(() {}),
                              enabled: context.watch<OtpBloc>().state
                                  is! OtpLoading,
                            ),
                            if (_emailError != null) ...[
                              const Gap(8),
                              Row(
                                children: [
                                  const Icon(Icons.cancel,
                                      color: Colors.red, size: 20),
                                  const Gap(5),
                                  Text(
                                    _emailError!,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.red,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ],
                            const Gap(50),

                            // Submit
                            Container(
                              padding: const EdgeInsets.all(8),
                              child: SizedBox(
                                width: double.infinity,
                                child: context.watch<OtpBloc>().state
                                        is OtpLoading
                                    ? const Center(
                                        child:
                                            CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<
                                                  Color>(Colors.pink),
                                        ),
                                      )
                                    : Container(
                                        decoration: BoxDecoration(
                                          color: _canSubmit
                                              ? appTheme.primaryColor
                                              : Colors.grey,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: MaterialButton(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    40),
                                          ),
                                          onPressed: _canSubmit
                                              ? () {
                                                  if (_formKey
                                                          .currentState!
                                                          .validate() &&
                                                      _canSubmit) {
                                                    final profileData = {
                                                      'username':
                                                          _usernameController
                                                              .text
                                                              .trim(),
                                                      'name':
                                                          _fullNameController
                                                              .text
                                                              .trim(),
                                                      'email': _emailController
                                                              .text
                                                              .trim()
                                                              .isEmpty
                                                          ? null
                                                          : _emailController
                                                              .text
                                                              .trim(),
                                                    };
                                                    context
                                                        .read<OtpBloc>()
                                                        .add(
                                                          CreateProfileButtonPressed(
                                                            token:
                                                                widget
                                                                    .token,
                                                            profileData:
                                                                profileData,
                                                          ),
                                                        );
                                                  }
                                                }
                                              : null,
                                          child: Text(
                                            "Let’s Go",
                                            style: appTheme
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  color: Colors.white,
                                                ),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}