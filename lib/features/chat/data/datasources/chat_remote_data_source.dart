import 'package:dio/dio.dart';
import 'package:kakan/config/constant_api.dart';
import 'package:kakan/core/network/api_service.dart';
import 'package:kakan/core/utils/session_manager.dart';
import 'package:kakan/features/chat/data/models/chat_models.dart';
import 'package:kakan/features/chat/data/models/following_user_model.dart';

abstract class ChatRemoteDataSource {
  Future<FollowingUsersResponse> getFollowingUsers(String userId);
  Future<CreateChatResponse> createChat(String userId);
  Future<CreateGroupChatResponse> createGroupChat(List<String> participantIds, String name);
  Future<MessageModel> sendMessage(String chatId, String content, [String? mediaFilePath, String? messageType]);
  Future<MessageModel> sendGroupMessage(String groupChatId, String content, [String? mediaFilePath, String? messageType]);
  Future<InboxResponse> getInbox();
  Future<MessageHistoryResponse> getMessageHistory(String chatId);
  Future<DeleteMessageResponse> deleteMessage(String messageId);
  Future<DeleteGroupChatResponse> deleteGroupChat(String groupChatId);
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final ApiService apiService;
  final SessionManager sessionManager;

  ChatRemoteDataSourceImpl({
    required this.apiService,
    required this.sessionManager,
  });

  @override
  Future<FollowingUsersResponse> getFollowingUsers(String userId) async {
    final endpoint = ConstantApi.getFollowingUsers.replaceFirst('%s', userId);
    final response = await apiService.get(endpoint);
    return FollowingUsersResponse.fromJson(response);
  }

  @override
  Future<CreateChatResponse> createChat(String userId) async {
    final response = await apiService.post(
      ConstantApi.createChat,
      CreateChatRequest(userId: userId).toJson(),
    );
    return CreateChatResponse.fromJson(response);
  }

  @override
  Future<CreateGroupChatResponse> createGroupChat(List<String> participantIds, String name) async {
    final response = await apiService.post(
      ConstantApi.createGroupChat,
      CreateGroupChatRequest(participantIds: participantIds, name: name).toJson(),
    );
    return CreateGroupChatResponse.fromJson(response);
  }

  @override
  Future<MessageModel> sendMessage(String chatId, String content, [String? mediaFilePath, String? messageType]) async {
    final endpoint = ConstantApi.sendMessage.replaceFirst('%s', chatId);
    final formData = FormData.fromMap({
      'content': content,
      if (messageType != null) 'message_type': messageType,
      if (mediaFilePath != null) 'media_file': await MultipartFile.fromFile(mediaFilePath),
    });
    final response = await apiService.post(
      endpoint,
      formData,
      includeAuth: true,
    );
    return MessageModel.fromJson(response);
  }

  @override
  Future<MessageModel> sendGroupMessage(String groupChatId, String content, [String? mediaFilePath, String? messageType]) async {
    final endpoint = ConstantApi.sendGroupMessage.replaceFirst('%s', groupChatId);
    final formData = FormData.fromMap({
      'content': content,
      if (messageType != null) 'message_type': messageType,
      if (mediaFilePath != null) 'media_file': await MultipartFile.fromFile(mediaFilePath),
    });
    final response = await apiService.post(
      endpoint,
      formData,
      includeAuth: true,
    );
    return MessageModel.fromJson(response);
  }

  @override
  Future<InboxResponse> getInbox() async {
    final response = await apiService.get(ConstantApi.getInbox);
    return InboxResponse.fromJson(response);
  }

  @override
  Future<MessageHistoryResponse> getMessageHistory(String chatId) async {
    final endpoint = ConstantApi.getMessageHistory.replaceFirst('%s', chatId);
    final response = await apiService.get(endpoint);
    return MessageHistoryResponse.fromJson(response);
  }

  @override
  Future<DeleteMessageResponse> deleteMessage(String messageId) async {
    final endpoint = ConstantApi.deleteMessage.replaceFirst('%s', messageId);
    final response = await apiService.delete(endpoint);
    return DeleteMessageResponse.fromJson(response);
  }

  @override
  Future<DeleteGroupChatResponse> deleteGroupChat(String groupChatId) async {
    final endpoint = ConstantApi.deleteGroupChat.replaceFirst('%s', groupChatId);
    final response = await apiService.delete(endpoint);
    return DeleteGroupChatResponse.fromJson(response);
  }
}