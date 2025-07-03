// lib/features/home/data/datasources/feed_remote_data_source.dart
import 'package:kakan/config/constant_api.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/network/api_service.dart';
import 'package:kakan/features/home/data/models/feed_model.dart';

abstract class FeedRemoteDataSource {
  Future<List<FeedModel>> getFeeds();
}

class FeedRemoteDataSourceImpl implements FeedRemoteDataSource {
  final ApiService apiService;

  FeedRemoteDataSourceImpl({required this.apiService});

  @override
  Future<List<FeedModel>> getFeeds() async {
    try {
      final response = await apiService.get(
        '/v${ConstantApi.apiVersion}/feeds/',
        includeAuth: true,
      );
      if (response is Map<String, dynamic> && response.containsKey('results')) {
        final results = response['results'] as List<dynamic>;
        return results.map((json) => FeedModel.fromJson(json)).toList();
      } else {
        throw ServerException(message: 'Invalid response format');
      }
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}