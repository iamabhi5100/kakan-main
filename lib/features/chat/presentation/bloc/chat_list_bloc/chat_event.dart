import 'package:equatable/equatable.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object> get props => [];
}

class FetchFollowingUsers extends ChatEvent {
  final String userId;

  const FetchFollowingUsers(this.userId);

  @override
  List<Object> get props => [userId];
}

class CreateChatEvent extends ChatEvent {
  final String userId;

  const CreateChatEvent(this.userId);

  @override
  List<Object> get props => [userId];
}

class CreateGroupChatEvent extends ChatEvent {
  final List<String> participantIds;
  final String name;

  const CreateGroupChatEvent({required this.participantIds, required this.name});

  @override
  List<Object> get props => [participantIds, name];
}

class SendMessageEvent extends ChatEvent {
  final String chatId;
  final String content;

  const SendMessageEvent(this.chatId, this.content);

  @override
  List<Object> get props => [chatId, content];
}

class SendMediaMessageEvent extends ChatEvent {
  final String chatId;
  final String content;
  final String mediaFilePath;
  final String messageType;

  const SendMediaMessageEvent({
    required this.chatId,
    required this.content,
    required this.mediaFilePath,
    required this.messageType,
  });

  @override
  List<Object> get props => [chatId, content, mediaFilePath, messageType];
}

class SendGroupMessageEvent extends ChatEvent {
  final String groupChatId;
  final String content;

  const SendGroupMessageEvent(this.groupChatId, this.content);

  @override
  List<Object> get props => [groupChatId, content];
}

class SendMediaGroupMessageEvent extends ChatEvent {
  final String groupChatId;
  final String content;
  final String mediaFilePath;
  final String messageType;

  const SendMediaGroupMessageEvent({
    required this.groupChatId,
    required this.content,
    required this.mediaFilePath,
    required this.messageType,
  });

  @override
  List<Object> get props => [groupChatId, content, mediaFilePath, messageType];
}

class FetchInboxEvent extends ChatEvent {
  const FetchInboxEvent();

  @override
  List<Object> get props => [];
}

class FetchMessageHistoryEvent extends ChatEvent {
  final String chatId;

  const FetchMessageHistoryEvent(this.chatId);

  @override
  List<Object> get props => [chatId];
}

class DeleteMessageEvent extends ChatEvent {
  final String messageId;

  const DeleteMessageEvent(this.messageId);

  @override
  List<Object> get props => [messageId];
}

class DeleteGroupChatEvent extends ChatEvent {
  final String groupChatId;

  const DeleteGroupChatEvent(this.groupChatId);

  @override
  List<Object> get props => [groupChatId];
}