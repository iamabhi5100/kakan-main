// File: lib/features/profile/domain/entities/profile.dart
class Profile {
  final String id;
  final String username;
  final String name;
  final String email;
  final String? dateOfBirth;
  final String title;
  final String gender;
  final String occupation;

  Profile({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
    this.dateOfBirth,
    required this.title,
    required this.gender,
    required this.occupation,
  });
}