// lib/features/followsuggestions/presentation/bloc/suggestion_state.dart
import 'package:equatable/equatable.dart';
import 'package:kakan/features/followsuggestions/data/models/suggestion_model.dart';

abstract class SuggestionState extends Equatable {
  const SuggestionState();
  @override
  List<Object> get props => [];
}

class SuggestionInitial extends SuggestionState {}

class SuggestionLoading extends SuggestionState {}

class SuggestionLoaded extends SuggestionState {
  final List<SuggestionModel> suggestions;

  const SuggestionLoaded({required this.suggestions});

  @override
  List<Object> get props => [suggestions];
}

class SuggestionFailure extends SuggestionState {
  final String message;

  const SuggestionFailure({required this.message});

  @override
  List<Object> get props => [message];
}

class SuggestionFollowLoading extends SuggestionState {
  final String userId;

  const SuggestionFollowLoading({required this.userId});

  @override
  List<Object> get props => [userId];
}

class SuggestionFollowSuccess extends SuggestionState {
  final List<SuggestionModel> suggestions;
  final String message;

  const SuggestionFollowSuccess({required this.suggestions, required this.message});

  @override
  List<Object> get props => [suggestions, message];
}

class SuggestionFollowFailure extends SuggestionState {
  final String message;
  final List<SuggestionModel> suggestions;

  const SuggestionFollowFailure({required this.message, required this.suggestions});

  @override
  List<Object> get props => [message, suggestions];
}