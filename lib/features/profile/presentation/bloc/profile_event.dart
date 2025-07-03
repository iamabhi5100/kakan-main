// File: lib/features/profile/presentation/bloc/profile_event.dart
part of 'profile_bloc.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object> get props => [];
}

class UpdateProfileEvent extends ProfileEvent {
  final String userId;
  final Map<String, dynamic> data;

  const UpdateProfileEvent({required this.userId, required this.data});

  @override
  List<Object> get props => [userId, data];
}