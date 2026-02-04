// lib/core/utils/session_manager.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kakan/config/constant_api.dart';
import 'package:kakan/core/network/api_service.dart';
import 'package:kakan/core/network/models/verify_otp_response.dart';
import 'dart:convert';
import 'package:kakan/injection_container.dart' as di;

class SessionManager {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Keys for storage
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _otpTokenKey = 'otp_token';
  static const String _profileIdKey = 'profile_id';
  static const String _userIdKey = 'user_id';
  static const String _verifyOtpResponseKey = 'verify_otp_response';

  Future<String?> getProfileImage() async {
    final profileId = await getProfileId();
    if (profileId == null) return null;
    try {
      final apiService = di.sl<ApiService>();
      final response = await apiService.get(
        ConstantApi.userProfile.replaceAll('{{user_id}}', profileId),
        includeAuth: true,
      );
      return response['profile_image']?.toString();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching profile image: $e');
      }
      return null;
    }
  }

  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  Future<void> saveOtpToken(String otpToken) async {
    await _storage.write(key: _otpTokenKey, value: otpToken);
  }

  Future<String?> getOtpToken() async {
    return await _storage.read(key: _otpTokenKey);
  }

  Future<void> clearOtpToken() async {
    await _storage.delete(key: _otpTokenKey);
  }

  Future<String?> getProfileId() async {
    return await _storage.read(key: _profileIdKey);
  }

  Future<void> saveProfileId(String profileId) async {
    await _storage.write(key: _profileIdKey, value: profileId);
  }

  Future<String?> getUserId() async {
    return await _storage.read(key: _userIdKey);
  }

  Future<void> saveUserId(String userId) async {
    await _storage.write(key: _userIdKey, value: userId);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  Future<void> clearTokens() async {
    await _storage.deleteAll();
  }

  Future<void> saveVerifyOtpResponse(VerifyOtpResponse response) async {
    try {
      final responseJson = response.toJson();
      final encodedResponse = jsonEncode(responseJson);
      await _storage.write(key: _verifyOtpResponseKey, value: encodedResponse);
      if (kDebugMode) {
        print('DEBUG: Saved VerifyOtpResponse to secure storage');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ERROR: Failed to save VerifyOtpResponse: $e');
      }
      rethrow;
    }
  }

  Future<VerifyOtpResponse?> getVerifyOtpResponse() async {
    try {
      final encodedResponse = await _storage.read(key: _verifyOtpResponseKey);
      if (encodedResponse == null) {
        if (kDebugMode) {
          print('DEBUG: No VerifyOtpResponse found in secure storage');
        }
        return null;
      }
      final responseJson = jsonDecode(encodedResponse);
      return VerifyOtpResponse.fromJson(responseJson);
    } catch (e) {
      if (kDebugMode) {
        print('ERROR: Failed to retrieve VerifyOtpResponse: $e');
      }
      return null;
    }
  }

  Future<void> clearVerifyOtpResponse() async {
    await _storage.delete(key: _verifyOtpResponseKey);
  }
}