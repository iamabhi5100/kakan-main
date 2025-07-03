import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:kakan/config/constant_api.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/network/api_service.dart';
import 'package:kakan/features/postmyfeed/data/models/post_model.dart';
import 'package:path_provider/path_provider.dart';

abstract class PostRemoteDataSource {
  Future<PostModel> createPost({
    required String mediaType,
    required String title,
    String? caption,
    String? mediaFilePath,
    String? mediaId,
    String? thumbnailPath,
    required String shareTo,
  });
  Future<String> downloadFile(String url);
}

class PostRemoteDataSourceImpl implements PostRemoteDataSource {
  final ApiService apiService;

  PostRemoteDataSourceImpl({required this.apiService});

  Future<String> _downloadFile(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final fileName = url.split('/').last;
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        print('DEBUG: Downloaded file to ${file.path}');
        return file.path;
      } else {
        throw ServerException(message: 'Failed to download media file: ${response.statusCode}');
      }
    } catch (e) {
      throw ServerException(message: 'Error downloading media file: $e');
    }
  }

  @override
  Future<String> downloadFile(String url) async {
    return await _downloadFile(url);
  }

  @override
  Future<PostModel> createPost({
    required String mediaType,
    required String title,
    String? caption,
    String? mediaFilePath,
    String? mediaId,
    String? thumbnailPath,
    required String shareTo,
  }) async {
    try {
      String? localMediaPath = mediaFilePath;
      if (mediaId == null && mediaFilePath != null && mediaFilePath.startsWith('http')) {
        print('DEBUG: mediaId is null, downloading video from $mediaFilePath');
        localMediaPath = await _downloadFile(mediaFilePath);
      }

      final formData = FormData.fromMap({
        'media_type': mediaType,
        'title': title,
        if (caption != null) 'caption': caption,
        if (mediaId != null) 'media_id': mediaId,
        if (localMediaPath != null && (mediaId == null || !localMediaPath.startsWith('http')))
          'media_file': await MultipartFile.fromFile(localMediaPath),
        if (thumbnailPath != null)
          'thumbnail': await MultipartFile.fromFile(thumbnailPath),
        'share_to': shareTo,
      });

      print('DEBUG: FormData fields: ${formData.fields}');
      print('DEBUG: FormData files: ${formData.files.map((file) => file.key).toList()}');

      final response = await apiService.post(
        ConstantApi.createPost,
        formData,
        includeAuth: true,
      );

      if (response is Map<String, dynamic>) {
        return PostModel.fromJson(response);
      } else {
        throw ServerException(message: 'Invalid response format');
      }
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}