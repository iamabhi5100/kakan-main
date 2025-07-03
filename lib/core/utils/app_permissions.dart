import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';

class AppPermissions {
  static final Logger _logger = Logger();

  static Future<List<Permission>> getRequiredPermissions() async {
    final List<Permission> permissions = [];

    if (Platform.isAndroid) {
      final androidVersion = int.tryParse(Platform.operatingSystemVersion.split(' ').first) ?? 13;

      if (androidVersion >= 13) {
        permissions.addAll([
          Permission.photos,
          Permission.videos,
          Permission.audio,
        ]);
      } else {
        permissions.add(Permission.storage);
      }

      if (androidVersion >= 11) {
        permissions.add(Permission.manageExternalStorage);
      }
    }

    _logger.i('Required permissions: $permissions');
    return permissions;
  }

  static Future<bool> areAllPermissionsGranted() async {
    final permissions = await getRequiredPermissions();
    bool allGranted = true;

    for (var permission in permissions) {
      final status = await permission.status;
      _logger.i('Permission $permission status: $status');
      if (!status.isGranted && !status.isLimited) {
        allGranted = false;
      }
    }

    _logger.i('All permissions granted: $allGranted');
    return allGranted;
  }

  static Future<bool> requestAllPermissions(BuildContext context) async {
    final permissions = await getRequiredPermissions();
    _logger.i('Requesting permissions: $permissions');

    bool allGranted = true;
    for (var permission in permissions) {
      if (!(await permission.status).isGranted) {
        final status = await permission.request();
        _logger.i('Permission $permission result: $status');

        if (!status.isGranted && !status.isLimited) {
          allGranted = false;
          if (status.isPermanentlyDenied) {
            _logger.w('Permission $permission is permanently denied');
            await handlePermanentlyDenied(context, permission);
          } else {
            _logger.w('Permission $permission is denied');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Please grant ${permission.toString().split('.').last} permission to access your ${permission == Permission.photos ? 'photos' : permission == Permission.videos ? 'videos' : permission == Permission.audio ? 'audio' : 'files'}.',
                ),
                action: SnackBarAction(
                  label: 'Retry',
                  onPressed: () => requestAllPermissions(context),
                ),
              ),
            );
          }
        }
      }
    }

    if (Platform.isAndroid && permissions.contains(Permission.manageExternalStorage)) {
      final manageStorageStatus = await Permission.manageExternalStorage.status;
      if (!manageStorageStatus.isGranted) {
        _logger.i('Requesting MANAGE_EXTERNAL_STORAGE');
        await _requestManageExternalStorage(context);
        if (!await Permission.manageExternalStorage.isGranted) {
          allGranted = false;
          _logger.w('MANAGE_EXTERNAL_STORAGE permission denied');
        }
      }
    }

    _logger.i('All permissions granted after request: $allGranted');
    return allGranted;
  }

  static Future<void> _requestManageExternalStorage(BuildContext context) async {
    _logger.i('Requesting MANAGE_EXTERNAL_STORAGE permission');
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('File Access Permission'),
        content: const Text(
          'This app needs access to all files for uploading content. Please enable "Allow all files access" in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              _logger.i('Opening app settings for MANAGE_EXTERNAL_STORAGE');
              try {
                await openAppSettings();
                _logger.i('Opened app settings successfully');
              } catch (e) {
                _logger.e('Error opening app settings: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to open settings: $e')),
                );
              }
            },
            child: const Text('Go to Settings'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _logger.i('User cancelled MANAGE_EXTERNAL_STORAGE permission prompt');
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  static Future<void> handlePermanentlyDenied(BuildContext context, Permission permission) async {
    if (await permission.isPermanentlyDenied) {
      _logger.i('Opening app settings for permanently denied permission: $permission');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${permission.toString().split('.').last} permission is permanently denied. Please enable it in app settings.',
          ),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () {
              _logger.i('Navigating to app settings');
              openAppSettings();
            },
          ),
        ),
      );
    }
  }
}