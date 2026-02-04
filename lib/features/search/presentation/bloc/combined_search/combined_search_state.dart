import 'package:kakan/features/search/domain/entities/search_result.dart';

abstract class CombinedSearchState {}

class SearchInitial extends CombinedSearchState {}
class SearchLoading extends CombinedSearchState {}

class SearchLoaded extends CombinedSearchState {
  final List<SearchResult> people;
  final List<SearchResult> songs;
  final List<SearchResult> videos;

  SearchLoaded({
    required this.people,
    required this.songs,
    required this.videos,
  });
}

class SearchError extends CombinedSearchState {
  final String message;
  SearchError(this.message);
}
