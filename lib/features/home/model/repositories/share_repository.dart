import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/home/data/datasources/share_remote_data_source.dart';
import 'package:kakan/features/home/data/models/share_models.dart';


abstract class ShareRepository {
  Future<Either<Failure, List<ShareItem>>> getUsersToShare();
  Future<Either<Failure, void>> sendMessage({
    required String chatId,
    required String type,
    required String content,
    required String messageType,
    String? mediaFileUrl,
  });
}

class ShareRepositoryImpl implements ShareRepository {
  final ShareRemoteDataSource remoteDataSource;

  ShareRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<ShareItem>>> getUsersToShare() async {
    try {
      final shareItems = await remoteDataSource.getUsersToShare();
      return Right(shareItems);
    } on ServerException catch (e) {
      return Left(ServerFailure(exception: e));
    }
  }

  @override
  Future<Either<Failure, void>> sendMessage({
    required String chatId,
    required String type,
    required String content,
    required String messageType,
    String? mediaFileUrl,
  }) async {
    try {
      await remoteDataSource.sendMessage(
        chatId: chatId,
        type: type,
        content: content,
        messageType: messageType,
        mediaFileUrl: mediaFileUrl,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(exception: e));
    }
  }
}