import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kakan/config/theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 3;

  final List<Map<String, String>> onboardingData = [
    {
      'image': 'assets/images/onboarding1.png',
      'title': 'Connect with Creators',
      'subtitle': 'Follow your favorite artists, discover new creators, and stay in the loop with trending music and videos!',
    },
    {
      'image': 'assets/images/onboarding2.png',
      'title': 'Chat & Share the Vibe',
      'subtitle': 'Talk about the latest hits, drop comments, and share your favorite moments with friends & fans!',
    },
    {
      'image': 'assets/images/onboarding3.png',
      'title': 'Play, Download & Create Ringtones!',
      'subtitle': 'Stream, download, and turn your favorite tracks into ringtones—all in one place!',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildDotIndicator(int index) {
    bool isCurrent = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isCurrent ? 35 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isCurrent ? appTheme.primaryColor : Colors.grey,
        borderRadius: BorderRadius.circular(isCurrent ? 4 : 8),
      ),
    );
  }

  Widget _buildFinishButton() {
    const double buttonHeight = 50;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: buttonHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: appTheme.primaryColor, width: 1),
                borderRadius: const BorderRadius.all(Radius.circular(4)),
              ),
              child: InkWell(
                onTap: () {
                  if (_currentPage > 0) {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.ease,
                    );
                  }
                },
                child: Center(
                  child: Text(
                    'Back',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: appTheme.primaryColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: buttonHeight,
              decoration: BoxDecoration(
                color: appTheme.primaryColor,
                borderRadius: const BorderRadius.all(Radius.circular(4)),
              ),
              child: InkWell(
                onTap: () {
                  context.go('/follow-suggestions');
                },
                child: const Center(
                  child: Text(
                    "Let's Started",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextButton() {
    const double buttonHeight = 50;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      width: double.infinity,
      child: Container(
        height: buttonHeight,
        decoration: BoxDecoration(
          color: appTheme.primaryColor,
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        child: InkWell(
          onTap: () {
            if (_currentPage < _totalPages - 1) {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 500),
                curve: Curves.ease,
              );
            }
          },
          child: const Center(
            child: Text(
              'Next',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiddleButtons() {
    const double buttonHeight = 50;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: buttonHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: appTheme.primaryColor, width: 1),
                borderRadius: const BorderRadius.all(Radius.circular(4)),
              ),
              child: InkWell(
                onTap: () {
                  if (_currentPage > 0) {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.ease,
                    );
                  }
                },
                child: Center(
                  child: Text(
                    'Back',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: appTheme.primaryColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: buttonHeight,
              decoration: BoxDecoration(
                color: appTheme.primaryColor,
                borderRadius: const BorderRadius.all(Radius.circular(4)),
              ),
              child: InkWell(
                onTap: () {
                  if (_currentPage < _totalPages - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.ease,
                    );
                  }
                },
                child: const Center(
                  child: Text(
                    'Next',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _totalPages,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final data = onboardingData[index];
                  return SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          data['image']!,
                          height: 400,
                          fit: BoxFit.cover,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          data['title']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 24.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          data['subtitle']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 18.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            _currentPage == 0
                ? _buildNextButton()
                : _currentPage == _totalPages - 1
                    ? _buildFinishButton()
                    : _buildMiddleButtons(),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _totalPages,
                (index) => _buildDotIndicator(index),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}