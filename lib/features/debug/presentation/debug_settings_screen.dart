import 'package:flutter/material.dart';
import 'package:kakan/config/chucker_config.dart';

class DebugSettingsScreen extends StatefulWidget {
  const DebugSettingsScreen({super.key});

  @override
  _DebugSettingsScreenState createState() => _DebugSettingsScreenState();
}

class _DebugSettingsScreenState extends State<DebugSettingsScreen> {
  bool _chuckerEnabled = ChuckerConfig.isEnabled;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('Enable Chucker HTTP Inspector'),
              value: _chuckerEnabled,
              onChanged: (value) {
                setState(() {
                  _chuckerEnabled = value;
                  ChuckerConfig.setChuckerEnabled(value);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Chucker ${value ? 'enabled' : 'disabled'}. Restart app to apply changes.'),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Note: Chucker is only available in debug builds. Restart the app after changing settings.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}