import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:go_router/go_router.dart';
import 'package:kakan/config/theme.dart';
import 'package:kakan/core/utils/session_manager.dart';
import 'package:kakan/features/chat/data/models/following_user_model.dart';
import 'package:kakan/features/chat/data/models/chat_models.dart';
import 'package:kakan/features/chat/presentation/bloc/chat_list_bloc/chat_bloc.dart';
import 'package:kakan/features/chat/presentation/bloc/chat_list_bloc/chat_event.dart';
import 'package:kakan/features/chat/presentation/bloc/chat_list_bloc/chat_state.dart';
import 'package:kakan/features/chat/presentation/pages/chat_screen.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:kakan/core/network/models/user_details.dart';
import 'dart:developer' as developer;

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

  final TextEditingController _searchController = TextEditingController();

  List<ChatItemModel> _filteredChats = [];
  List<ChatItemModel> _allChats = [];
  bool _hasFetchedInbox = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      final query = _searchController.text.trim().toLowerCase();
      if (query.isEmpty) {
        _filteredChats = _allChats;
      } else {
        _filteredChats = _allChats.where((chat) {
          final name = chat.isGroup
              ? (chat.groupName ?? '').toLowerCase()
              : (chat.participantsDetails.receivers.first.name ?? '').toLowerCase();
          return name.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _fetchInbox(BuildContext context) async {
    final sessionManager = di.sl<SessionManager>();
    final accessToken = await sessionManager.getAccessToken();
    if (accessToken != null) {
      context.read<ChatBloc>().add(const FetchInboxEvent());
    } else {
      if (!mounted) return;
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
        _showFollowingList = true; // open immediately so FAB hides
      });
      context.read<ChatBloc>().add(FetchFollowingUsers(userId));
    } else {
      if (!mounted) return;
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

  Future<void> _onRefresh(BuildContext blocContext) async {
    await _fetchInbox(blocContext);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseUrl = 'https://staging.api.kakan.co';

    return BlocProvider(
      create: (_) => di.sl<ChatBloc>(),
      child: Builder(
        builder: (blocContext) {
          if (!_hasFetchedInbox) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fetchInbox(blocContext);
              setState(() => _hasFetchedInbox = true);
            });
          }

          return Scaffold(
            backgroundColor: Colors.white,
            appBar: _ModernAppBar(onRefresh: () => _fetchInbox(blocContext)),
            body: Column(
              children: [
                // Search field
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: _SearchPill(
                    controller: _searchController,
                    onClear: () {
                      _searchController.clear();
                      setState(() => _filteredChats = _allChats);
                    },
                  ),
                ),

                // Content
                Expanded(
                  child: BlocConsumer<ChatBloc, ChatState>(
                    listener: (context, state) {
                      if (state is ChatFollowingLoaded) {
                        setState(() {
                          _followingUsers = state.users;
                          _showFollowingList = true; // make sure visible
                        });
                      } else if (state is ChatCreated) {
                        if (state.isGroup) {
                          Navigator.of(context)
                              .push(MaterialPageRoute(
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
                          ))
                              .then((_) {
                            blocContext.read<ChatBloc>().add(const FetchInboxEvent());
                          });
                        } else {
                          final selected = _followingUsers.isNotEmpty
                              ? _followingUsers.firstWhere(
                                  (u) => u.followedToDetails.id == state.selectedUserId,
                                  orElse: () => _followingUsers.first,
                                )
                              : FollowingUserModel(
                                  id: '',
                                  followedToDetails: FollowedToDetailsModel(
                                    id: state.selectedUserId,
                                    name: 'Chat',
                                    profileImage: null,
                                  ),
                                  created: '',
                                );

                          Navigator.of(context)
                              .push(MaterialPageRoute(
                            builder: (_) => BlocProvider<ChatBloc>(
                              create: (_) => di.sl<ChatBloc>(),
                              child: ChatScreen(
                                chatId: state.chatId,
                                receiver: selected,
                                isGroup: false,
                              ),
                            ),
                          ))
                              .then((_) {
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
                      } else if (state is ChatInboxLoaded) {
                        setState(() {
                          _allChats = state.chats;
                          _filteredChats = _allChats;
                          for (var chat in _allChats) {
                            developer.log('Chat ID: ${chat.id}, Group Name: ${chat.groupName}');
                          }
                          _onSearchChanged();
                        });
                      }
                    },
                    builder: (context, state) {
                      if (state is ChatLoading && _allChats.isEmpty) {
                        return const _ChatListSkeleton();
                      }

                      if ((_filteredChats.isEmpty && _allChats.isEmpty)) {
                        return _EmptyState(onTryAgain: () => _fetchInbox(blocContext));
                      }

                      return RefreshIndicator(
                        onRefresh: () => _onRefresh(blocContext),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          itemCount: _filteredChats.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final chat = _filteredChats[index];
                            final receiver = chat.isGroup ? null : chat.participantsDetails.receivers.first;
                            final lastMessage = chat.lastMessage?.content ?? 'No messages yet';

                            // group avatar decision: use first participant image if available
                            final String? groupAvatarUrl = chat.isGroup
                                ? (chat.participantsDetails.receivers.isNotEmpty
                                    ? chat.participantsDetails.receivers.first.profileImage
                                    : null)
                                : null;

                            return Dismissible(
                              key: Key(chat.id),
                              direction:
                                  chat.isGroup ? DismissDirection.endToStart : DismissDirection.none,
                              background: _DeleteBg(),
                              onDismissed: chat.isGroup
                                  ? (_) => blocContext.read<ChatBloc>().add(DeleteGroupChatEvent(chat.id))
                                  : null,
                              child: _ChatTile(
                                isGroup: chat.isGroup,
                                title: chat.isGroup
                                    ? (chat.groupName ?? 'Group Chat')
                                    : (receiver?.name ?? 'Unknown'),
                                subtitle: lastMessage,
                                time: _prettyTime(chat.created),
                                avatarUrl: chat.isGroup ? null : receiver?.profileImage,
                                groupAvatarUrl: groupAvatarUrl, // NEW
                                participants: chat.isGroup ? chat.participantsDetails.receivers : null,
                                baseUrl: baseUrl,
                                onTap: () {
                                  Navigator.of(context)
                                      .push(MaterialPageRoute(
                                    builder: (_) => BlocProvider<ChatBloc>(
                                      create: (_) => di.sl<ChatBloc>(),
                                      child: ChatScreen(
                                        chatId: chat.id,
                                        receiver: FollowingUserModel(
                                          id: chat.id,
                                          followedToDetails: FollowedToDetailsModel(
                                            id: chat.isGroup ? '' : (receiver?.id ?? ''),
                                            name: chat.isGroup
                                                ? (chat.groupName ?? 'Group Chat')
                                                : (receiver?.name ?? 'Unknown'),
                                            profileImage: chat.isGroup ? groupAvatarUrl : receiver?.profileImage,
                                          ),
                                          created: chat.created,
                                        ),
                                        isGroup: chat.isGroup,
                                        groupName: chat.groupName,
                                      ),
                                    ),
                                  ))
                                      .then((_) {
                                    blocContext.read<ChatBloc>().add(const FetchInboxEvent());
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),

                // Following / Group selection panel
                if (_showFollowingList)
                  _FollowingPanel(
                    isGroup: _isGroupChatCreation,
                    users: _followingUsers,
                    selectedUserIds: _selectedUserIds,
                    onToggleSelect: (id, selected) {
                      setState(() {
                        if (selected) {
                          _selectedUserIds.add(id);
                        } else {
                          _selectedUserIds.remove(id);
                        }
                      });
                    },
                    onClose: () {
                      setState(() {
                        _showFollowingList = false;
                        _selectedUserIds.clear();
                        _groupName = '';
                      });
                    },
                    onCreateGroup: () => _createGroupChat(blocContext),
                    onStartChat: (id) => _startNewChat(id, blocContext),
                    onNameChanged: (v) => _groupName = v,
                    groupName: _groupName,
                  ),
              ],
            ),

            // FAB (hidden when panel is open)
            floatingActionButton: !_showFollowingList
                ? SpeedDial(
                    icon: Icons.add,
                    iconTheme: const IconThemeData(color: Colors.white, size: 30),
                    activeIcon: Icons.close,
                    backgroundColor: appTheme.primaryColor,
                    elevation: 6,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    childMargin: const EdgeInsets.only(bottom: 6),
                    spacing: 6,
                    children: [
                      SpeedDialChild(
                        backgroundColor: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.chat, color: Colors.black),
                        label: 'New Chat',
                        labelBackgroundColor: Colors.white,
                        labelStyle: appTheme.textTheme.bodyMedium?.copyWith(color: Colors.black),
                        onTap: () => _fetchFollowingUsers(blocContext, isGroup: false),
                      ),
                      SpeedDialChild(
                        backgroundColor: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.group, color: Colors.black),
                        label: 'New Group Chat',
                        labelBackgroundColor: Colors.white,
                        labelStyle: appTheme.textTheme.bodyMedium?.copyWith(color: Colors.black),
                        onTap: () => _fetchFollowingUsers(blocContext, isGroup: true),
                      ),
                    ],
                  )
                : null,
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          );
        },
      ),
    );
  }

  String _prettyTime(String created) {
    // your API gives "DD/MM/YYYY, hh:mm AM"
    final parts = created.split(',');
    return parts.length > 1 ? parts[1].trim() : created;
  }
}

/* ======================= Widgets: AppBar & Search ======================= */

class _ModernAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onRefresh;
  const _ModernAppBar({required this.onRefresh});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8F9FF), Color(0xFFFFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.primaryColor.withOpacity(.2), theme.primaryColor.withOpacity(.05)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.chat_bubble_outline, color: theme.primaryColor),
          ),
          const SizedBox(width: 12),
          Text(
            'Chats',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w800,
              letterSpacing: .2,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Refresh',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}

class _SearchPill extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onClear;
  const _SearchPill({required this.controller, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE6E8EC)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Search chats...',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.grey),
              onPressed: onClear,
              splashRadius: 18,
            ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

/* =========================== Widgets: List UI =========================== */

class _ChatTile extends StatelessWidget {
  final bool isGroup;
  final String title;
  final String subtitle;
  final String time;
  final String? avatarUrl;      // individual user avatar
  final String? groupAvatarUrl; // NEW: group avatar (first participant or any provided)
  final List<UserDetails>? participants;
  final String baseUrl;
  final VoidCallback onTap;

  const _ChatTile({
    Key? key,
    required this.isGroup,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.avatarUrl,
    required this.groupAvatarUrl,
    required this.participants,
    required this.baseUrl,
    required this.onTap,
  }) : super(key: key);

  ImageProvider _userAvatarProvider() {
    if (avatarUrl == null) return const AssetImage('assets/images/avataruser.png');
    if (avatarUrl!.startsWith('http')) return NetworkImage(avatarUrl!);
    return NetworkImage('$baseUrl$avatarUrl');
  }

  ImageProvider _groupAvatarProvider() {
    final url = groupAvatarUrl;
    if (url == null || url.isEmpty) {
      return const AssetImage('assets/images/avataruser.png');
    }
    if (url.startsWith('http')) return NetworkImage(url);
    return NetworkImage('$baseUrl$url');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subColor = Colors.grey[600];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 14,
              offset: Offset(0, 4),
            )
          ],
          border: Border.all(color: const Color(0xFFEFF1F5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _GradientAvatar(
              child: CircleAvatar(
                backgroundColor: Colors.transparent,
                backgroundImage: isGroup ? _groupAvatarProvider() : _userAvatarProvider(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F1728),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        time,
                        style: theme.textTheme.labelMedium?.copyWith(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: subColor,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientAvatar extends StatelessWidget {
  final Widget child;
  const _GradientAvatar({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF8E8CF6), Color(0xFF5856D6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Color(0x1A5856D6), blurRadius: 10, offset: Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        padding: const EdgeInsets.all(2),
        child: ClipOval(child: child),
      ),
    );
  }
}

class _DeleteBg extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: Colors.red.shade500,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.delete, color: Colors.white, size: 30),
    );
  }
}

/* ============================ Widgets: Empty ============================ */

class _EmptyState extends StatelessWidget {
  final VoidCallback onTryAgain;
  const _EmptyState({required this.onTryAgain});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFF2F4F7),
              ),
              child: const Icon(Icons.chat_bubble_outline, size: 44, color: Colors.grey),
            ),
            const SizedBox(height: 18),
            Text(
              'No chats yet',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Start a new conversation from the button below.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onTryAgain,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/* =========================== Widgets: Skeleton ========================== */

class _ChatListSkeleton extends StatelessWidget {
  const _ChatListSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget _row() => Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFF2F4F7),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  Container(height: 14, decoration: _shimmerBox),
                  const SizedBox(height: 8),
                  Container(height: 12, decoration: _shimmerBox),
                ],
              ),
            ),
          ],
        );

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEFF1F5)),
        ),
        child: _row(),
      ),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemCount: 8,
    );
  }

  static const _shimmerBox = BoxDecoration(
    color: Color(0xFFF2F4F7),
    borderRadius: BorderRadius.all(Radius.circular(8)),
  );
}

