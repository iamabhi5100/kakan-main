import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/search/domain/entities/search_result.dart';
import 'package:kakan/features/search/domain/usecases/search_people.dart';
import 'package:kakan/features/search/domain/usecases/search_songs.dart';
import 'package:kakan/features/search/domain/usecases/search_videos.dart';
import 'combined_search_event.dart';
import 'combined_search_state.dart';

class CombinedSearchBloc
    extends Bloc<CombinedSearchEvent, CombinedSearchState> {
  final SearchPeople _people;
  final SearchSongs  _songs;
  final SearchVideos _videos;

  CombinedSearchBloc({
    required SearchPeople people,
    required SearchSongs songs,
    required SearchVideos videos,
  })  : _people = people,
        _songs  = songs,
        _videos = videos,
        super(SearchInitial()) {
    on<SearchAllEvent>(_onSearchAll);
  }

  Future<void> _onSearchAll(
      SearchAllEvent event, Emitter<CombinedSearchState> emit) async {
    final q = event.query.trim();
    if (q.isEmpty) {
      emit(SearchInitial());
      return;
    }
    emit(SearchLoading());

    final eitherPeople = await _people(q);
    final eitherSongs  = await _songs(q);
    final eitherVideos = await _videos(q);

    // bail on first error
    if (eitherPeople.isLeft()) {
      final f = eitherPeople.swap().getOrElse(() => ServerFailure());
      emit(SearchError(_mapFailureToMessage(f)));
      return;
    }
    if (eitherSongs.isLeft()) {
      final f = eitherSongs.swap().getOrElse(() => ServerFailure());
      emit(SearchError(_mapFailureToMessage(f)));
      return;
    }
    if (eitherVideos.isLeft()) {
      final f = eitherVideos.swap().getOrElse(() => ServerFailure());
      emit(SearchError(_mapFailureToMessage(f)));
      return;
    }

    // all success → extract
    final people = eitherPeople.getOrElse(() => <SearchResult>[]);
    final songs  = eitherSongs .getOrElse(() => <SearchResult>[]);
    final videos = eitherVideos.getOrElse(() => <SearchResult>[]);

    emit(SearchLoaded(
      people: people,
      songs:  songs,
      videos: videos,
    ));
  }

  String _mapFailureToMessage(Failure failure) {
    if (failure is ServerFailure) {
      return 'Server error: ${failure.exception?.message ?? 'Unknown'}';
    }
    return 'Unexpected error';
  }
}
