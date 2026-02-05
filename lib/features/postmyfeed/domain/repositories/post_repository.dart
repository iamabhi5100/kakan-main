import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/postmyfeed/domain/entities/carousel_media_item_entity.dart';
import 'package:kakan/features/postmyfeed/domain/entities/post_entity.dart';

abstract class PostRepository {
  Future<Either<Failure, PostEntity>> createPost({
    required String mediaType,
    required String title,
    String? caption,
    String? mediaFilePath,
    String? mediaId,
    String? thumbnailPath,
    required String shareTo,
  });
  Future<Either<Failure, PostEntity>> createPostCarousel({
    required String title,
    String? caption,
    required String shareTo,
    required List<CarouselMediaItemEntity> items,
  });
}