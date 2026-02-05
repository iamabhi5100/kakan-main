// lib/config/router.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:kakan/core/models/otp_page_args.dart';
import 'package:kakan/core/models/onboarding_form_args.dart';
import 'package:kakan/core/utils/session_manager.dart';

import 'package:kakan/features/chat/presentation/pages/chat_lists_screen.dart';
import 'package:kakan/features/followsuggestions/presentation/followsuggestions_screen.dart';
import 'package:kakan/features/home/home_screen.dart';
import 'package:kakan/features/login/data/datasources/remote_data_source.dart';
import 'package:kakan/features/login/presentation/pages/login_page.dart';
import 'package:kakan/features/login/presentation/pages/otp_page.dart';
import 'package:kakan/features/login/presentation/widgets/onboarding_form.dart';
import 'package:kakan/features/login/presentation/widgets/successfull_login.dart';
import 'package:kakan/features/myfiles/presentation/myfiles_screen.dart';
import 'package:kakan/features/onboarding/presentation/onboarding_screen.dart';

import 'package:kakan/features/postmyfeed/data/models/selected_media_item.dart';
import 'package:kakan/features/postmyfeed/presentation/audio_post_screen.dart' as audio_post;
import 'package:kakan/features/postmyfeed/presentation/carousel_post_screen.dart';
import 'package:kakan/features/postmyfeed/presentation/image_post_screen.dart';
import 'package:kakan/features/postmyfeed/presentation/main_post_screen.dart';
import 'package:kakan/features/postmyfeed/presentation/post_audio_editor_page.dart';
import 'package:kakan/features/postmyfeed/presentation/post_image_editor_screen.dart';
import 'package:kakan/features/postmyfeed/presentation/post_video_editor_screen.dart';
import 'package:kakan/features/postmyfeed/presentation/selected_items_page.dart';
import 'package:kakan/features/postmyfeed/presentation/video_post_screen.dart' as video_post;
import 'package:kakan/features/postmyfeed/presentation/bloc/post_bloc/post_bloc.dart';

import 'package:kakan/features/profile/presentation/bloc/profile_detail/profiledetails_bloc.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_post_list/profile_posts_bloc.dart';
import 'package:kakan/features/profile/presentation/pages/update_profile_screen.dart';
import 'package:kakan/features/profile/presentation/profile_screen.dart';

import 'package:kakan/features/reels/presentation/pages/reels_page.dart';
import 'package:kakan/features/search/presentation/search_screen.dart';
import 'package:kakan/features/splash/splash_screen.dart';

import 'package:kakan/features/youtube/domain/entities/video_entity.dart';
import 'package:kakan/features/youtube/presentation/bloc/youtube_bloc.dart';
import 'package:kakan/features/youtube/presentation/bloc/youtube_event.dart';
import 'package:kakan/features/youtube/presentation/pages/audio_editor_page.dart';
import 'package:kakan/features/youtube/presentation/pages/video_detail_screen.dart';
import 'package:kakan/features/youtube/presentation/pages/video_editor_screen.dart';
import 'package:kakan/features/youtube/presentation/pages/youtube_player_screen.dart';
import 'package:kakan/features/youtube/presentation/youtube_dashboard_screen.dart';

import 'package:kakan/injection_container.dart' as di;

/// Small helper that paints a white backplate while it checks auth.
/// If authenticated -> shows [child], else sends user to /login.
class AuthGate extends StatefulWidget {
  final Widget child;
  final String? returnToAfterLogin;

  const AuthGate({super.key, required this.child, this.returnToAfterLogin});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _session = di.sl<SessionManager>();
  bool _ready = false;
  bool _authed = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final token = await _session.getAccessToken();
      if (!mounted) return;
      _authed = token != null && token.isNotEmpty;
    } catch (_) {
      _authed = false;
    } finally {
      if (mounted) {
        setState(() => _ready = true);
        if (!_authed) {
          // Navigate after this frame, to avoid build-time redirects.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final returnTo = widget.returnToAfterLogin ?? '/home';
            context.go('/login', extra: {'returnTo': returnTo});
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always render something to avoid a blank frame.
    if (!_ready) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: SizedBox(width: 48, height: 48, child: CircularProgressIndicator(strokeWidth: 3))),
      );
    }
    if (_authed) return widget.child;

    // If we’re navigating to /login, keep a minimal white frame here.
    return const Scaffold(backgroundColor: Colors.white);
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title Screen')),
    );
  }
}

