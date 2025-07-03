import 'package:kakan/config/constant_api.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/network/api_service.dart';

abstract class DeleteDownloadRemoteDataSource {
  Future<void> deleteDownload(String mediaId);
}

class DeleteDownloadRemoteDataSourceImpl implements DeleteDownloadRemoteDataSource {
  final ApiService apiService;

  DeleteDownloadRemoteDataSourceImpl({required this.apiService});

  @override
  Future<void> deleteDownload(String mediaId) async {
    try {
      await apiService.delete(
        ConstantApi.deleteDownload.replaceFirst('%s', mediaId),
        includeAuth: true,
      );
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}