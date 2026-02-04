import 'package:kakan/config/constant_api.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/network/api_service.dart';

abstract class DeletePostRemoteDataSource {
  Future<void> deletePost(String postId);
}

class DeletePostRemoteDataSourceImpl implements DeletePostRemoteDataSource {
  final ApiService apiService;

  DeletePostRemoteDataSourceImpl({required this.apiService});

  @override
  Future<void> deletePost(String postId) async {
    try {
      await apiService.delete(
        '${ConstantApi.createPost}$postId/',
        includeAuth: true,
      );
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}