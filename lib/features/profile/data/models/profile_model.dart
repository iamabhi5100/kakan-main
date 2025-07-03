// File: lib/features/profile/data/models/profile_model.dart
import 'package:kakan/features/profile/domain/entities/profile.dart';

class ProfileModel extends Profile {
  ProfileModel({
    required String id,
    required String username,
    required String name,
    required String email,
    required String? dateOfBirth,
    required String title,
    required String gender,
    required String occupation,
  }) : super(
          id: id,
          username: username,
          name: name,
          email: email,
          dateOfBirth: dateOfBirth,
          title: title,
          gender: gender,
          occupation: occupation,
        );

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'],
      username: json['username'],
      name: json['name'],
      email: json['email'],
      dateOfBirth: json['date_of_birth'],
      title: json['title'],
      gender: json['gender'],
      occupation: json['occupation'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'name': name,
      'email': email,
      'date_of_birth': dateOfBirth,
      'title': title,
      'gender': gender,
      'occupation': occupation,
    };
  }
}