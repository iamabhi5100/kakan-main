import 'package:kakan/config/constant_api.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/network/api_service.dart';
import 'package:kakan/features/profile/data/models/profile_post_model.dart';

abstract class ProfilePostsRemoteDataSource {
  // <-- MODIFIED: Update the method to accept both userId and mediaType
  Future<List<ProfilePostModel>> getProfilePosts(String userId, String mediaType);
}

class ProfilePostsRemoteDataSourceImpl implements ProfilePostsRemoteDataSource {
  final ApiService apiService;

  ProfilePostsRemoteDataSourceImpl({required this.apiService});

  @override
  // <-- MODIFIED: Update the method signature to match the abstract class
  Future<List<ProfilePostModel>> getProfilePosts(String userId, String mediaType) async {
    try {
      // <-- UPDATED: Use the new endpoint structure (fetch all posts, no media_type param)
      final endpoint = '/v${ConstantApi.apiVersion}/posts/user-posts/?user_profile=$userId';
      
      final response = await apiService.get(
        endpoint,
        includeAuth: true,
      );
      
      if (response is Map<String, dynamic> && response.containsKey('results')) {
        final results = response['results'] as List<dynamic>;
        final allPosts = results
            .where((e) => e != null && e is Map<String, dynamic>)
            .cast<Map<String, dynamic>>()
            .map((json) => ProfilePostModel.fromJson(json))
            .toList();

        // Video tab: show all except post_type "audio". Song tab: show only post_type "audio".
        if (mediaType == 'audio') {
          return allPosts.where((post) => post.postType == 'audio').toList();
        }
        return allPosts.where((post) => post.postType != 'audio').toList();
      } else {
        throw ServerException(message: 'Invalid response format');
      }
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}