// lib/features/followsuggestions/data/models/suggestion_model.dart
import 'package:kakan/features/followsuggestions/domain/entities/suggestion_entity.dart';

class SuggestionModel extends SuggestionEntity {
  SuggestionModel({
    required String id,
    required bool isFollowed,
    required int followersCount,
    String? username,
    String? email,
    String? title,
    String? name,
    String? dateOfBirth,
    String? profileImage,
  }) : super(
          id: id,
          isFollowed: isFollowed,
          followersCount: followersCount,
          username: username,
          email: email,
          title: title,
          name: name,
          dateOfBirth: dateOfBirth,
          profileImage: profileImage,
        );

  factory SuggestionModel.fromJson(Map<String, dynamic> json) {
    return SuggestionModel(
      id: json['id'] as String,
      isFollowed: json['is_followed'] as bool,
      followersCount: json['followers_count'] as int,
      username: json['username'] as String?,
      email: json['email'] as String?,
      title: json['title'] as String?,
      name: json['name'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
      profileImage: json['profile_image'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'is_followed': isFollowed,
      'followers_count': followersCount,
      'username': username,
      'email': email,
      'title': title,
      'name': name,
      'date_of_birth': dateOfBirth,
      'profile_image': profileImage,
    };
  }
}