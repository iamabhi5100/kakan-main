import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/postmyfeed/domain/entities/carousel_media_item_entity.dart';
import 'package:kakan/features/postmyfeed/domain/entities/post_entity.dart';
import 'package:kakan/features/postmyfeed/domain/repositories/post_repository.dart';

class CreatePostCarousel implements UseCase<PostEntity, CreatePostCarouselParams> {
  final PostRepository repository;

  CreatePostCarousel(this.repository);

  @override
  Future<Either<Failure, PostEntity>> call(CreatePostCarouselParams params) async {
    return await repository.createPostCarousel(
      title: params.title,
      caption: params.caption,
      shareTo: params.shareTo,
      items: params.items,
    );
  }
}

class CreatePostCarouselParams {
  final String title;
  final String? caption;
  final String shareTo;
  final List<CarouselMediaItemEntity> items;

  CreatePostCarouselParams({
    required this.title,
    this.caption,
    required this.shareTo,
    required this.items,
  });
}