/* ====================== Widgets: Following/Group Panel ====================== */

class _FollowingPanel extends StatefulWidget {
  final bool isGroup;
  final List<FollowingUserModel> users;
  final List<String> selectedUserIds;
  final void Function(String id, bool selected) onToggleSelect;
  final VoidCallback onClose;
  final VoidCallback onCreateGroup;
  final void Function(String userId) onStartChat;
  final ValueChanged<String> onNameChanged;
  final String groupName;

  const _FollowingPanel({
    required this.isGroup,
    required this.users,
    required this.selectedUserIds,
    required this.onToggleSelect,
    required this.onClose,
    required this.onCreateGroup,
    required this.onStartChat,
    required this.onNameChanged,
    required this.groupName,
  });

  @override
  State<_FollowingPanel> createState() => _FollowingPanelState();
}

class _FollowingPanelState extends State<_FollowingPanel> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<FollowingUserModel> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.users;
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void didUpdateWidget(covariant _FollowingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.users != widget.users) {
      _filtered = _applyFilter(_searchCtrl.text, widget.users);
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    setState(() {
      _filtered = _applyFilter(_searchCtrl.text, widget.users);
    });
  }

  List<FollowingUserModel> _applyFilter(String q, List<FollowingUserModel> source) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return List.from(source);
    return source.where((u) => u.followedToDetails.name.toLowerCase().contains(query)).toList();
    }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.8; // taller modal

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      height: maxHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFE6E8EC),
              borderRadius: BorderRadius.circular(50),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Text(
                  widget.isGroup ? 'Create Group Chat' : 'Select a user',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF101828),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                  splashRadius: 20,
                )
              ],
            ),
          ),

          // Search inside modal
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE6E8EC)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  const Icon(Icons.search, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Search people...',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      ),
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                      onPressed: () {
                        _searchCtrl.clear();
                        _onSearch();
                      },
                      splashRadius: 18,
                    ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),

          if (widget.isGroup)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Enter group name',
                  filled: true,
                  fillColor: const Color(0xFFF7F7FA),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE6E8EC)),
                  ),
                ),
                onChanged: widget.onNameChanged,
              ),
            ),

          // Selected chips (group mode)
          if (widget.isGroup && widget.selectedUserIds.isNotEmpty)
            SizedBox(
              height: 42,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemBuilder: (_, i) {
                  final id = widget.selectedUserIds[i];
                  final user = widget.users.firstWhere((u) => u.followedToDetails.id == id);
                  return Chip(
                    label: Text(user.followedToDetails.name),
                    onDeleted: () => widget.onToggleSelect(id, false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: widget.selectedUserIds.length,
              ),
            ),

          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final user = _filtered[index];
                final isSelected = widget.selectedUserIds.contains(user.followedToDetails.id);

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFEFF1F5)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundImage: user.followedToDetails.profileImage != null
                          ? (user.followedToDetails.profileImage!.startsWith('http')
                              ? NetworkImage(user.followedToDetails.profileImage!)
                              : NetworkImage('https://staging.api.kakan.co${user.followedToDetails.profileImage!}'))
                          : const AssetImage('assets/images/avataruser.png') as ImageProvider,
                      backgroundColor: const Color(0xFFF2F4F7),
                    ),
                    title: Text(
                      user.followedToDetails.name,
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    trailing: widget.isGroup
                        ? Checkbox(
                            value: isSelected,
                            onChanged: (value) =>
                                widget.onToggleSelect(user.followedToDetails.id, value == true),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: widget.isGroup
                        ? () => widget.onToggleSelect(user.followedToDetails.id, !isSelected)
                        : () => widget.onStartChat(user.followedToDetails.id),
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onClose,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF101828),
                      side: const BorderSide(color: Color(0xFFE6E8EC)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                if (widget.isGroup)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: widget.onCreateGroup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5856D6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: const Text('Create Group'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
