class FollowingUserEntity {
  final String id;
  final FollowedToDetailsEntity followedToDetails;
  final String created;

  FollowingUserEntity({
    required this.id,
    required this.followedToDetails,
    required this.created,
  });
}

class FollowedToDetailsEntity {
  final String id;
  final String name;
  final String? profileImage;

  FollowedToDetailsEntity({
    required this.id,
    required this.name,
    this.profileImage,
  });
}