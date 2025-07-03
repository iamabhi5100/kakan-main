import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import 'package:toastification/toastification.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isVideoTabActive = true;
  bool _isOperationInProgress = false;
  final SessionManager _sessionManager = di.sl<SessionManager>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        // Fetch profile posts
        context.read<ProfilePostsBloc>().add(GetProfilePostsEvent(mediaType: 'video'));
        // Fetch profile details
        final userId = await _sessionManager.getUserId();
        if (userId != null) {
          context.read<ProfiledetailsBloc>().add(GetProfiledetailsEvent(userId: userId));
        } else {
          if (kDebugMode) {
            print('ProfileScreen: User ID not found');
          }
          toastification.show(
            context: context,
            title: const Text('User ID not found. Please log in again.'),
            type: ToastificationType.error,
            style: ToastificationStyle.fillColored,
            autoCloseDuration: const Duration(seconds: 3),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (kDebugMode) {
      print('ProfileScreen: Disposed');
    }
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

      // Pause media
      MediaManager().pauseMedia();

      // Clear all stored data from SessionManager
      await _sessionManager.clearTokens();
      await _sessionManager.clearVerifyOtpResponse();

      Navigator.pop(context); // Close loading dialog
      GoRouter.of(context).go('/login', extra: {'showLogoutSuccess': true}); // Navigate to login with success flag
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      toastification.show(
        context: context,
        title: Text('Logout failed: $e'),
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        autoCloseDuration: const Duration(seconds: 3),
      );
    }
  }

  void _handleTabChange(bool isVideoActive) {
    if (_isOperationInProgress) {
      if (kDebugMode) {
        print('Tab change blocked: Operation in progress');
      }
      return;
    }
    if (_isVideoTabActive != isVideoActive) {
      setState(() {
        _isVideoTabActive = isVideoActive;
      });
      final mediaType = isVideoActive ? 'video' : 'audio';
      if (mounted) {
        context.read<ProfilePostsBloc>().add(GetProfilePostsEvent(mediaType: mediaType));
      }
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
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: context.read<ProfilePostsBloc>()),
        BlocProvider.value(value: context.read<ProfiledetailsBloc>()),
      ],
      child: PopScope(
        canPop: !_isOperationInProgress,
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            actionsPadding: const EdgeInsets.only(right: 16),
            title: Text(
              'Profile',
              style: appTheme.textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(

                icon: Icon(Icons.logout, color: Colors.black),
                onPressed: _logout,
                tooltip: 'Logout',
                
              ),
            ],
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black),
          ),
          body: Column(
            children: [
              // Profile Header
              BlocBuilder<ProfiledetailsBloc, ProfiledetailsState>(
                builder: (context, state) {
                  String name = '';
                  String username = '';
                  String followersCount = '';
                  String followingCount = '';
                  String? profileImage;

                  if (state is ProfiledetailsLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is ProfiledetailsLoaded) {
                    name = state.profileDetails.name ?? 'User';
                    username = '@${state.profileDetails.username}';
                    followersCount = state.profileDetails.followersCount.toString();
                    followingCount = state.profileDetails.followingCount.toString();
                    profileImage = state.profileDetails.profileImage;
                  } else if (state is ProfiledetailsError) {
                    return Center(child: Text(state.message));
                  }

                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: profileImage != null
                              ? NetworkImage(profileImage)
                              : const NetworkImage(
                                  'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQyRhSPTCYGo76ZTjyt2mRqnTPtmz5rWAavFmqn9Wkm54-5detlTZkO_8o&usqp=CAE&s',
                                ),
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
              // Tabs
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
                              fontWeight: FontWeight.w600),
                        ),
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
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blue,
                onTap: (index) => _handleTabChange(index == 0),
              ),
              // Tab Content
              Expanded(
                child: BlocBuilder<ProfilePostsBloc, ProfilePostsState>(
                  builder: (context, state) {
                    if (state is ProfilePostsLoading) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (state is ProfilePostsLoaded) {
                      return _isVideoTabActive
                          ? _buildPostListVideo(state.posts)
                          : _buildPostListAudio(state.posts);
                    } else if (state is ProfilePostsError) {
                      return Center(child: Text(state.message));
                    }
                    return const Center(child: Text('No posts available'));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
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

  Widget _buildPostListVideo(List<ProfilePostEntity> posts) {
    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: VideoFeedWidget(post: post),
        );
      },
    );
  }

  Widget _buildPostListAudio(List<ProfilePostEntity> posts) {
    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: AudioFeedWidget(post: post),
        );
      },
    );
  }
}