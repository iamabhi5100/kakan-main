import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kakan/core/models/otp_page_args.dart';
import 'package:kakan/core/models/onboarding_form_args.dart';
import 'package:kakan/core/utils/session_manager.dart';
import 'package:kakan/features/chat/presentation/pages/chat_lists_screen.dart';
import 'package:kakan/features/debug/presentation/debug_settings_screen.dart';
import 'package:kakan/features/followsuggestions/presentation/followsuggestions_screen.dart';
import 'package:kakan/features/home/home_screen.dart';
import 'package:kakan/features/login/data/datasources/remote_data_source.dart';
import 'package:kakan/features/login/presentation/pages/login_page.dart';
import 'package:kakan/features/login/presentation/pages/otp_page.dart';
import 'package:kakan/features/login/presentation/widgets/onboarding_form.dart';
import 'package:kakan/features/login/presentation/widgets/successfull_login.dart';
import 'package:kakan/features/myfiles/presentation/myfiles_screen.dart';
import 'package:kakan/features/onboarding/presentation/onboarding_screen.dart';
import 'package:kakan/features/postmyfeed/presentation/audio_post_screen.dart';
import 'package:kakan/features/postmyfeed/presentation/main_post_screen.dart';
import 'package:kakan/features/postmyfeed/presentation/video_post_screen.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_detail/profiledetails_bloc.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_post_list/profile_posts_bloc.dart';
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
import 'package:kakan/features/youtube/presentation/youtube_dashboard_screen.dart';
import 'package:kakan/injection_container.dart' as di;

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
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
      redirect: (context, state) async {
        final sessionManager = di.sl<SessionManager>();
        final token = await sessionManager.getAccessToken();
        if (token != null) {
          return '/home';
        }
        return '/login';
      },
    ),
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
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
      redirect: (context, state) async {
        final sessionManager = di.sl<SessionManager>();
        final token = await sessionManager.getAccessToken();
        if (token == null) {
          return '/login';
        }
        return null;
      },
    ),
    GoRoute(
      path: '/youtube-dashboard',
      builder: (context, state) => BlocProvider(
        create: (_) => di.sl<YoutubeBloc>()..add(FetchHomeVideosEvent()),
        child: const YoutubeDashboardScreen(),
      ),
      redirect: (context, state) async {
        final sessionManager = di.sl<SessionManager>();
        final token = await sessionManager.getAccessToken();
        if (token == null) {
          return '/login';
        }
        return null;
      },
    ),
    GoRoute(
      path: '/video-detail',
      builder: (context, state) {
        final video = state.extra as VideoEntity;
        return BlocProvider.value(
          value: di.sl<YoutubeBloc>(),
          child: VideoDetailScreen(video: video),
        );
      },
    ),
    GoRoute(
      path: '/video-editor',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        final filePath = extra['filePath'] as String;
        final videoId = extra['videoId'] as String;
        final title = extra['title'] as String;
        return VideoEditorScreen(
          videoPath: filePath,
          videoId: videoId,
          title: title,
        );
      },
    ),
    GoRoute(
      path: '/audio-editor',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        final filePath = extra['filePath'] as String;
        final videoId = extra['videoId'] as String;
        final title = extra['title'] as String;
        return AudioEditorPage(
          audioPath: filePath,
          videoId: videoId,
          title: title,
        );
      },
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => di.sl<ProfilePostsBloc>()),
          BlocProvider(create: (_) => di.sl<ProfiledetailsBloc>()),
        ],
        child: const ProfileScreen(),
      ),
    ),
    GoRoute(
      path: '/my-files',
      builder: (context, state) => const MyfilesScreen(),
      redirect: (context, state) async {
        final sessionManager = di.sl<SessionManager>();
        final token = await sessionManager.getAccessToken();
        if (token == null) {
          return '/login';
        }
        return null;
      },
    ),
    GoRoute(
      path: '/chat',
      builder: (context, state) => const ChatListsScreen(),
      redirect: (context, state) async {
        final sessionManager = di.sl<SessionManager>();
        final token = await sessionManager.getAccessToken();
        if (token == null) {
          return '/login';
        }
        return null;
      },
    ),
    GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
    GoRoute(
      path: '/reels',
      builder: (context, state) => const ReelsPage(),
      redirect: (context, state) async {
        final sessionManager = di.sl<SessionManager>();
        final token = await sessionManager.getAccessToken();
        if (token == null) {
          return '/login';
        }
        return null;
      },
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const PlaceholderScreen(title: 'Notifications'),
    ),
    GoRoute(
      path: '/faqs',
      builder: (context, state) => const PlaceholderScreen(title: 'FAQs'),
    ),
    GoRoute(
      path: '/contact-details',
      builder: (context, state) => const PlaceholderScreen(title: 'Contact Details'),
    ),
    GoRoute(
      path: '/supports',
      builder: (context, state) => const PlaceholderScreen(title: 'Supports'),
    ),
    GoRoute(
      path: '/about-us',
      builder: (context, state) => const PlaceholderScreen(title: 'About Us'),
    ),
    GoRoute(
      path: '/privacy-policy',
      builder: (context, state) => const PlaceholderScreen(title: 'Privacy Policy'),
    ),
    GoRoute(
      path: '/terms',
      builder: (context, state) => const PlaceholderScreen(title: 'Terms & Condition'),
    ),
    GoRoute(
      path: '/main-post',
      builder: (context, state) => const MainPostScreen(),
      redirect: (context, state) async {
        final sessionManager = di.sl<SessionManager>();
        final token = await sessionManager.getAccessToken();
        if (token == null) {
          return '/login';
        }
        return null;
      },
    ),
    GoRoute(
      path: '/video-post',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return VideoPostScreen(filePath: extra?['filePath'] as String?);
      },
      redirect: (context, state) async {
        final sessionManager = di.sl<SessionManager>();
        final token = await sessionManager.getAccessToken();
        if (token == null) {
          return '/login';
        }
        return null;
      },
    ),
    GoRoute(
      path: '/audio-post',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return AudioPostScreen(filePath: extra?['filePath'] as String?);
      },
      redirect: (context, state) async {
        final sessionManager = di.sl<SessionManager>();
        final token = await sessionManager.getAccessToken();
        if (token == null) {
          return '/login';
        }
        return null;
      },
    ),
    GoRoute(
      path: '/debug-settings',
      builder: (context, state) => const DebugSettingsScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text('Error: Route ${state.uri} not found')),
  ),
);