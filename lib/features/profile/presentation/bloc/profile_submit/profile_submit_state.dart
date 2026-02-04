import 'package:kakan/features/profile/domain/entities/profiledetails_entity.dart';

abstract class ProfileSubmitState {}

class ProfileSubmitInitial extends ProfileSubmitState {}

class ProfileSubmitLoading extends ProfileSubmitState {}

class ProfileSubmitSuccess extends ProfileSubmitState {
  final ProfiledetailsEntity profileDetails;

  ProfileSubmitSuccess(this.profileDetails);
}

class ProfileSubmitError extends ProfileSubmitState {
  final String message;

  ProfileSubmitError(this.message);
}