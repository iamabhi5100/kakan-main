import 'package:kakan/config/constant_api.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/network/api_service.dart';
import '../models/search_result_model.dart';

abstract class SearchRemoteDataSource {
  Future<List<SearchResultModel>> searchPeople(String query);
  Future<List<SearchResultModel>> searchSongs(String query);
  Future<List<SearchResultModel>> searchVideos(String query);
}

class SearchRemoteDataSourceImpl implements SearchRemoteDataSource {
  final ApiService apiService;

  SearchRemoteDataSourceImpl(this.apiService);

  @override
  Future<List<SearchResultModel>> searchPeople(String query) async {
    try {
      final response = await apiService.get(
        ConstantApi.searchUsers.replaceFirst('%s', query),
        includeAuth: true,
      );
      final results = response['results'] as List<dynamic>;
      return results.map((json) => SearchResultModel.fromUserJson(json)).toList();
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<SearchResultModel>> searchSongs(String query) async {
    try {
      final response = await apiService.get(
        ConstantApi.searchPosts.replaceFirst('%s', query),
        includeAuth: true,
      );
      final results = response['results'] as List<dynamic>;
      return results
          .where((json) => json['media_type'] == 'audio')
          .map((json) => SearchResultModel.fromPostJson(json))
          .toList();
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<SearchResultModel>> searchVideos(String query) async {
    try {
      final response = await apiService.get(
        ConstantApi.searchPosts.replaceFirst('%s', query),
        includeAuth: true,
      );
      final results = response['results'] as List<dynamic>;
      return results
          .where((json) => json['media_type'] == 'video')
          .map((json) => SearchResultModel.fromPostJson(json))
          .toList();
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}