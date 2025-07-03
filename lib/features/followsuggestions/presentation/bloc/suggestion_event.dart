// lib/features/followsuggestions/presentation/bloc/suggestion_event.dart
import 'package:equatable/equatable.dart';

abstract class SuggestionEvent extends Equatable {
  const SuggestionEvent();
  @override
  List<Object> get props => [];
}

class FetchSuggestionsEvent extends SuggestionEvent {}

class FollowUserEvent extends SuggestionEvent {
  final String userId;

  const FollowUserEvent({required this.userId});

  @override
  List<Object> get props => [userId];
}

class UnfollowUserEvent extends SuggestionEvent {
  final String userId;

  const UnfollowUserEvent({required this.userId});

  @override
  List<Object> get props => [userId];
}