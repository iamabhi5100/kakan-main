/// A single media item (e.g. one slide in a carousel search result).
class SearchMediaItem {
  final String type; // 'image' | 'video' | 'audio'
  final String mediaFile;
  final String? thumbnail;

  const SearchMediaItem({
    required this.type,
    required this.mediaFile,
    this.thumbnail,
  });
}
