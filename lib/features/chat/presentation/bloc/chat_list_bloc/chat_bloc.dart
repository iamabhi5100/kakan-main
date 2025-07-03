import 'package:bloc/bloc.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/core/usecases/usecase.dart';
import 'package:kakan/features/chat/domain/usecases/create_chat.dart';
import 'package:kakan/features/chat/domain/usecases/create_group_chat.dart';
import 'package:kakan/features/chat/domain/usecases/delete_group_chat.dart';
import 'package:kakan/features/chat/domain/usecases/delete_message.dart';
import 'package:kakan/features/chat/domain/usecases/get_following_users.dart';
import 'package:kakan/features/chat/domain/usecases/get_inbox.dart';
import 'package:kakan/features/chat/domain/usecases/get_message_history.dart';
import 'package:kakan/features/chat/domain/usecases/send_group_message.dart';
import 'package:kakan/features/chat/domain/usecases/send_message.dart';
import 'package:kakan/features/chat/presentation/bloc/chat_list_bloc/chat_event.dart';
import 'package:kakan/features/chat/presentation/bloc/chat_list_bloc/chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final GetFollowingUsers getFollowingUsers;
  final CreateChat createChat;
  final CreateGroupChat createGroupChat;
  final SendMessage sendMessage;
  final SendGroupMessage sendGroupMessage;
  final GetInbox getInbox;
  final GetMessageHistory getMessageHistory;
  final DeleteMessage deleteMessage;
  final DeleteGroupChat deleteGroupChat;

  ChatBloc({
    required this.getFollowingUsers,
    required this.createChat,
    required this.createGroupChat,
    required this.sendMessage,
    required this.sendGroupMessage,
    required this.getInbox,
    required this.getMessageHistory,
    required this.deleteMessage,
    required this.deleteGroupChat,
  }) : super(ChatInitial()) {
    on<FetchFollowingUsers>(_onFetchFollowingUsers);
    on<CreateChatEvent>(_onCreateChat);
    on<CreateGroupChatEvent>(_onCreateGroupChat);
    on<SendMessageEvent>(_onSendMessage);
    on<SendGroupMessageEvent>(_onSendGroupMessage);
    on<SendMediaMessageEvent>(_onSendMediaMessage);
    on<SendMediaGroupMessageEvent>(_onSendMediaGroupMessage);
    on<FetchInboxEvent>(_onFetchInbox);
    on<FetchMessageHistoryEvent>(_onFetchMessageHistory);
    on<DeleteMessageEvent>(_onDeleteMessage);
    on<DeleteGroupChatEvent>(_onDeleteGroupChat);
  }

  Future<void> _onFetchFollowingUsers(FetchFollowingUsers event, Emitter<ChatState> emit) async {
    emit(ChatLoading());
    final failureOrUsers = await getFollowingUsers(event.userId);
    emit(failureOrUsers.fold(
      (failure) => ChatError(message: _mapFailureToMessage(failure)),
      (users) => ChatFollowingLoaded(users: users.results),
    ));
  }

  Future<void> _onCreateChat(CreateChatEvent event, Emitter<ChatState> emit) async {
    emit(ChatLoading());
    final failureOrChat = await createChat(event.userId);
    emit(failureOrChat.fold(
      (failure) => ChatError(message: _mapFailureToMessage(failure)),
      (chat) => ChatCreated(chatId: chat.chatId, selectedUserId: event.userId, isGroup: false),
    ));
  }

  Future<void> _onCreateGroupChat(CreateGroupChatEvent event, Emitter<ChatState> emit) async {
    emit(ChatLoading());
    final failureOrChat = await createGroupChat(CreateGroupChatParams(
      participantIds: event.participantIds,
      name: event.name,
    ));
    emit(failureOrChat.fold(
      (failure) => ChatError(message: _mapFailureToMessage(failure)),
      (chat) => ChatCreated(chatId: chat.chatId, selectedUserId: '', isGroup: true, groupName: event.name),
    ));
  }

  Future<void> _onSendMessage(SendMessageEvent event, Emitter<ChatState> emit) async {
    emit(ChatLoading());
    final failureOrMessage = await sendMessage(SendMessageParams(chatId: event.chatId, content: event.content));
    emit(failureOrMessage.fold(
      (failure) => ChatError(message: _mapFailureToMessage(failure)),
      (message) => MessageSent(message: message),
    ));
  }

  Future<void> _onSendGroupMessage(SendGroupMessageEvent event, Emitter<ChatState> emit) async {
    emit(ChatLoading());
    final failureOrMessage = await sendGroupMessage(SendGroupMessageParams(groupChatId: event.groupChatId, content: event.content));
    emit(failureOrMessage.fold(
      (failure) => ChatError(message: _mapFailureToMessage(failure)),
      (message) => MessageSent(message: message),
    ));
  }

  Future<void> _onSendMediaMessage(SendMediaMessageEvent event, Emitter<ChatState> emit) async {
    emit(ChatLoading());
    final failureOrMessage = await sendMessage(SendMessageParams(
      chatId: event.chatId,
      content: event.content,
      mediaFilePath: event.mediaFilePath,
      messageType: event.messageType,
    ));
    emit(failureOrMessage.fold(
      (failure) => ChatError(message: _mapFailureToMessage(failure)),
      (message) => MessageSent(message: message),
    ));
  }

  Future<void> _onSendMediaGroupMessage(SendMediaGroupMessageEvent event, Emitter<ChatState> emit) async {
    emit(ChatLoading());
    final failureOrMessage = await sendGroupMessage(SendGroupMessageParams(
      groupChatId: event.groupChatId,
      content: event.content,
      mediaFilePath: event.mediaFilePath,
      messageType: event.messageType,
    ));
    emit(failureOrMessage.fold(
      (failure) => ChatError(message: _mapFailureToMessage(failure)),
      (message) => MessageSent(message: message),
    ));
  }

  Future<void> _onFetchInbox(FetchInboxEvent event, Emitter<ChatState> emit) async {
    emit(ChatLoading());
    final failureOrInbox = await getInbox(NoParams());
    emit(failureOrInbox.fold(
      (failure) => ChatError(message: _mapFailureToMessage(failure)),
      (inbox) => ChatInboxLoaded(chats: inbox.results),
    ));
  }

  Future<void> _onFetchMessageHistory(FetchMessageHistoryEvent event, Emitter<ChatState> emit) async {
    emit(ChatLoading());
    final failureOrHistory = await getMessageHistory(event.chatId);
    emit(failureOrHistory.fold(
      (failure) => ChatError(message: _mapFailureToMessage(failure)),
      (history) => ChatMessagesLoaded(messages: history.results),
    ));
  }

  Future<void> _onDeleteMessage(DeleteMessageEvent event, Emitter<ChatState> emit) async {
    print('Deleting message with ID: ${event.messageId}');
    emit(ChatLoading());
    final failureOrResponse = await deleteMessage(event.messageId);
    emit(failureOrResponse.fold(
      (failure) {
        print('Delete message failed: ${_mapFailureToMessage(failure)}');
        return ChatError(message: _mapFailureToMessage(failure));
      },
      (response) => MessageDeleted(),
    ));
  }

  Future<void> _onDeleteGroupChat(DeleteGroupChatEvent event, Emitter<ChatState> emit) async {
    emit(ChatLoading());
    final failureOrResponse = await deleteGroupChat(event.groupChatId);
    emit(failureOrResponse.fold(
      (failure) => ChatError(message: _mapFailureToMessage(failure)),
      (response) => GroupChatDeleted(),
    ));
  }

  String _mapFailureToMessage(Failure failure) {
    if (failure is ServerFailure) {
      return failure.exception?.message ?? 'Server error';
    }
    return 'Unexpected error';
  }
}