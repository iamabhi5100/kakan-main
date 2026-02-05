/// Represents a single selected photo or video for carousel post.
class SelectedMediaItem {
  final String path;
  final String type; // 'image' | 'video'
  final String name;
  final String? mediaId;

  const SelectedMediaItem({
    required this.path,
    required this.type,
    required this.name,
    this.mediaId,
  });

  bool get isVideo => type == 'video';
  bool get isImage => type == 'image';

  SelectedMediaItem copyWith({
    String? path,
    String? type,
    String? name,
    String? mediaId,
  }) {
    return SelectedMediaItem(
      path: path ?? this.path,
      type: type ?? this.type,
      name: name ?? this.name,
      mediaId: mediaId ?? this.mediaId,
    );
  }
}
