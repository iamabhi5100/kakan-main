import 'package:kakan/features/home/model/entities/feed_entity.dart';

class CommentModel extends CommentEntity {
  CommentModel({
    required String id,
    required String created,
    required String content,
    required String userProfileId,
    required String postId,
    required UserProfileDetails userProfileDetails,
  }) : super(
         id: id,
         created: created,
         content: content,
         userProfileId: userProfileId,
         postId: postId,
         userProfileDetails: userProfileDetails,
       );

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id']?.toString() ?? '',
      created: json['created']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      userProfileId: json['user_profile']?.toString() ?? '',
      postId: json['post']?.toString() ?? '',
      userProfileDetails: UserProfileDetails.fromJson(
        json['user_profile_details'] ??
            {
              'id': json['user_profile']?.toString() ?? '',
              'username': 'Unknown',
              'name': 'Unknown User',
              'profile_image': null,
            },
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created': created,
      'content': content,
      'user_profile': userProfileId,
      'post': postId,
      'user_profile_details': userProfileDetails.toJson(),
    };
  }
}
