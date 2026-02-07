import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kakan/config/theme.dart';
import 'package:kakan/features/login/presentation/pages/login_page.dart';
import 'package:kakan/features/profile/presentation/profile_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> _logout() async {
    await _storage.delete(key: 'auth_token');
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            
          },
        ),
        title: Text(
          'Menu',
          style: appTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      
      ),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          ListTile(
            leading: Icon(Icons.person),
            title:  Text('Profile',style: appTheme.textTheme.titleLarge?.copyWith(
              fontSize: 18,
            )),
            trailing: const Icon(Icons.chevron_right, color: Colors.black),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => ProfileScreen()));
            },
          ),
          // const Divider(thickness: 0.5),
          ListTile(
            leading: Icon(Icons.notifications),
            title:  Text('Notifications',style: appTheme.textTheme.titleLarge?.copyWith(
              fontSize: 18,
            )),
            trailing: const Icon(Icons.chevron_right, color: Colors.black),
            onTap: () {},
          ),
          const Divider(thickness: 8),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Text('Contact us',style: appTheme.textTheme.titleLarge?.copyWith(
                fontSize: 20,
                color: Colors.grey[700],
              )),
          ),
          
          
          // const Divider(thickness: 0.5),
          ListTile(
            leading: Icon(Icons.question_answer),
            title:  Text('FAQs',style: appTheme.textTheme.titleLarge?.copyWith(
              fontSize: 18,
            )),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {},
          ),
          // const Divider(thickness: 0.5),
          ListTile(
            leading: Icon(Icons.contact_page_outlined),
            title: Text('Contact Details',style: appTheme.textTheme.titleLarge?.copyWith(
              fontSize: 18,
            )),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {},
          ),
          // const Divider(thickness: 0.5),
          ListTile(
            leading: Icon(Icons.support_agent),
            title: Text('Supports',style: appTheme.textTheme.titleLarge?.copyWith(
              fontSize: 18,
            )),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {},
          ),
          // const Divider(thickness: 0.5),
            const Divider(thickness: 8),
           Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Text('Legal',style: appTheme.textTheme.titleLarge?.copyWith(
                fontSize: 20,
                color: Colors.grey[700],
              )),
          ),
          // const Divider(thickness: 0.5),
          ListTile(
            leading: Icon(Icons.info),
            title:  Text('About us',style: appTheme.textTheme.titleLarge?.copyWith(
              fontSize: 18,
            )),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {},
          ),
          // const Divider(thickness: 0.5),
          ListTile(
            leading: Icon(Icons.security),
            title:  Text('Privacy Policy',style: appTheme.textTheme.titleLarge?.copyWith(
              fontSize: 18,
            )),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {},
          ),
          // const Divider(thickness: 0.5),
          ListTile(
            leading: Icon(Icons.import_contacts),
            title: Text('Terms & Condition',style: appTheme.textTheme.titleLarge?.copyWith(
              fontSize: 18,
            )),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {},
          ),
          // const Divider(thickness: 0.5),
          ListTile(
            leading: Icon(Icons.logout),
            title:  Text('Logout',style: appTheme.textTheme.titleLarge?.copyWith(
              fontSize: 18,
            )),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            textColor: Colors.red,
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}