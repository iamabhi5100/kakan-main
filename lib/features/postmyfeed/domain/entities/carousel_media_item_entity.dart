class CarouselMediaItemEntity {
  final String path;
  final String type; // 'image' | 'video'
  final String name;
  final String? mediaId;

  const CarouselMediaItemEntity({
    required this.path,
    required this.type,
    required this.name,
    this.mediaId,
  });
}
