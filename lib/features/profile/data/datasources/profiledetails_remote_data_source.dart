import 'package:kakan/config/constant_api.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/network/api_service.dart';
import 'package:kakan/features/profile/data/models/profiledetails_model.dart';

abstract class ProfiledetailsRemoteDataSource {
  Future<ProfiledetailsModel> getProfiledetails(String userId);
}

class ProfiledetailsRemoteDataSourceImpl implements ProfiledetailsRemoteDataSource {
  final ApiService apiService;

  ProfiledetailsRemoteDataSourceImpl({required this.apiService});

  @override
  Future<ProfiledetailsModel> getProfiledetails(String userId) async {
    try {
      final response = await apiService.get(
        ConstantApi.userProfile.replaceFirst('{{user_id}}', userId),
        includeAuth: true,
      );
      return ProfiledetailsModel.fromJson(response);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}