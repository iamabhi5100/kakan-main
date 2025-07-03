// lib/features/youtube/presentation/bloc/youtube_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/features/youtube/domain/usecases/search_videos.dart';
import 'package:kakan/features/youtube/domain/usecases/download_video.dart';
import 'package:kakan/features/youtube/presentation/bloc/youtube_event.dart';
import 'package:kakan/features/youtube/presentation/bloc/youtube_state.dart';
import 'package:rxdart/rxdart.dart';

class YoutubeBloc extends Bloc<YoutubeEvent, YoutubeState> {
  final SearchVideos searchVideos;
  final DownloadVideo downloadVideo;

  YoutubeBloc({
    required this.searchVideos,
    required this.downloadVideo,
  }) : super(YoutubeInitial()) {
    on<SearchVideosEvent>(
      _onSearchVideos,
      transformer: (events, mapper) => events.debounceTime(const Duration(milliseconds: 500)).asyncExpand(mapper),
    );
    on<DownloadVideoEvent>(
      _onDownloadVideo,
      transformer: (events, mapper) => events.debounceTime(const Duration(milliseconds: 500)).asyncExpand(mapper),
    );
    on<FetchHomeVideosEvent>(
      _onFetchHomeVideos,
      transformer: (events, mapper) => events.debounceTime(const Duration(milliseconds: 500)).asyncExpand(mapper),
    );
  }

  Future<void> _onSearchVideos(SearchVideosEvent event, Emitter<YoutubeState> emit) async {
    print('YoutubeBloc: Handling SearchVideosEvent with query: ${event.query}');
    emit(YoutubeLoading());
    final result = await searchVideos(event.query);
    result.fold(
      (failure) {
        print('YoutubeBloc: Search failed - $failure');
        String message = failure.toString();
        if (message.contains('Too Many Requests')) {
          message = 'Rate limit exceeded. Please try again later.';
        }
        emit(YoutubeError(message));
      },
      (videos) {
        print('YoutubeBloc: Search successful, found ${videos.length} videos');
        emit(YoutubeLoaded(videos: videos, isSearchResult: true));
      },
    );
  }

  Future<void> _onDownloadVideo(DownloadVideoEvent event, Emitter<YoutubeState> emit) async {
    print('YoutubeBloc: Handling DownloadVideoEvent for videoId: ${event.videoId}, title: ${event.title}, isAudioOnly: ${event.isAudioOnly}, preferredQuality: ${event.preferredQuality}');
    double lastProgress = 0.0;
    emit(YoutubeDownloading(progress: 0.0));

    final result = await downloadVideo(
      DownloadVideoParams(
        videoId: event.videoId,
        title: event.title,
        isAudioOnly: event.isAudioOnly,
        preferredQuality: event.preferredQuality,
        progressCallback: (progress) {
          if (progress - lastProgress > 0.05) {
            print('YoutubeBloc: Progress update - ${progress * 100}%');
            emit(YoutubeDownloading(progress: progress));
            lastProgress = progress;
          }
        },
      ),
    );

    result.fold(
      (failure) {
        print('YoutubeBloc: Download failed - $failure');
        String message = failure.toString();
        if (message.contains('Too Many Requests')) {
          message = 'Rate limit exceeded. Please try again later.';
        } else if (message.contains('Video unavailable') || message.contains('restricted')) {
          message = 'This video is unavailable, private, or restricted. Try a different quality or another video.';
        } else if (message.contains('Invalid video ID')) {
          message = 'Invalid video ID. Please check the video link.';
        }
        emit(YoutubeError(message));
      },
      (filePath) {
        print('YoutubeBloc: Download successful, filePath: $filePath');
        emit(YoutubeDownloaded(
          filePath: filePath,
          isAudioOnly: event.isAudioOnly,
          videoId: event.videoId,
          title: event.title,
        ));
      },
    );
  }

  Future<void> _onFetchHomeVideos(FetchHomeVideosEvent event, Emitter<YoutubeState> emit) async {
    print('YoutubeBloc: Handling FetchHomeVideosEvent');
    emit(YoutubeLoading());
    final result = await searchVideos('trending');
    result.fold(
      (failure) {
        print('YoutubeBloc: Fetch home videos failed - $failure');
        String message = failure.toString();
        if (message.contains('Too Many Requests')) {
          message = 'Rate limit exceeded. Please try again later.';
        }
        emit(YoutubeError(message));
      },
      (videos) {
        print('YoutubeBloc: Fetch home videos successful, found ${videos.length} videos');
        emit(YoutubeLoaded(videos: videos, isSearchResult: false));
      },
    );
  }
}