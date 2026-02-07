import 'package:dartz/dartz.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/chat/data/models/chat_models.dart';
import 'package:kakan/features/chat/data/models/following_user_model.dart';

abstract class ChatRepository {
  Future<Either<Failure, FollowingUsersResponse>> getFollowingUsers(String userId);
  Future<Either<Failure, CreateChatResponse>> createChat(String userId);
  Future<Either<Failure, CreateGroupChatResponse>> createGroupChat(List<String> participantIds, String name);
  Future<Either<Failure, MessageModel>> sendMessage(String chatId, String content, [String? mediaFilePath, String? messageType]);
  Future<Either<Failure, MessageModel>> sendGroupMessage(String groupChatId, String content, [String? mediaFilePath, String? messageType]);
  Future<Either<Failure, InboxResponse>> getInbox();
  Future<Either<Failure, MessageHistoryResponse>> getMessageHistory(String chatId);
  Future<Either<Failure, DeleteMessageResponse>> deleteMessage(String messageId);
  Future<Either<Failure, DeleteGroupChatResponse>> deleteGroupChat(String groupChatId);
}