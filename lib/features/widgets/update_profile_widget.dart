import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kakan/config/theme.dart';
import 'package:kakan/features/profile/presentation/pages/update_profile_screen.dart';

class UpdateNavProfileWidget extends StatefulWidget {
  const UpdateNavProfileWidget({super.key});

  @override
  State<UpdateNavProfileWidget> createState() => _UpdateNavProfileWidgetState();
}

class _UpdateNavProfileWidgetState extends State<UpdateNavProfileWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 234, 237, 253),
        border: Border.all(color: appTheme.primaryColor, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: appTheme.primaryColor, width: 2),
            ),
            child: CircleAvatar(
              radius: 25,
              backgroundImage: const NetworkImage(
                'https://picsum.photos/200',
              ),
              backgroundColor: Colors.grey,
              onBackgroundImageError: (exception, stackTrace) {
                if (kDebugMode) {
                  print("UpdateNavProfileWidget: Error loading profile image: $exception");
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We’re almost there to complete your profile',
                  style: appTheme.textTheme.titleLarge?.copyWith(
                    fontSize: 18,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (kDebugMode) {
                      print('UpdateNavProfileWidget: Navigating to UpdateProfileScreen');
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const UpdateProfileScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'Update profile',
                    style: TextStyle(
                      fontFamily: 'Product Sans',
                      color: appTheme.primaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                      decorationColor: appTheme.primaryColor,
                      decorationThickness: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}