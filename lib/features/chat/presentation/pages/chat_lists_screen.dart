import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:go_router/go_router.dart';
import 'package:kakan/config/theme.dart';
import 'package:kakan/core/utils/session_manager.dart';
import 'package:kakan/features/chat/data/models/following_user_model.dart';
import 'package:kakan/features/chat/presentation/bloc/chat_list_bloc/chat_bloc.dart';
import 'package:kakan/features/chat/presentation/bloc/chat_list_bloc/chat_event.dart';
import 'package:kakan/features/chat/presentation/bloc/chat_list_bloc/chat_state.dart';
import 'package:kakan/features/chat/presentation/pages/chat_screen.dart';
import 'package:kakan/features/chat/presentation/widgets/chat_item.dart';
import 'package:kakan/injection_container.dart' as di;

class ChatListsScreen extends StatefulWidget {
  const ChatListsScreen({Key? key}) : super(key: key);

  @override
  State<ChatListsScreen> createState() => _ChatListsScreenState();
}

class _ChatListsScreenState extends State<ChatListsScreen> {
  bool _showFollowingList = false;
  bool _isGroupChatCreation = false;
  List<FollowingUserModel> _followingUsers = [];
  List<String> _selectedUserIds = [];
  String _groupName = '';

  @override
  void initState() {
    super.initState();
  }

  Future<void> _fetchInbox(BuildContext context) async {
    final sessionManager = di.sl<SessionManager>();
    final accessToken = await sessionManager.getAccessToken();
    if (accessToken != null) {
      context.read<ChatBloc>().add(const FetchInboxEvent());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      context.go('/login');
    }
  }

  Future<void> _fetchFollowingUsers(BuildContext context, {bool isGroup = false}) async {
    final sessionManager = di.sl<SessionManager>();
    final userId = await sessionManager.getUserId();
    final accessToken = await sessionManager.getAccessToken();
    if (userId != null && accessToken != null) {
      setState(() {
        _isGroupChatCreation = isGroup;
        _selectedUserIds.clear();
        _groupName = '';
      });
      context.read<ChatBloc>().add(FetchFollowingUsers(userId));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      context.go('/login');
    }
  }

  void _startNewChat(String userId, BuildContext context) {
    context.read<ChatBloc>().add(CreateChatEvent(userId));
  }

