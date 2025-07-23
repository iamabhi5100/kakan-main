import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kakan/config/constant_api.dart';
import 'package:kakan/config/theme.dart';
import 'package:kakan/core/network/api_service.dart';
import 'package:kakan/core/utils/session_manager.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_bloc.dart';
import 'package:kakan/features/home/presentation/widgets/feed_data_list.dart';
import 'package:kakan/features/myfiles/presentation/myfiles_screen.dart';
import 'package:kakan/features/postmyfeed/presentation/main_post_screen.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_detail/profiledetails_bloc.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_post_list/profile_posts_bloc.dart';
import 'package:kakan/features/profile/presentation/profile_screen.dart';
import 'package:kakan/features/reels/presentation/pages/reels_page.dart';
import 'package:kakan/features/widgets/bottom_navigation_widget.dart';
import 'package:kakan/features/widgets/update_profile_widget.dart';
import 'package:kakan/injection_container.dart' as di;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isAuthenticated = false;
  bool _showUpdateProfileCard = false;
  String? _username;
  Future<Map<String, dynamic>>? _authStatusFuture;
  final ApiService _apiService = di.sl<ApiService>();
  final SessionManager _sessionManager = di.sl<SessionManager>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (kDebugMode) {
      print('HomeScreen: initState called');
    }
    _authStatusFuture = _checkAuthStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (kDebugMode) {
      print('HomeScreen: didChangeDependencies called');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (kDebugMode) {
      print('HomeScreen: dispose called');
    }
    super.dispose();
  }

  Future<Map<String, dynamic>> _checkAuthStatus() async {
    if (kDebugMode) {
      print('HomeScreen: Checking auth status');
    }
    try {
      final token = await _sessionManager.getAccessToken();
      if (token == null) {
        if (kDebugMode) {
          print('HomeScreen: No token found');
        }
        return {
          'isAuthenticated': false,
          'showUpdateProfileCard': false,
          'username': 'Guest',
        };
      }

      final userId = await _sessionManager.getUserId();
      if (userId == null) {
        if (kDebugMode) {
          print('HomeScreen: No userId found');
        }
        return {
          'isAuthenticated': false,
          'showUpdateProfileCard': false,
          'username': 'Guest',
        };
      }

      final response = await _apiService.get(
        '/v${ConstantApi.apiVersion}/user/$userId/',
        includeAuth: true,
      );

      if (response is Map<String, dynamic>) {
        final authData = {
          'isAuthenticated': true,
          'showUpdateProfileCard': response['show_update_profile_card'] ?? false,
          'username': response['username'] ?? 'Guest',
        };

        setState(() {
          _isAuthenticated = authData['isAuthenticated'] as bool;
          _showUpdateProfileCard = authData['showUpdateProfileCard'] as bool;
          _username = authData['username'] as String;
          _isLoading = false;
        });

        if (kDebugMode) {
          print('HomeScreen: Auth status updated: $_isAuthenticated, $_showUpdateProfileCard, $_username');
        }
        return authData;
      } else {
        throw Exception('Invalid response format');
      }
    } catch (e) {
      if (kDebugMode) {
        print('HomeScreen: Error fetching user data: $e');
      }
      setState(() {
        _isAuthenticated = false;
        _showUpdateProfileCard = false;
        _username = 'Guest';
        _isLoading = false;
      });
      return {
        'isAuthenticated': false,
        'showUpdateProfileCard': false,
        'username': 'Guest',
      };
    }
  }

  void _onNavTap(int index) {
    setState(() {
      _currentIndex = index;
      if (_currentIndex == 0) {
        _authStatusFuture = _checkAuthStatus();
        if (kDebugMode) {
          print('HomeScreen: Nav tapped, index: $index, refreshing auth status');
        }
      }
    });
  }

  Widget _getSelectedScreen() {
    if (kDebugMode) {
      print('HomeScreen: Building selected screen for index: $_currentIndex');
    }
    switch (_currentIndex) {
      case 0:
        return FutureBuilder<Map<String, dynamic>>(
          future: _authStatusFuture,
          builder: (context, snapshot) {
            if (kDebugMode) {
              print('HomeScreen: FutureBuilder state: ${snapshot.connectionState}');
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              if (kDebugMode) {
                print('HomeScreen: Error in _checkAuthStatus: ${snapshot.error}');
              }
              return const Center(child: Text('Error loading authentication status'));
            }

            final authData = snapshot.data!;
            _showUpdateProfileCard = authData['showUpdateProfileCard'] as bool;
            _username = authData['username'] as String;

            if (!authData['isAuthenticated']) {
              if (kDebugMode) {
                print('HomeScreen: Not authenticated, redirecting to login');
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go('/login');
              });
              return const Center(child: CircularProgressIndicator());
            }

            if (kDebugMode) {
              print('HomeScreen: Rendering feed with showUpdateProfileCard: $_showUpdateProfileCard');
            }
            return SingleChildScrollView(
              child: Column(
                children: [
                  if (_showUpdateProfileCard) const UpdateNavProfileWidget(),
                  const FeedDataList(),
                ],
              ),
            );
          },
        );
      case 1:
        return const MyfilesScreen();
      case 2:
        return const MainPostScreen();
      case 3:
        return const ReelsPage();
      case 4:
        return const ProfileScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print('HomeScreen: build called');
    }
    if (_isLoading) {
      if (kDebugMode) {
        print('HomeScreen: Showing loading indicator');
      }
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => di.sl<ProfilePostsBloc>()),
        BlocProvider(create: (_) => di.sl<FeedBloc>()),
        BlocProvider(create: (_) => di.sl<ProfiledetailsBloc>()),
      ],
      child: PopScope(
        onPopInvoked: (didPop) {
          if (didPop) {
            if (kDebugMode) {
              print('HomeScreen: Pop invoked, refreshing state');
            }
            setState(() {
              _authStatusFuture = _checkAuthStatus();
            });
          }
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: _currentIndex == 0
              ? AppBar(
                  title: GestureDetector(
                    onLongPress: () {
                      if (kDebugMode) {
                        context.go('/debug-settings');
                      }
                    },
                    child: Text(
                      'Hi, $_username',
                      style: appTheme.textTheme.titleSmall?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  actions: [
                    InkWell(
                      onTap: () {
                        context.push('/youtube-dashboard');
                      },
                      child: Image.asset(
                        'assets/images/youtubelogo.png',
                        width: 40,
                        height: 40,
                      ),
                    ),
                    const Gap(20),
                    InkWell(
                      onTap: () {
                        context.push('/chat');
                      },
                      child: Icon(
                        Icons.message,
                        color: Colors.grey[800],
                      ),
                    ),
                    const Gap(20),
                    InkWell(
                      onTap: () {
                        context.push('/search');
                      },
                      child: Icon(
                        Icons.search,
                        color: Colors.grey[800],
                      ),
                    ),
                    const Gap(20),
                  ],
                  backgroundColor: Colors.white,
                  elevation: 0,
                )
              : null,
          body: _getSelectedScreen(),
          bottomNavigationBar: BottomNavigationWidget(
            currentIndex: _currentIndex,
            onTap: _onNavTap,
          ),
        ),
      ),
    );
  }
}