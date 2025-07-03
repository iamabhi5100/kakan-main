// lib/features/followsuggestions/presentation/bloc/suggestion_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/followsuggestions/data/models/suggestion_model.dart';
import 'package:kakan/features/followsuggestions/domain/usecases/follow_user.dart';
import 'package:kakan/features/followsuggestions/domain/usecases/get_follow_suggestions.dart';
import 'package:kakan/features/followsuggestions/domain/usecases/unfollow_user.dart';
import 'package:kakan/features/followsuggestions/presentation/bloc/suggestion_event.dart';
import 'package:kakan/features/followsuggestions/presentation/bloc/suggestion_state.dart';

class SuggestionBloc extends Bloc<SuggestionEvent, SuggestionState> {
  final GetFollowSuggestions getFollowSuggestions;
  final FollowUser followUser;
  final UnfollowUser unfollowUser;
  List<SuggestionModel> _suggestions = [];

  SuggestionBloc({
    required this.getFollowSuggestions,
    required this.followUser,
    required this.unfollowUser,
  }) : super(SuggestionInitial()) {
    on<FetchSuggestionsEvent>(_onFetchSuggestions);
    on<FollowUserEvent>(_onFollowUser);
    on<UnfollowUserEvent>(_onUnfollowUser);
  }

  Future<void> _onFetchSuggestions(FetchSuggestionsEvent event, Emitter<SuggestionState> emit) async {
    emit(SuggestionLoading());
    final result = await getFollowSuggestions();
    emit(result.fold(
      (failure) => SuggestionFailure(message: _mapFailureToMessage(failure)),
      (suggestions) {
        _suggestions = suggestions;
        return SuggestionLoaded(suggestions: suggestions);
      },
    ));
  }

  Future<void> _onFollowUser(FollowUserEvent event, Emitter<SuggestionState> emit) async {
    emit(SuggestionFollowLoading(userId: event.userId));
    final result = await followUser(event.userId);
    emit(result.fold(
      (failure) => SuggestionFollowFailure(
        message: _mapFailureToMessage(failure),
        suggestions: _suggestions,
      ),
      (message) {
        final updatedSuggestions = _suggestions.map((user) {
          if (user.id == event.userId) {
            return SuggestionModel(
              id: user.id,
              isFollowed: true,
              followersCount: user.followersCount + 1,
              username: user.username,
              email: user.email,
              title: user.title,
              name: user.name,
              dateOfBirth: user.dateOfBirth,
              profileImage: user.profileImage,
            );
          }
          return user;
        }).toList();
        _suggestions = updatedSuggestions;
        return SuggestionFollowSuccess(suggestions: updatedSuggestions, message: message);
      },
    ));
  }

  Future<void> _onUnfollowUser(UnfollowUserEvent event, Emitter<SuggestionState> emit) async {
    emit(SuggestionFollowLoading(userId: event.userId));
    final result = await unfollowUser(event.userId);
    emit(result.fold(
      (failure) => SuggestionFollowFailure(
        message: _mapFailureToMessage(failure),
        suggestions: _suggestions,
      ),
      (message) {
        final updatedSuggestions = _suggestions.map((user) {
          if (user.id == event.userId) {
            return SuggestionModel(
              id: user.id,
              isFollowed: false,
              followersCount: user.followersCount > 0 ? user.followersCount - 1 : 0,
              username: user.username,
              email: user.email,
              title: user.title,
              name: user.name,
              dateOfBirth: user.dateOfBirth,
              profileImage: user.profileImage,
            );
          }
          return user;
        }).toList();
        _suggestions = updatedSuggestions;
        return SuggestionFollowSuccess(suggestions: updatedSuggestions, message: message);
      },
    ));
  }

  String _mapFailureToMessage(Failure failure) {
    if (failure is ServerFailure) {
      return failure.exception?.message ?? 'Server error occurred';
    }
    return 'Unexpected error occurred';
  }
}