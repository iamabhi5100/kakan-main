import 'package:kakan/features/profile/domain/entities/profileimage_entity.dart';

class ProfileimageModel extends ProfileimageEntity {
  ProfileimageModel({required String message}) : super(message: message);

  factory ProfileimageModel.fromJson(Map<String, dynamic> json) {
    return ProfileimageModel(
      message: json['message'] ?? 'Profile Picture uploaded successfully.',
    );
  }

  Map<String, dynamic> toJson() {
    return {'message': message};
  }
}