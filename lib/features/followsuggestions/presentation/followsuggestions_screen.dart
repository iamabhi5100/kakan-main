// lib/features/followsuggestions/presentation/followsuggestions_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kakan/config/theme.dart';
import 'package:kakan/features/followsuggestions/data/models/suggestion_model.dart';
import 'package:kakan/features/followsuggestions/presentation/bloc/suggestion_bloc.dart';
import 'package:kakan/features/followsuggestions/presentation/bloc/suggestion_event.dart';
import 'package:kakan/features/followsuggestions/presentation/bloc/suggestion_state.dart';
import 'package:kakan/injection_container.dart' as di;

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class FollowSuggestionsScreen extends StatefulWidget {
  const FollowSuggestionsScreen({super.key});

  @override
  State<FollowSuggestionsScreen> createState() => _FollowSuggestionsScreenState();
}

class _FollowSuggestionsScreenState extends State<FollowSuggestionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<SuggestionModel> _filteredUsers = [];
  bool _isNavigating = false;

  void _searchUsers(String query, List<SuggestionModel> users) {
    if (query.trim().isEmpty) {
      setState(() {
        _filteredUsers = List.from(users);
      });
      return;
    }
    setState(() {
      final lowerQuery = query.toLowerCase();
      _filteredUsers = users.where((user) {
        return (user.username?.toLowerCase().contains(lowerQuery) ?? false) ||
            (user.name?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => di.sl<SuggestionBloc>()..add(FetchSuggestionsEvent()),
      child: ScaffoldMessenger(
        key: scaffoldMessengerKey,
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(
              'Discover People',
              style: appTheme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
            actions: [
              TextButton(
                onPressed: () {
                  if (!_isNavigating) {
                    _isNavigating = true;
                    context.go('/home');
                  }
                },
                child: Text(
                  'Skip',
                  style: appTheme.textTheme.titleMedium?.copyWith(
                    color: appTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          body: BlocConsumer<SuggestionBloc, SuggestionState>(
            listener: (context, state) {
              if (state is SuggestionFollowSuccess) {
                setState(() {
                  _filteredUsers = state.suggestions;
                });
              } else if (state is SuggestionFollowFailure) {
                setState(() {
                  _filteredUsers = state.suggestions;
                });
              }
            },
            builder: (context, state) {
              if (state is SuggestionLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is SuggestionLoaded || state is SuggestionFollowSuccess || state is SuggestionFollowFailure) {
                final suggestions = state is SuggestionLoaded
                    ? state.suggestions
                    : (state is SuggestionFollowSuccess ? state.suggestions : (state as SuggestionFollowFailure).suggestions);
                if (_filteredUsers.isEmpty && suggestions.isNotEmpty) {
                  _filteredUsers = List.from(suggestions);
                }
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onChanged: (query) => _searchUsers(query, suggestions),
                      ),
                    ),
                    Expanded(
                      child: _filteredUsers.isEmpty
                          ? const Center(child: Text('No users found'))
                          : ListView.builder(
                              itemCount: _filteredUsers.length,
                              itemBuilder: (context, index) {
                                final user = _filteredUsers[index];
                                return _UserCard(
                                  user: user,
                                  isLoading: state is SuggestionFollowLoading && state.userId == user.id,
                                  onFollowPressed: () {
                                    context.read<SuggestionBloc>().add(
                                          user.isFollowed
                                              ? UnfollowUserEvent(userId: user.id)
                                              : FollowUserEvent(userId: user.id),
                                        );
                                  },
                                );
                              },
                            ),
                    ),
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      decoration: BoxDecoration(
                        color: appTheme.primaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: MaterialButton(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40),
                        ),
                        onPressed: () {
                          if (!_isNavigating) {
                            _isNavigating = true;
                            context.go('/home');
                          }
                        },
                        child: Text(
                          "Proceed",
                          style: appTheme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              } else if (state is SuggestionFollowLoading && _filteredUsers.isNotEmpty) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onChanged: (query) => _searchUsers(query, _filteredUsers),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return _UserCard(
                            user: user,
                            isLoading: state.userId == user.id,
                            onFollowPressed: () {
                              context.read<SuggestionBloc>().add(
                                    user.isFollowed
                                        ? UnfollowUserEvent(userId: user.id)
                                        : FollowUserEvent(userId: user.id),
                                  );
                            },
                          );
                        },
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      decoration: BoxDecoration(
                        color: appTheme.primaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: MaterialButton(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40),
                        ),
                        onPressed: () {
                          if (!_isNavigating) {
                            _isNavigating = true;
                            context.go('/home');
                          }
                        },
                        child: Text(
                          "Proceed",
                          style: appTheme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              } else if (state is SuggestionFailure) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: ${state.message}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          context.read<SuggestionBloc>().add(FetchSuggestionsEvent());
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              return const Center(child: CircularProgressIndicator());
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _UserCard extends StatelessWidget {
  final SuggestionModel user;
  final bool isLoading;
  final VoidCallback onFollowPressed;

  const _UserCard({
    required this.user,
    required this.isLoading,
    required this.onFollowPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[200],
            child: ClipOval(
              child: user.profileImage != null
                  ? Image.network(
                      user.profileImage!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'assets/images/avataruser.png',
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        );
                      },
                    )
                  : Image.asset(
                      'assets/images/avataruser.png',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username ?? 'Unknown',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${user.name?.isNotEmpty == true ? user.name : 'Unknown'} • ${user.followersCount} Followers',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
          _FollowButton(
            isFollowing: user.isFollowed,
            isLoading: isLoading,
            onPressed: onFollowPressed,
          ),
        ],
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  final bool isFollowing;
  final bool isLoading;
  final VoidCallback onPressed;

  const _FollowButton({
    required this.isFollowing,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: appTheme.primaryColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
      ),
      child: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              isFollowing ? 'Unfollow' : 'Follow',
              style: TextStyle(
                color: appTheme.primaryColor,
                fontFamily: 'Product Sans',
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}
