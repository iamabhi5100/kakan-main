import 'package:kakan/features/profile/domain/entities/profile_post_entity.dart';

class ProfilePostModel extends ProfilePostEntity {
  ProfilePostModel({
    required String id,
    required String caption,
    required String title,
    String? thumbnail,
    String? mediaFile,
    required String mediaType,
    required String created,
  }) : super(
          id: id,
          caption: caption,
          title: title,
          thumbnail: thumbnail,
          mediaFile: mediaFile,
          mediaType: mediaType,
          created: created,
        );

  factory ProfilePostModel.fromJson(Map<String, dynamic> json) {
    print('DEBUG: Parsing ProfilePostModel from JSON: $json');
    return ProfilePostModel(
      id: json['id']?.toString() ?? '',
      caption: json['caption']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      thumbnail: json['thumbnail']?.toString(),
      mediaFile: json['media_file']?.toString(),
      mediaType: json['media_type']?.toString() ?? '',
      created: json['created']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'caption': caption,
      'title': title,
      'thumbnail': thumbnail,
      'media_file': mediaFile,
      'media_type': mediaType,
      'created': created,
    };
  }
}