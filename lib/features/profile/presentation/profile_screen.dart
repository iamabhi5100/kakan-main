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
        context.read<ProfilePostsBloc>().add(
          GetProfilePostsEvent(mediaType: 'video'),
        );
        final userId = await _sessionManager.getUserId();
        if (userId != null) {
          context.read<ProfiledetailsBloc>().add(
            GetProfiledetailsEvent(userId: userId),
          );
        } else {
          if (kDebugMode) {
            print('ProfileScreen: User ID not found');
          }
          Fluttertoast.showToast(
            msg: 'User ID not found. Please log in again.',
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0,
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
      builder:
          (context) => AlertDialog(
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
        builder:
            (context) => const AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Logging out...'),
                ],
              ),
            ),
      );

      MediaManager().pauseMedia();
      await _sessionManager.clearTokens();
      await _sessionManager.clearVerifyOtpResponse();

      Navigator.pop(context); // Close loading dialog
      Fluttertoast.showToast(
        msg: 'Logged out successfully',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      GoRouter.of(context).go('/login', extra: {'showLogoutSuccess': true});
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      Fluttertoast.showToast(
        msg: 'Logout failed: $e',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
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
        context.read<ProfilePostsBloc>().add(
          GetProfilePostsEvent(mediaType: mediaType),
        );
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              12,
                            ), // Slightly rounded corners
                            image: DecorationImage(
                              image:
                                  profileImage != null &&
                                          profileImage.isNotEmpty
                                      ? NetworkImage(profileImage)
                                      : const AssetImage(
                                            'assets/images/avataruser.png',
                                          )
                                          as ImageProvider,
                              fit: BoxFit.cover,
                            ),

                            color: Colors.grey, // Fallback color if image fails
                          ),
                          child:
                              profileImage == null || profileImage.isEmpty
                                  ? Center(
                                    child: Text(
                                      username.isNotEmpty
                                          ? username[0].toUpperCase()
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
                            fontWeight: FontWeight.w600,
                          ),
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
              Expanded(
                child: BlocBuilder<ProfiledetailsBloc, ProfiledetailsState>(
                  builder: (context, profileState) {
                    String name = 'Unknown User';
                    String username = 'unknown';
                    String? profileImage;

                    if (profileState is ProfiledetailsLoaded) {
                      name =
                          profileState.profileDetails.name?.isNotEmpty == true
                              ? profileState.profileDetails.name!
                              : 'Unknown User';
                      username =
                          profileState.profileDetails.username?.isNotEmpty ==
                                  true
                              ? profileState.profileDetails.username
                              : 'unknown';
                      profileImage = profileState.profileDetails.profileImage;
                    }

                    return BlocBuilder<ProfilePostsBloc, ProfilePostsState>(
                      builder: (context, state) {
                        if (state is ProfilePostsLoading) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        } else if (state is ProfilePostsLoaded) {
                          return _isVideoTabActive
                              ? _buildPostListVideo(
                                state.posts,
                                name,
                                username,
                                profileImage,
                              )
                              : _buildPostListAudio(
                                state.posts,
                                name,
                                username,
                                profileImage,
                              );
                        } else if (state is ProfilePostsError) {
                          return Center(child: Text(state.message));
                        }
                        return const Center(child: Text('No posts available'));
                      },
                    );
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

  Widget _buildPostListVideo(
    List<ProfilePostEntity> posts,
    String name,
    String username,
    String? profileImage,
  ) {
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
  ) {
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
          ),
        );
      },
    );
  }
}
