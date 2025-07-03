import 'package:kakan/features/postmyfeed/domain/entities/post_entity.dart';

class PostModel extends PostEntity {
  PostModel({
    required String id,
    required String title,
    String? caption,
    String? mediaFile,
    String? thumbnail,
  }) : super(
          id: id,
          title: title,
          caption: caption,
          mediaFile: mediaFile,
          thumbnail: thumbnail,
        );

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      caption: json['caption'],
      mediaFile: json['media_file'],
      thumbnail: json['thumbnail'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'caption': caption,
      'media_file': mediaFile,
      'thumbnail': thumbnail,
    };
  }
}