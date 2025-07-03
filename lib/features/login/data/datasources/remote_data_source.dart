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
  final String userId;

  VerifyOtpResponseWrapper({
    required this.token,
    required this.hasProfile,
    required this.userId,
  });

  factory VerifyOtpResponseWrapper.fromVerifyOtpResponse(VerifyOtpResponse response) {
    return VerifyOtpResponseWrapper(
      token: response.accessToken,
      hasProfile: response.isExisted,
      userId: response.userDetails?.id ?? '',
    );
  }
}

abstract class RemoteDataSource {
  Future<String> requestOtp(String mobile, {CancelToken? cancelToken});
  Future<VerifyOtpResponseWrapper> verifyOtp(String otp, String otpToken, {CancelToken? cancelToken});
  Future<String> createProfile(String token, Map<String, dynamic> profileData, {CancelToken? cancelToken});
  Future<bool> checkUsername(String username, {CancelToken? cancelToken});
  Future<List<SuggestionModel>> getFollowSuggestions({CancelToken? cancelToken});
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
      await sessionManager.saveOtpToken(otpResponse.otpToken);
      print('OTP request successful, otpToken: ${otpResponse.otpToken}');
      return "OTP sent successfully";
    } catch (e) {
      print('Error during OTP request: $e');
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
      await sessionManager.saveVerifyOtpResponse(verifyResponse);
      await sessionManager.saveTokens(
        accessToken: verifyResponse.accessToken,
        refreshToken: verifyResponse.refreshToken,
      );
      if (verifyResponse.userDetails != null) {
        await sessionManager.saveUserId(verifyResponse.userDetails!.id);
        await sessionManager.saveAuthUserId(verifyResponse.userDetails!.user); // Save authUserId
      }
      await sessionManager.clearOtpToken();
      print('OTP verification successful, accessToken: ${verifyResponse.accessToken}, userId: ${verifyResponse.userDetails?.id}, authUserId: ${verifyResponse.userDetails?.user}');
      return VerifyOtpResponseWrapper.fromVerifyOtpResponse(verifyResponse);
    } catch (e) {
      print('Error during OTP verification: $e');
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
        '/v${ConstantApi.apiVersion}/user/',
        profileData,
        includeAuth: true,
        cancelToken: cancelToken,
      );
      print('Profile creation successful');
      return "Profile created successfully";
    } catch (e) {
      print('Error during profile creation: $e');
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
    } catch (e) {
      print('Error during username check: $e');
      rethrow;
    }
  }

  @override
  Future<List<SuggestionModel>> getFollowSuggestions({CancelToken? cancelToken}) async {
    if (!(await networkInfo.isConnected)) {
      throw ServerException(message: 'No internet connection');
    }
    try {
      final response = await apiService.get(
        ConstantApi.followSuggestions,
        includeAuth: true,
        cancelToken: cancelToken,
      );
      final suggestions = (response['results'] as List<dynamic>)
          .map((json) => SuggestionModel.fromJson(json as Map<String, dynamic>))
          .toList();
      print('Fetched ${suggestions.length} follow suggestions');
      return suggestions;
    } catch (e) {
      print('Error fetching follow suggestions: $e');
      rethrow;
    }
  }
}