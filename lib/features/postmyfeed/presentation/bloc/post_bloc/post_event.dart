import 'package:kakan/features/postmyfeed/domain/entities/carousel_media_item_entity.dart';

abstract class PostEvent {}

class CreatePostEvent extends PostEvent {
  final String mediaType;
  final String title;
  final String? caption;
  final String? mediaFilePath;
  final String? mediaId;
  final String? thumbnailPath;
  final String shareTo;

  CreatePostEvent({
    required this.mediaType,
    required this.title,
    this.caption,
    this.mediaFilePath,
    this.mediaId,
    this.thumbnailPath,
    required this.shareTo,
  });
}

class CreatePostCarouselEvent extends PostEvent {
  final String title;
  final String? caption;
  final String shareTo;
  final List<CarouselMediaItemEntity> items;

  CreatePostCarouselEvent({
    required this.title,
    this.caption,
    required this.shareTo,
    required this.items,
  });
}