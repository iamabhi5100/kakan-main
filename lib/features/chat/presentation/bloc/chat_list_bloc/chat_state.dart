// lib/features/chat/presentation/bloc/chat_list_bloc/chat_state.dart
import 'package:equatable/equatable.dart';
import 'package:kakan/features/chat/data/models/chat_models.dart';
import 'package:kakan/features/chat/data/models/following_user_model.dart';

abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object> get props => [];
}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatFollowingLoaded extends ChatState {
  final List<FollowingUserModel> users;

  const ChatFollowingLoaded({required this.users});

  @override
  List<Object> get props => [users];
}

class ChatCreated extends ChatState {
  final String chatId;
  final String selectedUserId;
  final bool isGroup;
  final String? groupName;

  const ChatCreated({
    required this.chatId,
    required this.selectedUserId,
    required this.isGroup,
    this.groupName,
  });

  @override
  List<Object> get props => [chatId, selectedUserId, isGroup, groupName ?? ''];
}

class MessageSent extends ChatState {
  final MessageModel message;

  const MessageSent({required this.message});

  @override
  List<Object> get props => [message];
}

class ChatInboxLoaded extends ChatState {
  final List<ChatItemModel> chats;

  const ChatInboxLoaded({required this.chats});

  @override
  List<Object> get props => [chats];
}

class ChatMessagesLoaded extends ChatState {
  final List<MessageModel> messages;

  const ChatMessagesLoaded({required this.messages});

  @override
  List<Object> get props => [messages];
}

class MessageDeleted extends ChatState {}

class GroupChatDeleted extends ChatState {}

class ChatError extends ChatState {
  final String message;

  const ChatError({required this.message});

  @override
  List<Object> get props => [message];
}
