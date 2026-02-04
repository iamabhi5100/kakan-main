// lib/injection_container.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get_it/get_it.dart';

import 'package:kakan/core/network/api_service.dart';
import 'package:kakan/core/network/network_info.dart';
import 'package:kakan/core/utils/session_manager.dart';

// Chat
import 'package:kakan/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:kakan/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:kakan/features/chat/domain/repositories/chat_repository.dart';
import 'package:kakan/features/chat/domain/usecases/create_chat.dart';
import 'package:kakan/features/chat/domain/usecases/create_group_chat.dart';
import 'package:kakan/features/chat/domain/usecases/delete_group_chat.dart';
import 'package:kakan/features/chat/domain/usecases/delete_message.dart';
import 'package:kakan/features/chat/domain/usecases/get_following_users.dart';
import 'package:kakan/features/chat/domain/usecases/get_inbox.dart';
import 'package:kakan/features/chat/domain/usecases/get_message_history.dart';
import 'package:kakan/features/chat/domain/usecases/send_group_message.dart';
import 'package:kakan/features/chat/domain/usecases/send_message.dart' as chat;
import 'package:kakan/features/chat/presentation/bloc/chat_list_bloc/chat_bloc.dart';

// Follow Suggestions
import 'package:kakan/features/followsuggestions/data/datasources/suggestion_remote_data_source.dart'
    as follow_suggestions;
import 'package:kakan/features/followsuggestions/data/repositories/suggestion_repository_impl.dart';
import 'package:kakan/features/followsuggestions/domain/repositories/suggestion_repository.dart';
import 'package:kakan/features/followsuggestions/domain/usecases/follow_user.dart';
import 'package:kakan/features/followsuggestions/domain/usecases/get_follow_suggestions.dart';
import 'package:kakan/features/followsuggestions/domain/usecases/unfollow_user.dart';
import 'package:kakan/features/followsuggestions/presentation/bloc/suggestion_bloc.dart';

// Home / Feed / Share
import 'package:kakan/features/home/data/datasources/feed_remote_data_source.dart';
import 'package:kakan/features/home/data/datasources/share_remote_data_source.dart';
import 'package:kakan/features/home/data/repositories/feed_repository_impl.dart';
import 'package:kakan/features/home/model/repositories/feed_repository.dart';
import 'package:kakan/features/home/model/repositories/share_repository.dart';
import 'package:kakan/features/home/model/usecases/get_feeds.dart';
import 'package:kakan/features/home/model/usecases/get_users_to_share.dart';
import 'package:kakan/features/home/model/usecases/send_share_message.dart';
import 'package:kakan/features/home/model/usecases/add_comment.dart';
import 'package:kakan/features/home/model/usecases/get_comments.dart';
import 'package:kakan/features/home/model/usecases/delete_comment.dart';
import 'package:kakan/features/home/presentation/bloc/feed_bloc/feed_bloc.dart';

// Login
import 'package:kakan/features/login/data/datasources/remote_data_source.dart'
    as login;
import 'package:kakan/features/login/data/repositories/auth_repository_impl.dart';
import 'package:kakan/features/login/domain/repositories/auth_repository.dart';
import 'package:kakan/features/login/domain/usecases/create_profile.dart';
import 'package:kakan/features/login/domain/usecases/request_otp.dart';
import 'package:kakan/features/login/domain/usecases/verify_otp.dart';
import 'package:kakan/features/login/presentation/bloc/otp_bloc.dart';

// My Files (Downloads)
import 'package:kakan/features/myfiles/data/datasources/delete_download_remote_data_source.dart';
import 'package:kakan/features/myfiles/data/datasources/downloads_remote_data_source.dart';
import 'package:kakan/features/myfiles/data/repositories/delete_download_repository_impl.dart';
import 'package:kakan/features/myfiles/data/repositories/downloads_repository_impl.dart';
import 'package:kakan/features/myfiles/domain/repositories/delete_download_repository.dart';
import 'package:kakan/features/myfiles/domain/repositories/downloads_repository.dart';
import 'package:kakan/features/myfiles/domain/usecases/delete_download.dart';
import 'package:kakan/features/myfiles/domain/usecases/get_downloads.dart';
import 'package:kakan/features/myfiles/presentation/bloc/delete_download/delete_download_bloc.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_bloc.dart';

