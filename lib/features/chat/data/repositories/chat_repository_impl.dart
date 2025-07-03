import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/network/network_info.dart';
import 'package:kakan/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:kakan/features/chat/data/models/chat_models.dart';
import 'package:kakan/features/chat/data/models/following_user_model.dart';
import 'package:kakan/features/chat/domain/repositories/chat_repository.dart';
import 'package:kakan/features/postmyfeed/data/datasources/post_remote_data_source.dart';
import 'package:kakan/injection_container.dart' as di;
import 'dart:developer' as developer;

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;
  final PostRemoteDataSource postRemoteDataSource;

  ChatRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  }) : postRemoteDataSource = di.sl<PostRemoteDataSource>();

  @override
  Future<Either<Failure, FollowingUsersResponse>> getFollowingUsers(String userId) async {
    if (await networkInfo.isConnected) {
      try {
        final response = await remoteDataSource.getFollowingUsers(userId);
        return Right(response);
      } on ServerException catch (e) {
        return Left(ServerFailure(exception: e));
      }
    } else {
      return Left(ServerFailure(exception: ServerException(message: 'No internet connection')));
    }
  }

  @override
  Future<Either<Failure, CreateChatResponse>> createChat(String userId) async {
    if (await networkInfo.isConnected) {
      try {
        final response = await remoteDataSource.createChat(userId);
        return Right(response);
      } on ServerException catch (e) {
        return Left(ServerFailure(exception: e));
      }
    } else {
      return Left(ServerFailure(exception: ServerException(message: 'No internet connection')));
    }
  }

  @override
  Future<Either<Failure, CreateGroupChatResponse>> createGroupChat(List<String> participantIds, String name) async {
    if (await networkInfo.isConnected) {
      try {
        final response = await remoteDataSource.createGroupChat(participantIds, name);
        return Right(response);
      } on ServerException catch (e) {
        return Left(ServerFailure(exception: e));
      }
    } else {
      return Left(ServerFailure(exception: ServerException(message: 'No internet connection')));
    }
  }

  @override
  Future<Either<Failure, MessageModel>> sendMessage(String chatId, String content, [String? mediaFilePath, String? messageType]) async {
    if (await networkInfo.isConnected) {
      try {
        String? localMediaPath = mediaFilePath;
        if (mediaFilePath != null && mediaFilePath.startsWith('http')) {
          developer.log('Downloading media file from $mediaFilePath');
          localMediaPath = await postRemoteDataSource.downloadFile(mediaFilePath);
        }
        final response = await remoteDataSource.sendMessage(chatId, content, localMediaPath, messageType);
        return Right(response);
      } on ServerException catch (e) {
        return Left(ServerFailure(exception: e));
      }
    } else {
      return Left(ServerFailure(exception: ServerException(message: 'No internet connection')));
    }
  }

  @override
  Future<Either<Failure, MessageModel>> sendGroupMessage(String groupChatId, String content, [String? mediaFilePath, String? messageType]) async {
    if (await networkInfo.isConnected) {
      try {
        String? localMediaPath = mediaFilePath;
        if (mediaFilePath != null && mediaFilePath.startsWith('http')) {
          developer.log('Downloading media file from $mediaFilePath');
          localMediaPath = await postRemoteDataSource.downloadFile(mediaFilePath);
        }
        final response = await remoteDataSource.sendGroupMessage(groupChatId, content, localMediaPath, messageType);
        return Right(response);
      } on ServerException catch (e) {
        return Left(ServerFailure(exception: e));
      }
    } else {
      return Left(ServerFailure(exception: ServerException(message: 'No internet connection')));
    }
  }

  @override
  Future<Either<Failure, InboxResponse>> getInbox() async {
    if (await networkInfo.isConnected) {
      try {
        final response = await remoteDataSource.getInbox();
        return Right(response);
      } on ServerException catch (e) {
        return Left(ServerFailure(exception: e));
      }
    } else {
      return Left(ServerFailure(exception: ServerException(message: 'No internet connection')));
    }
  }

  @override
  Future<Either<Failure, MessageHistoryResponse>> getMessageHistory(String chatId) async {
    if (await networkInfo.isConnected) {
      try {
        final response = await remoteDataSource.getMessageHistory(chatId);
        return Right(response);
      } on ServerException catch (e) {
        return Left(ServerFailure(exception: e));
      }
    } else {
      return Left(ServerFailure(exception: ServerException(message: 'No internet connection')));
    }
  }

  @override
  Future<Either<Failure, DeleteMessageResponse>> deleteMessage(String messageId) async {
    if (await networkInfo.isConnected) {
      try {
        developer.log('Attempting to delete message with ID: $messageId');
        final response = await remoteDataSource.deleteMessage(messageId);
        developer.log('Delete message response: ${response.success}');
        return Right(response);
      } on ServerException catch (e) {
        developer.log('Delete message failed: ${e.message}');
        return Left(ServerFailure(exception: e));
      }
    } else {
      developer.log('No internet connection for delete message');
      return Left(ServerFailure(exception: ServerException(message: 'No internet connection')));
    }
  }

  @override
  Future<Either<Failure, DeleteGroupChatResponse>> deleteGroupChat(String groupChatId) async {
    if (await networkInfo.isConnected) {
      try {
        final response = await remoteDataSource.deleteGroupChat(groupChatId);
        return Right(response);
      } on ServerException catch (e) {
        return Left(ServerFailure(exception: e));
      }
    } else {
      return Left(ServerFailure(exception: ServerException(message: 'No internet connection')));
    }
  }
}