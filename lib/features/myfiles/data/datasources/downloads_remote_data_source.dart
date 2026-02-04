import 'package:kakan/config/constant_api.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/network/api_service.dart';
import 'package:kakan/features/myfiles/data/models/download_model.dart';

abstract class DownloadsRemoteDataSource {
  Future<List<DownloadModel>> getDownloads(String mediaType, {String? search});
}

class DownloadsRemoteDataSourceImpl implements DownloadsRemoteDataSource {
  final ApiService apiService;

  DownloadsRemoteDataSourceImpl({required this.apiService});

  @override
  Future<List<DownloadModel>> getDownloads(String mediaType, {String? search}) async {
    try {
      final uri = Uri.parse(ConstantApi.downloads).replace(queryParameters: {
        'media_type': mediaType,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      });

      final response = await apiService.get(
        uri.toString(),
        includeAuth: true,
      );

      if (response is Map<String, dynamic> && response.containsKey('results')) {
        final results = response['results'] as List<dynamic>;
        return results.map((json) => DownloadModel.fromJson(json)).toList();
      } else {
        throw ServerException(message: 'Invalid response format');
      }
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
