import 'package:kakan/config/constant_api.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/network/api_service.dart';
import 'package:kakan/features/profile/data/models/profile_post_model.dart';

abstract class ProfilePostsRemoteDataSource {
  Future<List<ProfilePostModel>> getProfilePosts(String mediaType);
}

class ProfilePostsRemoteDataSourceImpl implements ProfilePostsRemoteDataSource {
  final ApiService apiService;

  ProfilePostsRemoteDataSourceImpl({required this.apiService});

  @override
  Future<List<ProfilePostModel>> getProfilePosts(String mediaType) async {
    try {
      final response = await apiService.get(
        '${ConstantApi.createPost}?media_type=$mediaType',
        includeAuth: true,
      );
      if (response is Map<String, dynamic> && response.containsKey('results')) {
        final results = response['results'] as List<dynamic>;
        return results.map((json) => ProfilePostModel.fromJson(json)).toList();
      } else {
        throw ServerException(message: 'Invalid response format');
      }
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}