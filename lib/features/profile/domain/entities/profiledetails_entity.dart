class ProfiledetailsEntity {
  final String id;
  final String username;
  final String phone;
  final String? email;
  final String? title;
  final String? name;
  final String? dateOfBirth;
  final String? gender;
  final String? profileImage;
  final String? occupation;
  final int followersCount; // Add followersCount
  final int followingCount; // Add followingCount

  ProfiledetailsEntity({
    required this.id,
    required this.username,
    required this.phone,
    this.email,
    this.title,
    this.name,
    this.dateOfBirth,
    this.gender,
    this.profileImage,
    this.occupation,
    required this.followersCount, // Mark as required
    required this.followingCount, // Mark as required
  });
}