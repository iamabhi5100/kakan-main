class FollowingUserModel {
  final String id;
  final FollowedToDetailsModel followedToDetails;
  final String created;

  FollowingUserModel({
    required this.id,
    required this.followedToDetails,
    required this.created,
  });

  factory FollowingUserModel.fromJson(Map<String, dynamic> json) {
    return FollowingUserModel(
      id: json['id'],
      followedToDetails: FollowedToDetailsModel.fromJson(json['followed_to_details']),
      created: json['created'],
    );
  }
}

class FollowedToDetailsModel {
  final String id;
  final String name;
  final String? profileImage;

  FollowedToDetailsModel({
    required this.id,
    required this.name,
    this.profileImage,
  });

  factory FollowedToDetailsModel.fromJson(Map<String, dynamic> json) {
    return FollowedToDetailsModel(
      id: json['id'],
      name: json['name'],
      profileImage: json['profile_image'],
    );
  }
}

class FollowingUsersResponse {
  final int count;
  final String? next;
  final String? previous;
  final List<FollowingUserModel> results;

  FollowingUsersResponse({
    required this.count,
    required this.next,
    required this.previous,
    required this.results,
  });

  factory FollowingUsersResponse.fromJson(Map<String, dynamic> json) {
    var results = json['results'] as List;
    List<FollowingUserModel> followingUsers =
        results.map((i) => FollowingUserModel.fromJson(i)).toList();

    return FollowingUsersResponse(
      count: json['count'],
      next: json['next'],
      previous: json['previous'],
      results: followingUsers,
    );
  }
}