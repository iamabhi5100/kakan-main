import 'package:kakan/features/profile/domain/entities/profiledetails_entity.dart';

abstract class ProfiledetailsState {}

class ProfiledetailsInitial extends ProfiledetailsState {}

class ProfiledetailsLoading extends ProfiledetailsState {}

class ProfiledetailsLoaded extends ProfiledetailsState {
  final ProfiledetailsEntity profileDetails;

  ProfiledetailsLoaded(this.profileDetails);
}

class ProfiledetailsError extends ProfiledetailsState {
  final String message;

  ProfiledetailsError(this.message);
}