// Posting
import 'package:kakan/features/postmyfeed/data/datasources/post_remote_data_source.dart';
import 'package:kakan/features/postmyfeed/data/repositories/post_repository_impl.dart';
import 'package:kakan/features/postmyfeed/domain/repositories/post_repository.dart';
import 'package:kakan/features/postmyfeed/domain/usecases/create_post.dart';
import 'package:kakan/features/postmyfeed/presentation/bloc/post_bloc/post_bloc.dart';

// Profile
import 'package:kakan/features/profile/data/datasources/delete_post_remote_data_source.dart';
import 'package:kakan/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:kakan/features/profile/data/datasources/profile_submit_remote_data_source.dart';
import 'package:kakan/features/profile/data/datasources/profiledetails_remote_data_source.dart';
import 'package:kakan/features/profile/data/datasources/profileimage_remote_data_source.dart';
import 'package:kakan/features/profile/data/datasources/profile_posts_remote_data_source.dart';
import 'package:kakan/features/profile/data/repositories/delete_post_repository_impl.dart';
import 'package:kakan/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:kakan/features/profile/data/repositories/profile_submit_repository_impl.dart';
import 'package:kakan/features/profile/data/repositories/profiledetails_repository_impl.dart';
import 'package:kakan/features/profile/data/repositories/profileimage_repository_impl.dart';
import 'package:kakan/features/profile/data/repositories/profile_posts_repository_impl.dart';
import 'package:kakan/features/profile/domain/repositories/delete_post_repository.dart';
import 'package:kakan/features/profile/domain/repositories/profile_repository.dart';
import 'package:kakan/features/profile/domain/repositories/profile_submit_repository.dart';
import 'package:kakan/features/profile/domain/repositories/profiledetails_repository.dart';
import 'package:kakan/features/profile/domain/repositories/profileimage_repository.dart';
import 'package:kakan/features/profile/domain/repositories/profile_posts_repository.dart';
import 'package:kakan/features/profile/domain/usecases/delete_post.dart';
import 'package:kakan/features/profile/domain/usecases/get_profiledetails.dart';
import 'package:kakan/features/profile/domain/usecases/submit_profile.dart';
import 'package:kakan/features/profile/domain/usecases/update_profile.dart';
import 'package:kakan/features/profile/domain/usecases/upload_profileimage.dart';
import 'package:kakan/features/profile/domain/usecases/get_profile_posts.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_detail/profiledetails_bloc.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_image/profileimage_bloc.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_post_delete/delete_post_bloc.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_submit/profile_submit_bloc.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_post_list/profile_posts_bloc.dart';

// Reels
import 'package:kakan/features/reels/data/datasources/reels_remote_data_source.dart';
import 'package:kakan/features/reels/data/repositories/reels_repository_impl.dart';
import 'package:kakan/features/reels/domain/repositories/reels_repository.dart';
import 'package:kakan/features/reels/domain/usecases/delete_reel.dart';
import 'package:kakan/features/reels/domain/usecases/get_reels.dart';
import 'package:kakan/features/reels/domain/usecases/get_share_targets.dart';
import 'package:kakan/features/reels/domain/usecases/like_reel.dart';
import 'package:kakan/features/reels/domain/usecases/repost_reel.dart';
import 'package:kakan/features/reels/domain/usecases/share_reel.dart';
import 'package:kakan/features/reels/presentation/bloc/reel_lists/reels_bloc.dart';

// Search
import 'package:kakan/features/search/data/datasources/search_remote_datasource.dart';
import 'package:kakan/features/search/data/repositories/search_repository_impl.dart';
import 'package:kakan/features/search/domain/repositories/search_repository.dart';
import 'package:kakan/features/search/domain/usecases/search_people.dart';
import 'package:kakan/features/search/domain/usecases/search_songs.dart';
import 'package:kakan/features/search/domain/usecases/search_videos.dart';
import 'package:kakan/features/search/presentation/bloc/combined_search/combined_search_bloc.dart';

// YouTube
import 'package:kakan/features/youtube/data/api_service.dart';
import 'package:kakan/features/youtube/data/youtube_service.dart';
import 'package:kakan/features/youtube/domain/repositories/youtube_repository.dart';
import 'package:kakan/features/youtube/data/youtube_repository_impl.dart';
import 'package:kakan/features/youtube/domain/usecases/download_video.dart';
import 'package:kakan/features/youtube/domain/usecases/fetch_home_videos.dart';
import 'package:kakan/features/youtube/domain/usecases/search_videos.dart' as youtube;
import 'package:kakan/features/youtube/presentation/bloc/youtube_bloc.dart';

final sl = GetIt.instance;

