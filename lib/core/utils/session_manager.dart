import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kakan/core/network/models/verify_otp_response.dart';
import 'dart:convert';

class SessionManager {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Keys for storage
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _otpTokenKey = 'otp_token';
  static const String _userIdKey = 'user_id';
  static const String _authUserIdKey = 'auth_user_id'; // New key for userDetails.user
  static const String _verifyOtpResponseKey = 'verify_otp_response';

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

  Future<String?> getUserId() async {
    return await _storage.read(key: _userIdKey);
  }

  Future<void> saveUserId(String userId) async {
    await _storage.write(key: _userIdKey, value: userId);
  }

  Future<String?> getAuthUserId() async {
    return await _storage.read(key: _authUserIdKey);
  }

  Future<void> saveAuthUserId(String authUserId) async {
    await _storage.write(key: _authUserIdKey, value: authUserId);
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
      print('DEBUG: Saved VerifyOtpResponse to secure storage');
    } catch (e) {
      print('ERROR: Failed to save VerifyOtpResponse: $e');
      rethrow;
    }
  }

  Future<VerifyOtpResponse?> getVerifyOtpResponse() async {
    try {
      final encodedResponse = await _storage.read(key: _verifyOtpResponseKey);
      if (encodedResponse == null) {
        print('DEBUG: No VerifyOtpResponse found in secure storage');
        return null;
      }
      final responseJson = jsonDecode(encodedResponse);
      return VerifyOtpResponse.fromJson(responseJson);
    } catch (e) {
      print('ERROR: Failed to retrieve VerifyOtpResponse: $e');
      return null;
    }
  }

  Future<void> clearVerifyOtpResponse() async {
    await _storage.delete(key: _verifyOtpResponseKey);
  }
}