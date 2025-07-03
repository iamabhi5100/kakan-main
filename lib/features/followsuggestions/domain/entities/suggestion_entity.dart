// lib/features/followsuggestions/domain/entities/suggestion_entity.dart
class SuggestionEntity {
  final String id;
  final bool isFollowed;
  final int followersCount;
  final String? username;
  final String? email;
  final String? title;
  final String? name;
  final String? dateOfBirth;
  final String? profileImage;

  SuggestionEntity({
    required this.id,
    required this.isFollowed,
    required this.followersCount,
    this.username,
    this.email,
    this.title,
    this.name,
    this.dateOfBirth,
    this.profileImage,
  });
}