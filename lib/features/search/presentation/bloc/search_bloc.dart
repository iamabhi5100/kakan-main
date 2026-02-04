import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/search/domain/entities/search_result.dart';
import 'package:kakan/features/search/domain/usecases/search_people.dart';
import 'package:kakan/features/search/domain/usecases/search_songs.dart';
import 'package:kakan/features/search/domain/usecases/search_videos.dart' as search;

abstract class SearchEvent {}

class SearchPeopleEvent extends SearchEvent {
  final String query;
  SearchPeopleEvent(this.query);
}

class SearchSongsEvent extends SearchEvent {
  final String query;
  SearchSongsEvent(this.query);
}

class SearchVideosEvent extends SearchEvent {
  final String query;
  SearchVideosEvent(this.query);
}

abstract class SearchState {}

class SearchInitial extends SearchState {}

class SearchLoading extends SearchState {}

class SearchLoaded extends SearchState {
  final List<SearchResult> results;
  final String type; // 'people', 'songs', 'videos'
  SearchLoaded(this.results, this.type);
}

class SearchError extends SearchState {
  final String message;
  SearchError(this.message);
}

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final SearchPeople searchPeople;
  final SearchSongs searchSongs;
  final search.SearchVideos searchVideos;

  SearchBloc({
    required this.searchPeople,
    required this.searchSongs,
    required this.searchVideos,
  }) : super(SearchInitial()) {
    on<SearchPeopleEvent>((event, emit) async {
      emit(SearchLoading());
      final result = await searchPeople(event.query);
      emit(result.fold(
        (failure) => SearchError(_mapFailureToMessage(failure)),
        (results) => SearchLoaded(results, 'people'),
      ));
    });

    on<SearchSongsEvent>((event, emit) async {
      emit(SearchLoading());
      final result = await searchSongs(event.query);
      emit(result.fold(
        (failure) => SearchError(_mapFailureToMessage(failure)),
        (results) => SearchLoaded(results, 'songs'),
      ));
    });

    on<SearchVideosEvent>((event, emit) async {
      emit(SearchLoading());
      final result = await searchVideos(event.query);
      emit(result.fold(
        (failure) => SearchError(_mapFailureToMessage(failure)),
        (results) => SearchLoaded(results, 'videos'),
      ));
    });
  }

  String _mapFailureToMessage(Failure failure) {
    if (failure is ServerFailure) {
      return 'Server error: ${failure.exception?.message ?? 'Unknown error'}';
    }
    return 'Unexpected error';
  }
}