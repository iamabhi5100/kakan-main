import 'package:kakan/features/myfiles/domain/entities/download_entity.dart';

class DownloadModel extends DownloadEntity {
  DownloadModel({
    required String id,
    required String created,
    required String mediaType,
    String? mediaFile,
    String? thumbnail,
    String? title,
    String? duration,
  }) : super(
          id: id,
          created: created,
          mediaType: mediaType,
          mediaFile: mediaFile,
          thumbnail: thumbnail,
          title: title,
          duration: duration,
        );

  factory DownloadModel.fromJson(Map<String, dynamic> json) {
    print('DEBUG: Parsing DownloadModel from JSON: $json');
    return DownloadModel(
      id: json['id']?.toString() ?? '', // Ensure id is not null
      created: json['created']?.toString() ?? '',
      mediaType: json['media_type']?.toString() ?? '',
      mediaFile: json['media_file']?.toString(),
      thumbnail: json['thumbnail']?.toString(),
      title: json['title']?.toString(),
      duration: json['duration']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created': created,
      'media_type': mediaType,
      'media_file': mediaFile,
      'thumbnail': thumbnail,
      'title': title,
      'duration': duration,
    };
  }
}