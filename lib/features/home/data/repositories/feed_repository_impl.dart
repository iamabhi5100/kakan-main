import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/network/network_info.dart';
import 'package:kakan/features/home/data/datasources/feed_remote_data_source.dart';
import 'package:kakan/features/home/data/models/feed_model.dart';
import 'package:kakan/features/home/data/models/comment_model.dart';
import 'package:kakan/features/home/model/entities/feed_entity.dart';
import 'package:kakan/features/home/model/repositories/feed_repository.dart';

class FeedRepositoryImpl implements FeedRepository {
  final FeedRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  FeedRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, Map<String, dynamic>>> getFeeds({String? nextUrl}) async {
    if (await networkInfo.isConnected) {
      try {
        final resp = await remoteDataSource.getFeeds(nextUrl: nextUrl);
        final list = (resp['results'] as List<FeedModel>)
            .map<FeedEntity>((m) => m)
            .toList();
        final hasMore = resp['next'] != null;
        final newNext = resp['next'] as String?;

        return Right({
          'feeds': list,
          'hasMore': hasMore,
          'nextUrl': newNext,
        });
      } on ServerException catch (e) {
        return Left(ServerFailure(exception: e));
      }
    } else {
      return Left(ServerFailure(exception: ServerException(message: 'No internet connection')));
    }
  }

  @override
  Future<Either<Failure, void>> likeDislikePost(String postId) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.likeDislikePost(postId);
        return const Right(null);
      } on ServerException catch (e) {
        return Left(ServerFailure(exception: e));
      }
    } else {
      return Left(ServerFailure(exception: ServerException(message: 'No internet connection')));
    }
  }

  @override
  Future<Either<Failure, String>> repost({
    required String postId,
    required String title,
    required String caption,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final newPostId = await remoteDataSource.repost(
          postId: postId,
          title: title,
          caption: caption,
        );
        return Right(newPostId);
      } on ServerException catch (e) {
        return Left(ServerFailure(exception: e));
      }
    } else {
      return Left(ServerFailure(exception: ServerException(message: 'No internet connection')));
    }
  }

  @override
  Future<Either<Failure, void>> deleteFeed(String feedId) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.deleteFeed(feedId);
        return const Right(null);
      } on ServerException catch (e) {
        return Left(ServerFailure(exception: e));
      }
    } else {
      return Left(ServerFailure(exception: ServerException(message: 'No internet connection')));
    }
  }

  @override
  Future<Either<Failure, void>> addComment(String postId, String content) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.addComment(postId, content);
        return const Right(null);
      } on ServerException catch (e) {
        return Left(ServerFailure(exception: e));
      }
    } else {
      return Left(ServerFailure(exception: ServerException(message: 'No internet connection')));
    }
  }

  @override
  Future<Either<Failure, List<CommentEntity>>> getComments(String postId) async {
    if (await networkInfo.isConnected) {
      try {
        final comments = await remoteDataSource.getComments(postId);
        return Right(comments);
      } on ServerException catch (e) {
        return Left(ServerFailure(exception: e));
      }
    } else {
      return Left(ServerFailure(exception: ServerException(message: 'No internet connection')));
    }
  }

  @override
  Future<Either<Failure, void>> deleteComment(String commentId) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.deleteComment(commentId);
        return const Right(null);
      } on ServerException catch (e) {
        return Left(ServerFailure(exception: e));
      }
    } else {
      return Left(ServerFailure(exception: ServerException(message: 'No internet connection')));
    }
  }
}