final GoRouter router = GoRouter(
  initialLocation: '/splash',
  routes: [
    // Splash — paints immediately, then decides /home or /login itself.
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),

    // Public
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(
      path: '/otp',
      builder: (context, state) {
        final args = state.extra as OTPPageArgs;
        return OTPPage(
          phone: args.phone,
          remoteDataSource: args.remoteDataSource,
        );
      },
    ),
    GoRoute(
      path: '/onboarding-form',
      builder: (context, state) {
        final args = state.extra as OnboardingFormArgs;
        return OnboardingForm(
          token: args.token,
          remoteDataSource: args.remoteDataSource,
        );
      },
    ),
    GoRoute(
      path: '/successful-login',
      builder: (context, state) => const SuccessfullLogin(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/follow-suggestions',
      builder: (context, state) => const FollowSuggestionsScreen(),
    ),

    // Protected with AuthGate
    GoRoute(
      path: '/home',
      builder: (context, state) => const AuthGate(child: HomeScreen()),
    ),
    GoRoute(
      path: '/youtube-dashboard',
      builder: (context, state) => AuthGate(
        child: BlocProvider(
          create: (_) => di.sl<YoutubeBloc>()..add(FetchHomeVideosEvent()),
          child: const YoutubeDashboardScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/youtube-player',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final video = extra['video'] as VideoEntity;
        final isShort = extra['isShort'] as bool? ?? false;
        return AuthGate(child: YoutubePlayerScreen(video: video, isShort: isShort));
      },
    ),
    GoRoute(
      path: '/video-detail',
      builder: (context, state) {
        final video = state.extra as VideoEntity;
        return AuthGate(
          child: BlocProvider(
            create: (_) => di.sl<YoutubeBloc>(),
            child: VideoDetailScreen(video: video),
          ),
        );
      },
    ),
    GoRoute(
      path: '/youtube-video-editor',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final filePath = extra['filePath'] as String?;
        final videoId = extra['videoId'] as String?;
        final title = extra['title'] as String?;
        return AuthGate(
          child: VideoEditorScreen(
            videoPath: filePath ?? '',
            videoId: videoId ?? '',
            title: title ?? '',
          ),
        );
      },
    ),
    GoRoute(
      path: '/youtube-audio-editor',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final filePath = extra['filePath'] as String?;
        final videoId = extra['videoId'] as String?;
        final title = extra['title'] as String?;
        final thumbnailUrl = extra['thumbnailUrl'] as String?;
        return AuthGate(
          child: AudioEditorPage(
            audioPath: filePath ?? '',
            videoId: videoId ?? '',
            title: title ?? '',
            thumbnailUrl: thumbnailUrl,
          ),
        );
      },
    ),
    GoRoute(
      path: '/post-video-editor',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final filePath = extra['filePath'] as String?;
        final mediaId = extra['mediaId'] as String?;
        final title = extra['title'] as String?;
        final fromCarousel = extra['fromCarousel'] as bool? ?? false;
        return AuthGate(
          child: PostVideoEditorScreen(
            videoPath: filePath ?? '',
            mediaId: mediaId,
            title: title,
            fromCarousel: fromCarousel,
          ),
        );
      },
    ),
    GoRoute(
      path: '/post-image-editor',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final filePath = extra['filePath'] as String? ?? '';
        return AuthGate(child: PostImageEditorScreen(filePath: filePath));
      },
    ),
    GoRoute(
      path: '/selected-items',
      builder: (context, state) {
        final items = state.extra as List<SelectedMediaItem>? ?? [];
        return AuthGate(child: SelectedItemsPage(initialItems: items));
      },
    ),
    GoRoute(
      path: '/carousel-post',
      builder: (context, state) {
        final items = state.extra as List<SelectedMediaItem>? ?? [];
        return AuthGate(
          child: BlocProvider(
            create: (_) => di.sl<PostBloc>(),
            child: CarouselPostScreen(items: items),
          ),
        );
      },
    ),
    GoRoute(
      path: '/post-audio-editor',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final filePath = extra['filePath'] as String?;
        final mediaId = extra['mediaId'] as String?;
        final title = extra['title'] as String?;
        return AuthGate(
          child: PostAudioEditorPage(
            audioPath: filePath ?? '',
            mediaId: mediaId,
            title: title,
          ),
        );
      },
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => AuthGate(
        child: MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => di.sl<ProfilePostsBloc>()),
            BlocProvider(create: (_) => di.sl<ProfiledetailsBloc>()),
          ],
          child: const ProfileScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/user/:userId',
      builder: (context, state) {
        final userId = state.pathParameters['userId'];
        return AuthGate(
          child: MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => di.sl<ProfilePostsBloc>()),
              BlocProvider(create: (_) => di.sl<ProfiledetailsBloc>()),
            ],
            child: ProfileScreen(userId: userId),
          ),
        );
      },
    ),
    GoRoute(
      path: '/update-profile',
      builder: (context, state) => const AuthGate(child: UpdateProfileScreen()),
    ),
    GoRoute(
      path: '/my-files',
      builder: (context, state) => const AuthGate(child: MyfilesScreen()),
    ),
    GoRoute(
      path: '/chat',
      builder: (context, state) => const AuthGate(child: ChatListsScreen()),
    ),
    GoRoute(path: '/search', builder: (context, state) => const AuthGate(child: SearchScreen())),
    GoRoute(
      path: '/reels',
      builder: (context, state) => const AuthGate(child: ReelsPage()),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const AuthGate(child: PlaceholderScreen(title: 'Notifications')),
    ),
    GoRoute(
      path: '/faqs',
      builder: (context, state) => const AuthGate(child: PlaceholderScreen(title: 'FAQs')),
    ),
    GoRoute(
      path: '/contact-details',
      builder: (context, state) => const AuthGate(child: PlaceholderScreen(title: 'Contact Details')),
    ),
    GoRoute(
      path: '/supports',
      builder: (context, state) => const AuthGate(child: PlaceholderScreen(title: 'Supports')),
    ),
    GoRoute(
      path: '/about-us',
      builder: (context, state) => const AuthGate(child: PlaceholderScreen(title: 'About Us')),
    ),
    GoRoute(
      path: '/privacy-policy',
      builder: (context, state) => const AuthGate(child: PlaceholderScreen(title: 'Privacy Policy')),
    ),
    GoRoute(
      path: '/terms',
      builder: (context, state) => const AuthGate(child: PlaceholderScreen(title: 'Terms & Condition')),
    ),
    GoRoute(
      path: '/main-post',
      builder: (context, state) => const AuthGate(child: MainPostScreen()),
    ),

    GoRoute(
      path: '/video-post',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return AuthGate(
          child: video_post.VideoPostScreen(
            filePath: (extra['filePath'] as String?) ?? '',
            mediaId: (extra['mediaId'] as String?) ?? '',
            title: (extra['title'] as String?) ?? '',
          ),
        );
      },
    ),
    GoRoute(
      path: '/image-post',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return AuthGate(
          child: ImagePostScreen(
            filePath: (extra['filePath'] as String?) ?? '',
            mediaId: (extra['mediaId'] as String?) ?? '',
            title: (extra['title'] as String?) ?? '',
          ),
        );
      },
    ),
    GoRoute(
      path: '/audio-post',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return AuthGate(
          child: audio_post.AudioPostScreen(
            filePath: (extra['filePath'] as String?) ?? '',
            mediaId: (extra['mediaId'] as String?) ?? '',
            title: (extra['title'] as String?) ?? '',
          ),
        );
      },
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text('Error: Route ${state.uri} not found')),
  ),
);