  void _createGroupChat(BuildContext context) {
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one user')),
      );
      return;
    }
    if (_groupName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }
    context.read<ChatBloc>().add(CreateGroupChatEvent(
      participantIds: _selectedUserIds,
      name: _groupName,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => di.sl<ChatBloc>(),
      child: Builder(
        builder: (blocContext) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _fetchInbox(blocContext);
          });

          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              elevation: 2,
              shadowColor: Colors.grey[200],
              backgroundColor: Colors.white,
              title: Text(
                'Chats',
                style: appTheme.textTheme.titleLarge?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(24.0),
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search chats...',
                        hintStyle: appTheme.textTheme.bodyMedium,
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: BlocConsumer<ChatBloc, ChatState>(
                    listener: (context, state) {
                      if (state is ChatFollowingLoaded) {
                        setState(() {
                          _followingUsers = state.users;
                          _showFollowingList = true;
                        });
                      } else if (state is ChatCreated) {
                        if (state.isGroup) {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => BlocProvider<ChatBloc>(
                              create: (_) => di.sl<ChatBloc>(),
                              child: ChatScreen(
                                chatId: state.chatId,
                                receiver: FollowingUserModel(
                                  id: '',
                                  followedToDetails: FollowedToDetailsModel(
                                    id: '',
                                    name: state.groupName ?? 'Group Chat',
                                    profileImage: null,
                                  ),
                                  created: '',
                                ),
                                isGroup: true,
                                groupName: state.groupName,
                              ),
                            ),
                          )).then((_) {
                            blocContext.read<ChatBloc>().add(const FetchInboxEvent());
                          });
                        } else {
                          final selected = _followingUsers.firstWhere(
                            (u) => u.followedToDetails.id == state.selectedUserId,
                            orElse: () => _followingUsers.first,
                          );
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => BlocProvider<ChatBloc>(
                              create: (_) => di.sl<ChatBloc>(),
                              child: ChatScreen(
                                chatId: state.chatId,
                                receiver: selected,
                                isGroup: false,
                              ),
                            ),
                          )).then((_) {
                            blocContext.read<ChatBloc>().add(const FetchInboxEvent());
                          });
                        }
                        setState(() => _showFollowingList = false);
                      } else if (state is GroupChatDeleted) {
                        blocContext.read<ChatBloc>().add(const FetchInboxEvent());
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Group chat deleted')),
                        );
                      } else if (state is ChatError) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(state.message)),
                        );
                      }
                    },
                    builder: (context, state) {
                      if (state is ChatLoading) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (state is ChatInboxLoaded) {
                        final chats = state.chats;
                        if (chats.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'No chats found. Start a new chat!',
                                  style: appTheme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          itemCount: chats.length,
                          itemBuilder: (context, index) {
                            final chat = chats[index];
                            final receiver = chat.isGroup ? null : chat.participantsDetails.receivers.first;
                            final lastMessage = chat.lastMessage?.content ?? 'No messages yet';

                            return ChatItem(
                              user: FollowingUserModel(
                                id: chat.id,
                                followedToDetails: FollowedToDetailsModel(
                                  id: chat.isGroup ? '' : receiver!.id,
                                  name: chat.isGroup ? (chat.groupName ?? 'Group Chat') : (receiver!.name ?? 'Unknown'),
                                  profileImage: chat.isGroup ? null : receiver!.profileImage,
                                ),
                                created: chat.created,
                              ),
                              lastMessage: lastMessage,
                              isGroup: chat.isGroup,
                              participants: chat.isGroup ? chat.participantsDetails.receivers : [],
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => BlocProvider<ChatBloc>(
                                    create: (_) => di.sl<ChatBloc>(),
                                    child: ChatScreen(
                                      chatId: chat.id,
                                      receiver: FollowingUserModel(
                                        id: chat.id,
                                        followedToDetails: FollowedToDetailsModel(
                                          id: chat.isGroup ? '' : receiver!.id,
                                          name: chat.isGroup ? (chat.groupName ?? 'Group Chat') : (receiver!.name ?? 'Unknown'),
                                          profileImage: chat.isGroup ? null : receiver!.profileImage,
                                        ),
                                        created: chat.created,
                                      ),
                                      isGroup: chat.isGroup,
                                      groupName: chat.groupName,
                                    ),
                                  ),
                                )).then((_) {
                                  blocContext.read<ChatBloc>().add(const FetchInboxEvent());
                                });
                              },
                              onDismissed: chat.isGroup
                                  ? () {
                                      blocContext.read<ChatBloc>().add(DeleteGroupChatEvent(chat.id));
                                    }
                                  : null,
                            );
                          },
                        );
                      } else if (state is ChatError) {
                        return Center(
                          child: Text(
                            state.message,
                            style: appTheme.textTheme.bodyMedium?.copyWith(color: Colors.red),
                          ),
                        );
                      }
                      return const Center(child: Text('Tap to load chats'));
                    },
                  ),
                ),
                if (_showFollowingList)
                  Container(
                    height: 400,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey[300]!,
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _isGroupChatCreation ? 'Create Group Chat' : 'Select a user to chat',
                            style: appTheme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: appTheme.primaryColor,
                            ),
                          ),
                        ),
                        if (_isGroupChatCreation)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Enter group name',
                                hintStyle: appTheme.textTheme.bodyMedium,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                              ),
                              onChanged: (value) {
                                _groupName = value;
                              },
                            ),
                          ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            itemCount: _followingUsers.length,
                            itemBuilder: (context, index) {
                              final user = _followingUsers[index];
                              final isSelected = _selectedUserIds.contains(user.followedToDetails.id);
                              return Card(
                                color: Colors.white,
                                elevation: 1,
                                margin: const EdgeInsets.symmetric(vertical: 4.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(12.0),
                                  leading: CircleAvatar(
                                    radius: 24,
                                    backgroundImage: user.followedToDetails.profileImage != null
                                        ? NetworkImage(user.followedToDetails.profileImage!)
                                        : const AssetImage('assets/images/avatar1.png') as ImageProvider,
                                    backgroundColor: Colors.grey[200],
                                  ),
                                  title: Text(
                                    user.followedToDetails.name,
                                    style: appTheme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  trailing: _isGroupChatCreation
                                      ? Checkbox(
                                          value: isSelected,
                                          onChanged: (value) {
                                            setState(() {
                                              if (value == true) {
                                                _selectedUserIds.add(user.followedToDetails.id);
                                              } else {
                                                _selectedUserIds.remove(user.followedToDetails.id);
                                              }
                                            });
                                          },
                                        )
                                      : null,
                                  onTap: _isGroupChatCreation
                                      ? () {
                                          setState(() {
                                            if (isSelected) {
                                              _selectedUserIds.remove(user.followedToDetails.id);
                                            } else {
                                              _selectedUserIds.add(user.followedToDetails.id);
                                            }
                                          });
                                        }
                                      : () => _startNewChat(user.followedToDetails.id, blocContext),
                                ),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _showFollowingList = false;
                                    _selectedUserIds.clear();
                                    _groupName = '';
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[300],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                ),
                                child: Text(
                                  'Cancel',
                                  style: appTheme.textTheme.bodyMedium?.copyWith(color: Colors.black),
                                ),
                              ),
                              if (_isGroupChatCreation)
                                ElevatedButton(
                                  onPressed: () => _createGroupChat(blocContext),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: appTheme.primaryColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                  ),
                                  child: Text(
                                    'Create Group',
                                    style: appTheme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            floatingActionButton: SpeedDial(
              icon: Icons.add,
              iconTheme: const IconThemeData(
                color: Colors.white,
                size: 30,
              ),
              activeIcon: Icons.close,
              backgroundColor: appTheme.primaryColor,
              children: [
                SpeedDialChild(
                  child: const Icon(Icons.chat),
                  label: 'New Chat',
                  labelStyle: appTheme.textTheme.bodyMedium?.copyWith(color: Colors.black),
                  onTap: () => _fetchFollowingUsers(blocContext, isGroup: false),
                ),
                SpeedDialChild(
                  child: const Icon(Icons.group),
                  label: 'New Group Chat',
                  labelStyle: appTheme.textTheme.bodyMedium?.copyWith(color: Colors.black),
                  onTap: () => _fetchFollowingUsers(blocContext, isGroup: true),
                ),
              ],
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          );
        },
      ),
    );
  }
}