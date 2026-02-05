import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/network/network_info.dart';
import 'package:kakan/features/postmyfeed/data/datasources/post_remote_data_source.dart';
import 'package:kakan/features/postmyfeed/data/models/selected_media_item.dart';
import 'package:kakan/features/postmyfeed/domain/entities/carousel_media_item_entity.dart';
import 'package:kakan/features/postmyfeed/domain/entities/post_entity.dart';
import 'package:kakan/features/postmyfeed/domain/repositories/post_repository.dart';

class PostRepositoryImpl implements PostRepository {
  final PostRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  PostRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, PostEntity>> createPost({
    required String mediaType,
    required String title,
    String? caption,
    String? mediaFilePath,
    String? mediaId,
    String? thumbnailPath,
    required String shareTo,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final post = await remoteDataSource.createPost(
          mediaType: mediaType,
          title: title,
          caption: caption,
          mediaFilePath: mediaFilePath,
          mediaId: mediaId,
          thumbnailPath: thumbnailPath,
          shareTo: shareTo,
        );
        return Right(post);
      } on ServerException catch (e) {
        return Left(ServerFailure(exception: e));
      }
    } else {
      return Left(ServerFailure(exception: ServerException(message: 'No internet connection')));
    }
  }

  @override
  Future<Either<Failure, PostEntity>> createPostCarousel({
    required String title,
    String? caption,
    required String shareTo,
    required List<CarouselMediaItemEntity> items,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final list = items
            .map((e) => SelectedMediaItem(
                  path: e.path,
                  type: e.type,
                  name: e.name,
                  mediaId: e.mediaId,
                ))
            .toList();
        final post = await remoteDataSource.createPostCarousel(
          title: title,
          caption: caption,
          shareTo: shareTo,
          items: list,
        );
        return Right(post);
      } on ServerException catch (e) {
        return Left(ServerFailure(exception: e));
      }
    } else {
      return Left(ServerFailure(exception: ServerException(message: 'No internet connection')));
    }
  }
}