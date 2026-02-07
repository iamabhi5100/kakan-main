// lib/features/followsuggestions/data/datasources/remote_data_source.dart
import 'package:dio/dio.dart';
import 'package:kakan/config/constant_api.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/network/api_service.dart';
import 'package:kakan/core/network/models/request_otp_request.dart';
import 'package:kakan/core/network/models/request_otp_response.dart';
import 'package:kakan/core/network/models/verify_otp_request.dart';
import 'package:kakan/core/network/models/verify_otp_response.dart';
import 'package:kakan/core/network/network_info.dart';
import 'package:kakan/core/utils/session_manager.dart';
import 'package:kakan/features/followsuggestions/data/models/suggestion_model.dart';

class VerifyOtpResponseWrapper {
  final String token;
  final bool hasProfile;

  VerifyOtpResponseWrapper({required this.token, required this.hasProfile});

  factory VerifyOtpResponseWrapper.fromVerifyOtpResponse(VerifyOtpResponse response) {
    return VerifyOtpResponseWrapper(
      token: response.accessToken,
      hasProfile: response.isExisted,
    );
  }
}

abstract class RemoteDataSource {
  Future<String> requestOtp(String mobile, {CancelToken? cancelToken});
  Future<VerifyOtpResponseWrapper> verifyOtp(String otp, String otpToken, {CancelToken? cancelToken});
  Future<String> createProfile(String token, Map<String, dynamic> profileData, {CancelToken? cancelToken});
  Future<bool> checkUsername(String username, {CancelToken? cancelToken});
  Future<List<SuggestionModel>> getFollowSuggestions({CancelToken? cancelToken});
  Future<String> followUser(String userId, {CancelToken? cancelToken});
  Future<String> unfollowUser(String userId, {CancelToken? cancelToken});
}

class RemoteDataSourceImpl implements RemoteDataSource {
  final ApiService apiService;
  final SessionManager sessionManager;
  final NetworkInfo networkInfo;

  RemoteDataSourceImpl({
    required this.apiService,
    required this.sessionManager,
    required this.networkInfo,
  });

