import 'package:kakan/core/network/models/user_details.dart';

class CreateChatRequest {
  final String userId;

  CreateChatRequest({required this.userId});

  Map<String, dynamic> toJson() => {'user_id': userId};
}

class CreateChatResponse {
  final String chatId;

  CreateChatResponse({required this.chatId});

  factory CreateChatResponse.fromJson(Map<String, dynamic> json) {
    return CreateChatResponse(chatId: json['chat_id']);
  }
}

class CreateGroupChatRequest {
  final List<String> participantIds;
  final String name;

  CreateGroupChatRequest({required this.participantIds, required this.name});

  Map<String, dynamic> toJson() => {
        'participant_ids': participantIds,
        'name': name,
      };
}

class CreateGroupChatResponse {
  final String chatId;

  CreateGroupChatResponse({required this.chatId});

  factory CreateGroupChatResponse.fromJson(Map<String, dynamic> json) {
    return CreateGroupChatResponse(chatId: json['chat_id']);
  }
}

class SendMessageRequest {
  final String content;

  SendMessageRequest({required this.content});

  Map<String, dynamic> toJson() => {'content': content};
}

class MessageModel {
  final String id;
  final String? internalId;
  final UserDetails senderDetails;
  final String created;
  final String modified;
  final String messageType;
  final String content;
  final String? mediaFile;
  final String timestamp;
  final bool isDeleted;
  final String chat;
  final String sender;

  MessageModel({
    required this.id,
    this.internalId,
    required this.senderDetails,
    required this.created,
    required this.modified,
    required this.messageType,
    required this.content,
    this.mediaFile,
    required this.timestamp,
    required this.isDeleted,
    required this.chat,
    required this.sender,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'],
      internalId: json['internal_id'],
      senderDetails: UserDetails.fromJson(json['sender_details']),
      created: json['created'],
      modified: json['modified'],
      messageType: json['message_type'],
      content: json['content'],
      mediaFile: json['media_file'],
      timestamp: json['timestamp'],
      isDeleted: json['is_deleted'],
      chat: json['chat'],
      sender: json['sender'],
    );
  }
}

class InboxResponse {
  final int count;
  final String? next;
  final String? previous;
  final List<ChatItemModel> results;

  InboxResponse({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });

  factory InboxResponse.fromJson(Map<String, dynamic> json) {
    var results = json['results'] as List;
    List<ChatItemModel> chats = results.map((i) => ChatItemModel.fromJson(i)).toList();
    return InboxResponse(
      count: json['count'],
      next: json['next'],
      previous: json['previous'],
      results: chats,
    );
  }
}

class ChatItemModel {
  final String id;
  final bool isGroup;
  final String? groupName;
  final String created;
  final MessageModel? lastMessage;
  final ParticipantsDetails participantsDetails;

  ChatItemModel({
    required this.id,
    required this.isGroup,
    this.groupName,
    required this.created,
    this.lastMessage,
    required this.participantsDetails,
  });

  factory ChatItemModel.fromJson(Map<String, dynamic> json) {
    return ChatItemModel(
      id: json['id'],
      isGroup: json['is_group'],
      groupName: json['name'], // Changed from json['group_name'] to json['name']
      created: json['created'],
      lastMessage: json['last_message'] != null ? MessageModel.fromJson(json['last_message']) : null,
      participantsDetails: ParticipantsDetails.fromJson(json['participants_details']),
    );
  }
}

class ParticipantsDetails {
  final UserDetails sender;
  final List<UserDetails> receivers;

  ParticipantsDetails({
    required this.sender,
    required this.receivers,
  });

  factory ParticipantsDetails.fromJson(Map<String, dynamic> json) {
    var receivers = json['receivers'] as List;
    List<UserDetails> receiverList = receivers.map((i) => UserDetails.fromJson(i)).toList();
    return ParticipantsDetails(
      sender: UserDetails.fromJson(json['sender']),
      receivers: receiverList,
    );
  }
}

class MessageHistoryResponse {
  final int count;
  final String? next;
  final String? previous;
  final List<MessageModel> results;

  MessageHistoryResponse({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });

  factory MessageHistoryResponse.fromJson(Map<String, dynamic> json) {
    var results = json['results'] as List;
    List<MessageModel> messages = results.map((i) => MessageModel.fromJson(i)).toList();
    return MessageHistoryResponse(
      count: json['count'],
      next: json['next'],
      previous: json['previous'],
      results: messages,
    );
  }
}

class DeleteMessageResponse {
  final String success;

  DeleteMessageResponse({required this.success});

  factory DeleteMessageResponse.fromJson(Map<String, dynamic> json) {
    return DeleteMessageResponse(success: json['success']);
  }
}

class DeleteGroupChatResponse {
  final String success;

  DeleteGroupChatResponse({required this.success});

  factory DeleteGroupChatResponse.fromJson(Map<String, dynamic> json) {
    return DeleteGroupChatResponse(success: json['success']);
  }
}
