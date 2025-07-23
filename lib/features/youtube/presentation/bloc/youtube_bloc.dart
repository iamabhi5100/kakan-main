import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';
import 'package:kakan/features/youtube/domain/usecases/search_videos.dart';
import 'package:kakan/features/youtube/domain/usecases/download_video.dart';
import 'package:kakan/features/youtube/presentation/bloc/youtube_event.dart';
import 'package:kakan/features/youtube/presentation/bloc/youtube_state.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/error/failures.dart';

class YoutubeBloc extends Bloc<YoutubeEvent, YoutubeState> {
  final SearchVideos searchVideos;
  final DownloadVideo downloadVideo;

  YoutubeBloc({
    required this.searchVideos,
    required this.downloadVideo,
  }) : super(YoutubeInitial()) {
    on<SearchVideosEvent>(
      _onSearchVideos,
      transformer: (events, mapper) =>
          events.debounceTime(const Duration(milliseconds: 500)).asyncExpand(mapper),
    );
    on<FetchHomeVideosEvent>(
      _onFetchHomeVideos,
      transformer: (events, mapper) =>
          events.debounceTime(const Duration(milliseconds: 500)).asyncExpand(mapper),
    );
    on<DownloadVideoEvent>(
      _onDownloadVideo,
      transformer: (events, mapper) =>
          events.debounceTime(const Duration(milliseconds: 500)).asyncExpand(mapper),
    );
  }

  Future<void> _onSearchVideos(
      SearchVideosEvent event, Emitter<YoutubeState> emit) async {
    emit(YoutubeLoading());
    final result = await searchVideos(event.query);
    result.fold(
      (failure) {
        final message = _extractMessage(failure);
        emit(YoutubeError(message));
      },
      (videos) => emit(YoutubeLoaded(videos: videos, isSearchResult: true)),
    );
  }

  Future<void> _onFetchHomeVideos(
      FetchHomeVideosEvent event, Emitter<YoutubeState> emit) async {
    emit(YoutubeLoading());
    final result = await searchVideos('trending');
    result.fold(
      (failure) {
        final message = _extractMessage(failure);
        emit(YoutubeError(message));
      },
      (videos) => emit(YoutubeLoaded(videos: videos, isSearchResult: false)),
    );
  }

  Future<void> _onDownloadVideo(
      DownloadVideoEvent event, Emitter<YoutubeState> emit) async {
    emit(YoutubeDownloading(progress: 0.0));
    double lastProgress = 0.0;

    final result = await downloadVideo(
      DownloadVideoParams(
        videoId: event.videoId,
        title: event.title,
        isAudioOnly: event.isAudioOnly,
        preferredQuality: event.preferredQuality,
        progressCallback: (progress) {
          if ((progress - lastProgress) > 0.05) {
            lastProgress = progress;
            emit(YoutubeDownloading(progress: progress));
          }
        },
      ),
    );

    result.fold(
      (failure) {
        final message = _extractMessage(failure);
        emit(YoutubeError(message));
      },
      (filePath) => emit(YoutubeDownloaded(
        filePath: filePath,
        isAudioOnly: event.isAudioOnly,
        videoId: event.videoId,
        title: event.title,
      )),
    );
  }

  /// Helper to unwrap the message from a Failure.
  String _extractMessage(Failure failure) {
    if (failure is ServerFailure && failure.exception is ServerException) {
      return (failure.exception as ServerException).message ?? 'Unknown server error';
    }
    return failure.toString();
  }
}
