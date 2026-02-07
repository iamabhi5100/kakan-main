// lib/features/login/presentation/widgets/successfull_login.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

class SuccessfullLogin extends StatefulWidget {
  const SuccessfullLogin({super.key});

  @override
  State<SuccessfullLogin> createState() => _SuccessfullLoginState();
}

class _SuccessfullLoginState extends State<SuccessfullLogin> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        GoRouter.of(context).go('/onboarding');
      }
    });
  }

  @override
  void dispose() {
    _controller.stop(); // Stop animation
    _controller.dispose(); // Dispose controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/images/success_animation.json',
                controller: _controller,
                onLoaded: (composition) {
                  _controller
                    ..duration = composition.duration
                    ..forward();
                },
                fit: BoxFit.contain,
                repeat: false,
                frameRate: FrameRate(30), // Reduce frame rate for performance
              ),
              const SizedBox(height: 20),
              const Text(
                'Login Successful!',
                style: TextStyle(
                  fontFamily: 'Product Sans',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}