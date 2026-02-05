import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/postmyfeed/domain/entities/post_entity.dart';
import 'package:kakan/features/postmyfeed/domain/repositories/post_repository.dart';

class CreatePost implements UseCase<PostEntity, CreatePostParams> {
  final PostRepository repository;

  CreatePost(this.repository);

  @override
  Future<Either<Failure, PostEntity>> call(CreatePostParams params) async {
    return await repository.createPost(
      mediaType: params.mediaType,
      title: params.title,
      caption: params.caption,
      mediaFilePath: params.mediaFilePath,
      mediaId: params.mediaId,
      thumbnailPath: params.thumbnailPath,
      shareTo: params.shareTo,
    );
  }
}

class CreatePostParams {
  final String mediaType;
  final String title;
  final String? caption;
  final String? mediaFilePath;
  final String? mediaId;
  final String? thumbnailPath;
  final String shareTo;

  CreatePostParams({
    required this.mediaType,
    required this.title,
    this.caption,
    this.mediaFilePath,
    this.mediaId,
    this.thumbnailPath,
    required this.shareTo,
  });
}