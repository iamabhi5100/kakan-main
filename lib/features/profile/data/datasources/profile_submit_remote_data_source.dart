import 'package:kakan/config/constant_api.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/network/api_service.dart';
import 'package:kakan/features/profile/data/models/profiledetails_model.dart';

abstract class ProfileSubmitRemoteDataSource {
  Future<ProfiledetailsModel> submitProfile(String userId, Map<String, dynamic> data);
}

class ProfileSubmitRemoteDataSourceImpl implements ProfileSubmitRemoteDataSource {
  final ApiService apiService;

  ProfileSubmitRemoteDataSourceImpl({required this.apiService});

  @override
  Future<ProfiledetailsModel> submitProfile(String userId, Map<String, dynamic> data) async {
    try {
      final response = await apiService.patch(
        '/v${ConstantApi.apiVersion}/user/$userId/update-profile/',
        data,
        includeAuth: true,
      );
      return ProfiledetailsModel.fromJson(response);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}