import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kakan/config/theme.dart';
import 'package:kakan/core/utils/media_manager.dart';
import 'package:kakan/core/utils/session_manager.dart';
import 'package:kakan/features/home/presentation/widgets/audio_feed_widget.dart';
import 'package:kakan/features/home/presentation/widgets/video_feed_widget.dart';
import 'package:kakan/features/profile/domain/entities/profile_post_entity.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_detail/profiledetails_bloc.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_detail/profiledetails_event.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_detail/profiledetails_state.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_post_list/profile_posts_bloc.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_post_list/profile_posts_event.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_post_list/profile_posts_state.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_bloc.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isVideoTabActive = true;
  bool _isOperationInProgress = false;
  final SessionManager _sessionManager = di.sl<SessionManager>();

  // NEW: track whether this screen is showing the logged-in user's profile
  bool _isOwnProfile = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _handleTabChange(_tabController.index == 0);
      } else {
        if (_isVideoTabActive != (_tabController.index == 0)) {
          _handleTabChange(_tabController.index == 0);
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDataForUser();
      _determineOwnership();
    });
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userId != oldWidget.userId) {
      _fetchDataForUser();
      _determineOwnership();
    }
  }

  Future<void> _determineOwnership() async {
    // Consider it "own profile" if:
    // - /profile route (widget.userId == null)
    // - /user/:id AND id == current user's profileId
    try {
      final myId = await _sessionManager.getProfileId();
      final own = widget.userId == null || (myId != null && widget.userId == myId);
      if (mounted && _isOwnProfile != own) {
        setState(() => _isOwnProfile = own);
      }
    } catch (_) {
      if (mounted) setState(() => _isOwnProfile = widget.userId == null);
    }
  }

  Future<void> _fetchDataForUser() async {
    if (!mounted) return;

    String? targetUserId = widget.userId;
    if (targetUserId == null) {
      targetUserId = await _sessionManager.getProfileId();
    }

    if (targetUserId != null) {
      context.read<ProfiledetailsBloc>().add(
            GetProfiledetailsEvent(userId: targetUserId),
          );
      context.read<ProfilePostsBloc>().add(
            GetProfilePostsEvent(mediaType: 'video', userId: targetUserId),
          );
    } else {
      if (kDebugMode) {
        print('ProfileScreen: No target user ID found to fetch data.');
      }
      Fluttertoast.showToast(
        msg: 'User ID not found. Please log in again.',
        backgroundColor: Colors.red,
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    MediaManager().pauseAll();
    super.dispose();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Logging out...'),
            ],
          ),
        ),
      );

      MediaManager().pauseAll();
      await _sessionManager.clearTokens();
      await _sessionManager.clearVerifyOtpResponse();

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        Fluttertoast.showToast(
          msg: 'Logged out successfully',
          backgroundColor: Colors.green,
        );
        GoRouter.of(context).go('/login', extra: {'showLogoutSuccess': true});
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        Fluttertoast.showToast(
          msg: 'Logout failed: $e',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  void _handleTabChange(bool isVideoActive) async {
    if (_isOperationInProgress || _isVideoTabActive == isVideoActive) {
      return;
    }
    setState(() {
      _isVideoTabActive = isVideoActive;
    });

    String? targetUserId = widget.userId ?? await _sessionManager.getProfileId();
    if (targetUserId != null && mounted) {
      final mediaType = isVideoActive ? 'video' : 'audio';
      context.read<ProfilePostsBloc>().add(
            GetProfilePostsEvent(mediaType: mediaType, userId: targetUserId),
          );
    }
  }

  void _onOperationStateChanged(bool isInProgress) {
    if (mounted) {
      setState(() {
        _isOperationInProgress = isInProgress;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FeedBloc>(
      create: (_) => di.sl<FeedBloc>(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverAppBar(
                title: Text(
                  widget.userId == null ? 'Profile' : 'User Profile',
                  style: appTheme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                actions: [
                  // NEW: Show "Edit" when viewing own profile (both /profile and /user/:id if id == me)
                  if (_isOwnProfile)
                    IconButton(
                      tooltip: 'Edit Profile',
                      icon: const Icon(Icons.edit_outlined, color: Colors.black),
                      onPressed: () => context.go('/update-profile'),
                    ),
                  // Keep existing logout button on /profile (optional to extend to _isOwnProfile as well)
                  if (widget.userId == null)
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.black),
                      onPressed: _logout,
                      tooltip: 'Logout',
                    ),
                ],
                pinned: true,
                floating: true,
                forceElevated: innerBoxIsScrolled,
                backgroundColor: Colors.white,
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.black),
              ),
              SliverToBoxAdapter(
                child: BlocBuilder<ProfiledetailsBloc, ProfiledetailsState>(
                  builder: (context, state) {
                    String name = '';
                    String username = '';
                    String followersCount = '';
                    String followingCount = '';
                    String? profileImage;

                    if (state is ProfiledetailsLoading) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    } else if (state is ProfiledetailsLoaded) {
                      name = state.profileDetails.name ?? 'User';
                      username = '@${state.profileDetails.username}';
                      followersCount =
                          state.profileDetails.followersCount.toString();
                      followingCount =
                          state.profileDetails.followingCount.toString();
                      profileImage = state.profileDetails.profileImage;
                    } else if (state is ProfiledetailsError) {
                      return Center(child: Text(state.message));
                    }

                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: profileImage != null &&
                                        profileImage.isNotEmpty
                                    ? NetworkImage(profileImage)
                                    : const AssetImage(
                                        'assets/images/avataruser.png',
                                      ) as ImageProvider,
                                fit: BoxFit.cover,
                              ),
                              color: Colors.grey,
                            ),
                            child: profileImage == null || profileImage.isEmpty
                                ? Center(
                                    child: Text(
                                      username.isNotEmpty && username.length > 1
                                          ? username[1].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const Gap(20),
                          Text(
                            name,
                            style: appTheme.textTheme.titleLarge?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Gap(8),
                          Text(
                            username,
                            style: appTheme.textTheme.titleSmall?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const Gap(20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatColumn('Followers', followersCount),
                              _buildStatColumn('Following', followingCount),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SliverPersistentHeader(
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.videocam),
                            SizedBox(width: 8),
                            Text(
                              'Video',
                              style: TextStyle(
                                fontFamily: 'Product Sans',
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.music_note),
                            SizedBox(width: 8),
                            Text(
                              'Song',
                              style: TextStyle(
                                fontFamily: 'Product Sans',
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                    labelColor: Colors.blue,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.blue,
                    onTap: (index) => _handleTabChange(index == 0),
                  ),
                ),
                pinned: true,
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildPostList(),
              _buildPostList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostList() {
    return BlocBuilder<ProfiledetailsBloc, ProfiledetailsState>(
      builder: (context, profileState) {
        String name = 'Unknown User';
        String username = 'unknown';
        String? profileImage;
        String? profileOwnerId;

        if (profileState is ProfiledetailsLoaded) {
          name = profileState.profileDetails.name ?? 'Unknown User';
          username = profileState.profileDetails.username;
          profileImage = profileState.profileDetails.profileImage;
          profileOwnerId = profileState.profileDetails.id;
        }

        return BlocBuilder<ProfilePostsBloc, ProfilePostsState>(
          builder: (context, postState) {
            if (postState is ProfilePostsLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (postState is ProfilePostsLoaded) {
              if (profileOwnerId == null) {
                return const Center(child: Text('Waiting for user details...'));
              }
              return _isVideoTabActive
                  ? _buildPostListVideo(
                      postState.posts, name, username, profileImage, profileOwnerId)
                  : _buildPostListAudio(
                      postState.posts, name, username, profileImage, profileOwnerId);
            } else if (postState is ProfilePostsError) {
              return Center(child: Text(postState.message));
            }
            return const Center(child: Text('No posts available'));
          },
        );
      },
    );
  }

  Widget _buildStatColumn(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: appTheme.textTheme.titleSmall?.copyWith(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildPostListVideo(
    List<ProfilePostEntity> posts,
    String name,
    String username,
    String? profileImage,
    String userId,
  ) {
    if (posts.isEmpty) {
      return const Center(child: Text('No videos posted yet.'));
    }
    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: VideoFeedWidget(
            post: post,
            name: name,
            username: username,
            profileImage: profileImage,
            userId: userId,
          ),
        );
      },
    );
  }

  Widget _buildPostListAudio(
    List<ProfilePostEntity> posts,
    String name,
    String username,
    String? profileImage,
    String userId,
  ) {
    if (posts.isEmpty) {
      return const Center(child: Text('No songs posted yet.'));
    }
    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: AudioFeedWidget(
            post: post,
            name: name,
            username: username,
            profileImage: profileImage,
            userId: userId,
          ),
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
