abstract class CombinedSearchEvent {}

/// Fires on every query change (you can debounce if you like).
class SearchAllEvent extends CombinedSearchEvent {
  final String query;
  SearchAllEvent(this.query);
}
