
// import 'package:kakan/features/profile/domain/entities/profile_post_entity.dart';

import 'package:kakan/features/profile/domain/entities/profile_post_entity.dart';

abstract class ProfilePostsState {}

class ProfilePostsInitial extends ProfilePostsState {}

class ProfilePostsLoading extends ProfilePostsState {}

class ProfilePostsLoaded extends ProfilePostsState {
  final List<ProfilePostEntity> posts;

  ProfilePostsLoaded(this.posts);
}

class ProfilePostsError extends ProfilePostsState {
  final String message;

  ProfilePostsError(this.message);
}