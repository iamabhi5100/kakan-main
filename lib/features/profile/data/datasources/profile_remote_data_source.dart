// File: lib/features/profile/data/datasources/profile_remote_data_source.dart
import 'package:kakan/config/constant_api.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/network/api_service.dart';
import 'package:kakan/features/profile/data/models/profile_model.dart';

abstract class ProfileRemoteDataSource {
  Future<ProfileModel> updateProfile(String userId, Map<String, dynamic> data);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final ApiService apiService;

  ProfileRemoteDataSourceImpl({required this.apiService});

  @override
  Future<ProfileModel> updateProfile(String userId, Map<String, dynamic> data) async {
    try {
      final response = await apiService.patch(
        ConstantApi.userProfile + userId + '/',
        data,
      );
      return ProfileModel.fromJson(response);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}