void init() {
  print('DEBUG: Initializing GetIt dependencies');

  // Core services
  sl.registerLazySingleton(() => Dio());
  sl.registerLazySingleton(() => SessionManager());
  sl.registerLazySingleton(() => Connectivity());
  sl.registerLazySingleton(() => DefaultCacheManager());
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));
  sl.registerLazySingleton(() => ApiService(sessionManager: sl()));

  // Share Feature
  sl.registerLazySingleton<ShareRemoteDataSource>(() => ShareRemoteDataSourceImpl(
        apiService: sl(),
        cacheManager: sl(),
      ));
  sl.registerLazySingleton<ShareRepository>(() => ShareRepositoryImpl(remoteDataSource: sl()));
  sl.registerLazySingleton(() => GetUsersToShare(sl()));
  sl.registerLazySingleton(() => SendShareMessage(sl()));

  // Login Feature
  sl.registerFactory(() => OtpBloc(
        requestOtp: sl(),
        verifyOtp: sl(),
        createProfile: sl(),
        sessionManager: sl(),
      ));
  sl.registerLazySingleton(() => RequestOtp(sl()));
  sl.registerLazySingleton(() => VerifyOtp(sl()));
  sl.registerLazySingleton(() => CreateProfile(sl()));
  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(
        remoteDataSource: sl<login.RemoteDataSource>(),
      ));
  sl.registerLazySingleton<login.RemoteDataSource>(() => login.RemoteDataSourceImpl(
        apiService: sl(),
        sessionManager: sl(),
        networkInfo: sl(),
      ));

  // Follow Suggestions Feature
  sl.registerLazySingleton<follow_suggestions.RemoteDataSource>(
      () => follow_suggestions.RemoteDataSourceImpl(
            apiService: sl(),
            sessionManager: sl(),
            networkInfo: sl(),
          ));
  sl.registerLazySingleton<SuggestionRepository>(
      () => SuggestionRepositoryImpl(remoteDataSource: sl<follow_suggestions.RemoteDataSource>()));
  sl.registerLazySingleton(() => GetFollowSuggestions(sl()));
  sl.registerLazySingleton(() => FollowUser(sl()));
  sl.registerLazySingleton(() => UnfollowUser(sl()));
  sl.registerFactory(() => SuggestionBloc(
        getFollowSuggestions: sl(),
        followUser: sl(),
        unfollowUser: sl(),
      ));

  // Profile Feature
  sl.registerLazySingleton(() => UpdateProfile(sl()));
  sl.registerLazySingleton<ProfileRepository>(() => ProfileRepositoryImpl(
        remoteDataSource: sl<ProfileRemoteDataSource>(),
      ));
  sl.registerLazySingleton<ProfileRemoteDataSource>(() => ProfileRemoteDataSourceImpl(apiService: sl()));

  // Profile Submit Feature
  sl.registerFactory(() => ProfileSubmitBloc(submitProfile: sl()));
  sl.registerLazySingleton(() => SubmitProfile(sl()));
  sl.registerLazySingleton<ProfileSubmitRepository>(() => ProfileSubmitRepositoryImpl(
        remoteDataSource: sl<ProfileSubmitRemoteDataSource>(),
        networkInfo: sl(),
      ));
  sl.registerLazySingleton<ProfileSubmitRemoteDataSource>(() => ProfileSubmitRemoteDataSourceImpl(apiService: sl()));

  // Profile Image Feature
  sl.registerFactory(() => ProfileimageBloc(uploadProfileimage: sl()));
  sl.registerLazySingleton(() => UploadProfileimage(sl()));
  sl.registerLazySingleton<ProfileimageRepository>(() => ProfileimageRepositoryImpl(
        remoteDataSource: sl<ProfileimageRemoteDataSource>(),
        networkInfo: sl(),
      ));
  sl.registerLazySingleton<ProfileimageRemoteDataSource>(() => ProfileimageRemoteDataSourceImpl(apiService: sl()));

  // Profile Details Feature
  sl.registerFactory(() => ProfiledetailsBloc(getProfiledetails: sl()));
  sl.registerLazySingleton(() => GetProfiledetails(sl()));
  sl.registerLazySingleton<ProfiledetailsRepository>(() => ProfiledetailsRepositoryImpl(
        remoteDataSource: sl<ProfiledetailsRemoteDataSource>(),
        networkInfo: sl(),
      ));
  sl.registerLazySingleton<ProfiledetailsRemoteDataSource>(() => ProfiledetailsRemoteDataSourceImpl(apiService: sl()));

  // Downloads Feature
  sl.registerFactory(() => DownloadsBloc(getDownloads: sl()));
  sl.registerLazySingleton(() => GetDownloads(sl()));
  sl.registerLazySingleton<DownloadsRepository>(() => DownloadsRepositoryImpl(
        remoteDataSource: sl<DownloadsRemoteDataSource>(),
        networkInfo: sl(),
      ));
  sl.registerLazySingleton<DownloadsRemoteDataSource>(() => DownloadsRemoteDataSourceImpl(apiService: sl()));

  // Delete Download Feature
  sl.registerFactory(() => DeleteDownloadBloc(deleteDownload: sl()));
  sl.registerLazySingleton(() => DeleteDownload(sl()));
  sl.registerLazySingleton<DeleteDownloadRepository>(() => DeleteDownloadRepositoryImpl(
        remoteDataSource: sl<DeleteDownloadRemoteDataSource>(),
        networkInfo: sl(),
      ));
  sl.registerLazySingleton<DeleteDownloadRemoteDataSource>(() => DeleteDownloadRemoteDataSourceImpl(apiService: sl()));

  // Chat Feature
  sl.registerFactory(() => ChatBloc(
        getFollowingUsers: sl(),
        createChat: sl(),
        createGroupChat: sl(),
        sendMessage: sl<chat.SendMessage>(),
        sendGroupMessage: sl(),
        getInbox: sl(),
        getMessageHistory: sl(),
        deleteMessage: sl(),
        deleteGroupChat: sl(),
      ));
  sl.registerLazySingleton(() => GetFollowingUsers(sl()));
  sl.registerLazySingleton(() => CreateChat(sl()));
  sl.registerLazySingleton(() => CreateGroupChat(sl()));
  sl.registerLazySingleton(() => chat.SendMessage(sl()));
  sl.registerLazySingleton(() => SendGroupMessage(sl()));
  sl.registerLazySingleton(() => GetInbox(sl()));
  sl.registerLazySingleton(() => GetMessageHistory(sl()));
  sl.registerLazySingleton(() => DeleteMessage(sl()));
  sl.registerLazySingleton(() => DeleteGroupChat(sl()));
  sl.registerLazySingleton<ChatRepository>(() => ChatRepositoryImpl(
        remoteDataSource: sl<ChatRemoteDataSource>(),
        networkInfo: sl(),
      ));
  sl.registerLazySingleton<ChatRemoteDataSource>(
      () => ChatRemoteDataSourceImpl(apiService: sl(), sessionManager: sl()));

  // Post Feature
  sl.registerFactory(() => PostBloc(createPost: sl()));
  sl.registerLazySingleton(() => CreatePost(sl()));
  sl.registerLazySingleton<PostRepository>(() => PostRepositoryImpl(
        remoteDataSource: sl<PostRemoteDataSource>(),
        networkInfo: sl(),
      ));
  sl.registerLazySingleton<PostRemoteDataSource>(() => PostRemoteDataSourceImpl(apiService: sl()));

  // Profile Posts Feature
  sl.registerFactory(() => ProfilePostsBloc(getProfilePosts: sl()));
  sl.registerLazySingleton(() => GetProfilePosts(sl()));
  sl.registerLazySingleton<ProfilePostsRepository>(() => ProfilePostsRepositoryImpl(
        remoteDataSource: sl<ProfilePostsRemoteDataSource>(),
        networkInfo: sl(),
      ));
  sl.registerLazySingleton<ProfilePostsRemoteDataSource>(() => ProfilePostsRemoteDataSourceImpl(apiService: sl()));

  // Delete Post Feature
  sl.registerFactory(() => DeletePostBloc(deletePost: sl()));
  sl.registerLazySingleton(() => DeletePost(sl()));
  sl.registerLazySingleton<DeletePostRepository>(() => DeletePostRepositoryImpl(
        remoteDataSource: sl<DeletePostRemoteDataSource>(),
        networkInfo: sl(),
      ));
  sl.registerLazySingleton<DeletePostRemoteDataSource>(
      () => DeletePostRemoteDataSourceImpl(apiService: sl()));

  // Feed Feature
  sl.registerFactory(() => FeedBloc(
        getFeeds: sl(),
        repository: sl(),
        addComment: sl(),
        getComments: sl(),
        deleteComment: sl(),
      ));
  sl.registerLazySingleton(() => GetFeeds(sl()));
  sl.registerLazySingleton<FeedRepository>(() => FeedRepositoryImpl(
        remoteDataSource: sl<FeedRemoteDataSource>(),
        networkInfo: sl(),
      ));
  sl.registerLazySingleton<FeedRemoteDataSource>(() => FeedRemoteDataSourceImpl(
        apiService: sl(),
        cacheManager: sl(),
      ));
  sl.registerLazySingleton(() => AddComment(sl()));
  sl.registerLazySingleton(() => GetComments(sl()));
  sl.registerLazySingleton(() => DeleteComment(sl()));

  // Search Feature
  sl.registerLazySingleton(() => SearchPeople(sl()));
  sl.registerLazySingleton(() => SearchSongs(sl()));
  sl.registerLazySingleton(() => SearchVideos(sl()));
  sl.registerFactory<CombinedSearchBloc>(() => CombinedSearchBloc(
        people: sl<SearchPeople>(),
        songs: sl<SearchSongs>(),
        videos: sl<SearchVideos>(),
      ));
  sl.registerLazySingleton<SearchRepository>(() => SearchRepositoryImpl(sl()));
  sl.registerLazySingleton<SearchRemoteDataSource>(() => SearchRemoteDataSourceImpl(sl()));

  // YouTube Feature (✅ fixed)
  sl.registerLazySingleton(() => YoutubeService(cacheManager: sl()));
  sl.registerLazySingleton(() => YoutubeApiService(dio: sl(), sessionManager: sl()));

  sl.registerLazySingleton<YoutubeRepository>(() => YoutubeRepositoryImpl(
        api: sl<YoutubeService>(),
        cacheManager: sl<DefaultCacheManager>(),
      ));

  sl.registerLazySingleton(() => youtube.SearchVideos(sl()));
  sl.registerLazySingleton(() => FetchHomeVideos(sl()));
  sl.registerLazySingleton(() => DownloadVideo(sl()));
  sl.registerFactory(() => YoutubeBloc(
        searchVideos: sl<youtube.SearchVideos>(),
        fetchHomeVideos: sl<FetchHomeVideos>(),
        downloadVideo: sl<DownloadVideo>(),
      ));

  // Reels Feature
  sl.registerLazySingleton<ReelsRepository>(() => ReelsRepositoryImpl(
        remoteDataSource: sl<ReelsRemoteDataSource>(),
        networkInfo: sl(),
      ));
  sl.registerLazySingleton<ReelsRemoteDataSource>(() => ReelsRemoteDataSourceImpl(
        apiService: sl(),
        cacheManager: sl(),
      ));
  sl.registerLazySingleton(() => GetReels(sl()));
  sl.registerLazySingleton(() => LikeReel(sl()));
  sl.registerLazySingleton(() => RepostReel(sl()));
  sl.registerLazySingleton(() => ShareReel(sl()));
  sl.registerLazySingleton(() => DeleteReel(sl()));
  sl.registerLazySingleton(() => GetShareTargets(sl()));
  sl.registerFactory(() => ReelsBloc(
        getReels: sl(),
        likeReel: sl(),
        repostReel: sl(),
        shareReel: sl(),
        deleteReel: sl(),
        getShareTargets: sl(),
        getComments: sl(),
        addComment: sl(),
        deleteComment: sl(),
      ));

  // Debug probes
  print('DEBUG: Registered ReelsRepository: ${sl.isRegistered<ReelsRepository>()}');
  print('DEBUG: Registered ReelsRemoteDataSource: ${sl.isRegistered<ReelsRemoteDataSource>()}');
  print('DEBUG: Registered GetReels: ${sl.isRegistered<GetReels>()}');
  print('DEBUG: Registered LikeReel: ${sl.isRegistered<LikeReel>()}');
  print('DEBUG: Registered RepostReel: ${sl.isRegistered<RepostReel>()}');
  print('DEBUG: Registered ReelsBloc: ${sl.isRegistered<ReelsBloc>()}');
  print('DEBUG: Registered FeedRemoteDataSource: ${sl.isRegistered<FeedRemoteDataSource>()}');
  print('DEBUG: Registered ShareRepository: ${sl.isRegistered<ShareRepository>()}');
  print('DEBUG: Registered AddComment: ${sl.isRegistered<AddComment>()}');
  print('DEBUG: Registered GetComments: ${sl.isRegistered<GetComments>()}');
  print('DEBUG: Registered DeleteComment: ${sl.isRegistered<DeleteComment>()}');
}