  @override
  Future<String> requestOtp(String mobile, {CancelToken? cancelToken}) async {
    if (!(await networkInfo.isConnected)) {
      throw ServerException(message: 'No internet connection');
    }
    if (!RegExp(r'^\d{10}$').hasMatch(mobile)) {
      throw ServerException(message: 'Please Enter valid Phone Number number format');
    }
    try {
      final response = await apiService.post(
        ConstantApi.getOtp,
        RequestOtpRequest(phone: mobile).toJson(),
        includeAuth: false,
        cancelToken: cancelToken,
      );
      final otpResponse = RequestOtpResponse.fromJson(response);
      await sessionManager.saveTokens(accessToken: otpResponse.otpToken);
      print('OTP request successful, otpToken: ${otpResponse.otpToken}');
      return "OTP sent successfully";
    } catch (e, stackTrace) {
      print('Error during OTP request: $e\nStack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<VerifyOtpResponseWrapper> verifyOtp(String otp, String otpToken, {CancelToken? cancelToken}) async {
    if (!(await networkInfo.isConnected)) {
      throw ServerException(message: 'No internet connection');
    }
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      throw ServerException(message: 'Invalid OTP format');
    }
    if (otpToken.isEmpty) {
      throw ServerException(message: 'OTP token is missing');
    }
    try {
      final response = await apiService.post(
        ConstantApi.verifyOtp,
        VerifyOtpRequest(otp: otp, otpToken: otpToken).toJson(),
        includeAuth: false,
        cancelToken: cancelToken,
      );
      final verifyResponse = VerifyOtpResponse.fromJson(response);
      await sessionManager.saveTokens(
        accessToken: verifyResponse.accessToken,
        refreshToken: verifyResponse.refreshToken,
      );
      print('OTP verification successful, accessToken: ${verifyResponse.accessToken}');
      return VerifyOtpResponseWrapper.fromVerifyOtpResponse(verifyResponse);
    } catch (e, stackTrace) {
      print('Error during OTP verification: $e\nStack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<String> createProfile(String token, Map<String, dynamic> profileData, {CancelToken? cancelToken}) async {
    if (!(await networkInfo.isConnected)) {
      throw ServerException(message: 'No internet connection');
    }
    if (token.isEmpty) {
      throw ServerException(message: 'Authentication token is missing');
    }
    if (profileData.isEmpty || profileData['username'] == null || profileData['name'] == null) {
      throw ServerException(message: 'Invalid profile data: username and name are required');
    }
    try {
      final response = await apiService.post(
        ConstantApi.userProfile,
        profileData,
        includeAuth: true,
        cancelToken: cancelToken,
      );
      print('Profile creation successful: $response');
      return "Profile created successfully";
    } catch (e, stackTrace) {
      print('Error during profile creation: $e\nStack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<bool> checkUsername(String username, {CancelToken? cancelToken}) async {
    if (!(await networkInfo.isConnected)) {
      throw ServerException(message: 'No internet connection');
    }
    if (username.trim().isEmpty) {
      throw ServerException(message: 'Username cannot be empty');
    }
    try {
      await apiService.post(
        '/v${ConstantApi.apiVersion}/user/auth/check-username/',
        {'username': username.trim()},
        includeAuth: false,
        cancelToken: cancelToken,
      );
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        return false;
      }
      throw ServerException(message: 'Error checking username: ${e.message}');
    } catch (e, stackTrace) {
      print('Error during username check: $e\nStack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<List<SuggestionModel>> getFollowSuggestions({CancelToken? cancelToken}) async {
    if (!(await networkInfo.isConnected)) {
      throw ServerException(message: 'No internet connection');
    }
    List<SuggestionModel> allSuggestions = [];
    String? nextUrl = ConstantApi.followSuggestions;

    try {
      while (nextUrl != null) {
        final response = await apiService.get(
          nextUrl.startsWith('https://') ? Uri.parse(nextUrl).path + (Uri.parse(nextUrl).query.isNotEmpty ? '?${Uri.parse(nextUrl).query}' : '') : nextUrl,
          includeAuth: true,
          cancelToken: cancelToken,
        );
        final suggestions = (response['results'] as List<dynamic>)
            .map((json) => SuggestionModel.fromJson(json as Map<String, dynamic>))
            .toList();
        allSuggestions.addAll(suggestions);
        nextUrl = response['next'];
      }
      print('Fetched ${allSuggestions.length} follow suggestions');
      return allSuggestions;
    } catch (e, stackTrace) {
      print('Error fetching follow suggestions: $e\nStack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<String> followUser(String userId, {CancelToken? cancelToken}) async {
    if (!(await networkInfo.isConnected)) {
      throw ServerException(message: 'No internet connection');
    }
    if (userId.isEmpty) {
      throw ServerException(message: 'User ID is missing');
    }
    final currentUserId = await sessionManager.getUserId();
    if (userId == currentUserId) {
      throw ServerException(message: 'Cannot follow yourself');
    }
    final followUrl = ConstantApi.followUser.replaceFirst('%s', userId);
    try {
      final response = await apiService.post(
        followUrl,
        {'followed_to': userId},
        includeAuth: true,
        cancelToken: cancelToken,
      );
      print('Follow successful for user: $userId, response: $response');
      return response['message'] as String? ?? 'User Followed successfully';
    } catch (e, stackTrace) {
      print('Error during follow: $e\nStack trace: $stackTrace');
      throw ServerException(message: 'Failed to follow user: $e');
    }
  }

  @override
  Future<String> unfollowUser(String userId, {CancelToken? cancelToken}) async {
    if (!(await networkInfo.isConnected)) {
      throw ServerException(message: 'No internet connection');
    }
    if (userId.isEmpty) {
      throw ServerException(message: 'User ID is missing');
    }
    final currentUserId = await sessionManager.getUserId();
    if (userId == currentUserId) {
      throw ServerException(message: 'Cannot unfollow yourself');
    }
    final unfollowUrl = ConstantApi.unfollowUser.replaceFirst('%s', userId);
    try {
      final response = await apiService.post(
        unfollowUrl,
        {'followed_to': userId},
        includeAuth: true,
        cancelToken: cancelToken,
      );
      print('Unfollow successful for user: $userId, response: $response');
      return response['message'] as String? ?? 'User Unfollowed successfully';
    } catch (e, stackTrace) {
      print('Error during unfollow: $e\nStack trace: $stackTrace');
      throw ServerException(message: 'Failed to unfollow user: $e');
    }
  }
}
