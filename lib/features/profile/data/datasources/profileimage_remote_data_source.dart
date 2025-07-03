import 'package:dio/dio.dart';
import 'package:kakan/config/constant_api.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/network/api_service.dart';
import 'package:kakan/features/profile/data/models/profileimage_model.dart';

abstract class ProfileimageRemoteDataSource {
  Future<ProfileimageModel> uploadProfileimage(String userId, String imagePath);
}

class ProfileimageRemoteDataSourceImpl implements ProfileimageRemoteDataSource {
  final ApiService apiService;

  ProfileimageRemoteDataSourceImpl({required this.apiService});

  @override
  Future<ProfileimageModel> uploadProfileimage(String userId, String imagePath) async {
    try {
      final response = await apiService.uploadFile(
        '/v${ConstantApi.apiVersion}/user/$userId/upload-profile-picture/',
        filePath: imagePath,
        fileKey: 'profile_image',
        includeAuth: true,
      );
      return ProfileimageModel.fromJson(response);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}