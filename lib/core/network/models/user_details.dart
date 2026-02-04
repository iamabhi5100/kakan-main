// lib/core/network/models/user_details.dart
class UserDetails {
  final String id;
  final String internalId;
  final bool isFollowed;
  final int followersCount;
  final int followingCount;
  final bool showUpdateProfileCard;
  final String created;
  final String modified;
  final String internalCode;
  final String prefix;
  final int sequenceNumber;
  final String userStatus;
  final String userType;
  final String username;
  final String phone;
  final String? email;
  final String? title;
  final String? name;
  final String? dateOfBirth;
  final String? gender;
  final String? profileImage;
  final String? occupation;
  final String user;

  UserDetails({
    required this.id,
    required this.internalId,
    required this.isFollowed,
    required this.followersCount,
    required this.followingCount,
    required this.showUpdateProfileCard,
    required this.created,
    required this.modified,
    required this.internalCode,
    required this.prefix,
    required this.sequenceNumber,
    required this.userStatus,
    required this.userType,
    required this.username,
    required this.phone,
    this.email,
    this.title,
    this.name,
    this.dateOfBirth,
    this.gender,
    this.profileImage,
    this.occupation,
    required this.user,
  });

  factory UserDetails.fromJson(Map<String, dynamic> json) {
    return UserDetails(
      id: json['id'] as String? ?? '',
      internalId: json['internal_id'] as String? ?? '',
      isFollowed: json['is_followed'] as bool? ?? false,
      followersCount: json['followers_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
      showUpdateProfileCard: json['show_update_profile_card'] as bool? ?? false,
      created: json['created'] as String? ?? '',
      modified: json['modified'] as String? ?? '',
      internalCode: json['internal_code'] as String? ?? '',
      prefix: json['prefix'] as String? ?? '',
      sequenceNumber: json['sequence_number'] as int? ?? 0,
      userStatus: json['user_status'] as String? ?? '',
      userType: json['user_type'] as String? ?? '',
      username: json['username'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      title: json['title'] as String?,
      name: json['name'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
      gender: json['gender'] as String?,
      profileImage: json['profile_image'] as String?,
      occupation: json['occupation'] as String?,
      user: json['user'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'internal_id': internalId,
      'is_followed': isFollowed,
      'followers_count': followersCount,
      'following_count': followingCount,
      'show_update_profile_card': showUpdateProfileCard,
      'created': created,
      'modified': modified,
      'internal_code': internalCode,
      'prefix': prefix,
      'sequence_number': sequenceNumber,
      'user_status': userStatus,
      'user_type': userType,
      'username': username,
      'phone': phone,
      'email': email,
      'title': title,
      'name': name,
      'date_of_birth': dateOfBirth,
      'gender': gender,
      'profile_image': profileImage,
      'occupation': occupation,
      'user': user,
    };
  }
}
