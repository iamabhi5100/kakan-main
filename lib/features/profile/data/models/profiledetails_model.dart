import 'package:kakan/features/profile/domain/entities/profiledetails_entity.dart';

class ProfiledetailsModel extends ProfiledetailsEntity {
  ProfiledetailsModel({
    required String id,
    required String username,
    required String phone,
    String? email,
    String? title,
    String? name,
    String? dateOfBirth,
    String? gender,
    String? profileImage,
    String? occupation,
    required int followersCount, // Add followersCount
    required int followingCount, // Add followingCount
  }) : super(
          id: id,
          username: username,
          phone: phone,
          email: email,
          title: title,
          name: name,
          dateOfBirth: dateOfBirth,
          gender: gender,
          profileImage: profileImage,
          occupation: occupation,
          followersCount: followersCount,
          followingCount: followingCount,
        );

  factory ProfiledetailsModel.fromJson(Map<String, dynamic> json) {
    print('ProfiledetailsModel: Parsing JSON: $json');
    return ProfiledetailsModel(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      title: json['title'],
      name: json['name'],
      dateOfBirth: json['date_of_birth'],
      gender: json['gender'],
      profileImage: json['profile_image'],
      occupation: json['occupation'],
      followersCount: json['followers_count'] ?? 0, // Map followers_count
      followingCount: json['following_count'] ?? 0, // Map following_count
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'phone': phone,
      'email': email,
      'title': title,
      'name': name,
      'date_of_birth': dateOfBirth,
      'gender': gender,
      'profile_image': profileImage,
      'occupation': occupation,
      'followers_count': followersCount, // Include in JSON
      'following_count': followingCount, // Include in JSON
    };
  }
}