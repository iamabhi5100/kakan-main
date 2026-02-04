import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kakan/config/theme.dart';
import 'package:kakan/core/utils/media_manager.dart';
import 'package:kakan/core/utils/session_manager.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:fluttertoast/fluttertoast.dart';

class DrawerNavigationWidget extends StatelessWidget {
  final BuildContext parentContext; // Stable context from HomeScreen

  const DrawerNavigationWidget({super.key, required this.parentContext});

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: parentContext,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      showDialog(
        context: parentContext,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Logging out...'),
            ],
          ),
        ),
      );

      // Pause media
      MediaManager().pauseAll();

      // Clear all stored data from SessionManager
      final sessionManager = di.sl<SessionManager>();
      await sessionManager.clearTokens();
      await sessionManager.clearVerifyOtpResponse();

      Navigator.pop(parentContext); // Close loading dialog
      Fluttertoast.showToast(
        msg: 'Logged out successfully',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      GoRouter.of(parentContext).go('/login', extra: {'showLogoutSuccess': true});
    } catch (e) {
      Navigator.pop(parentContext); // Close loading dialog
      Fluttertoast.showToast(
        msg: 'Logout failed: $e',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: appTheme.primaryColor),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(
                      'ND',
                      style: appTheme.textTheme.titleMedium?.copyWith(
                        color: appTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'nd_rockstar',
                    style: appTheme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'nd_rockstar@kakan.com',
                    style: appTheme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            ListView(
              padding: const EdgeInsets.all(8),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(
                    'Profile',
                    style: appTheme.textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.black),
                  onTap: () {
                    Navigator.pop(context);
                    GoRouter.of(parentContext).go('/profile');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: Text(
                    'Notifications',
                    style: appTheme.textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.black),
                  onTap: () {
                    Navigator.pop(context);
                    GoRouter.of(parentContext).go('/notifications');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.group),
                  title: Text(
                    'Follow Suggestions',
                    style: appTheme.textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.black),
                  onTap: () {
                    Navigator.pop(context);
                    GoRouter.of(parentContext).go('/follow-suggestions');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.search),
                  title: Text(
                    'Search',
                    style: appTheme.textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.black),
                  onTap: () {
                    Navigator.pop(context);
                    GoRouter.of(parentContext).go('/search');
                  },
                ),
                const Divider(thickness: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 18),
                  child: Text(
                    'Contact us',
                    style: appTheme.textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.question_answer),
                  title: Text(
                    'FAQs',
                    style: appTheme.textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(context);
                    GoRouter.of(parentContext).go('/faqs');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.contact_page_outlined),
                  title: Text(
                    'Contact Details',
                    style: appTheme.textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(context);
                    GoRouter.of(parentContext).go('/contact-details');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.support_agent),
                  title: Text(
                    'Supports',
                    style: appTheme.textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(context);
                    GoRouter.of(parentContext).go('/supports');
                  },
                ),
                const Divider(thickness: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 18),
                  child: Text(
                    'Legal',
                    style: appTheme.textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.info),
                  title: Text(
                    'About us',
                    style: appTheme.textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(context);
                    GoRouter.of(parentContext).go('/about-us');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.security),
                  title: Text(
                    'Privacy Policy',
                    style: appTheme.textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(context);
                    GoRouter.of(parentContext).go('/privacy-policy');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.import_contacts),
                  title: Text(
                    'Terms & Condition',
                    style: appTheme.textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(context);
                    GoRouter.of(parentContext).go('/terms');
                  },
                ),
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.red[400]),
                  title: Text(
                    'Logout',
                    style: appTheme.textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  textColor: Colors.red,
                  onTap: () {
                    Navigator.pop(context); // Close the drawer
                    _logout();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}