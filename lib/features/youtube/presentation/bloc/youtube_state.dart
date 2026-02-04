// lib/features/youtube/presentation/bloc/youtube_state.dart
import 'package:kakan/features/youtube/model/youtube_home_model.dart';

abstract class YoutubeState {}

class YoutubeInitial extends YoutubeState {}

class YoutubeLoading extends YoutubeState {}

class YoutubeLoaded extends YoutubeState {
  final List<Content> contents;
  final bool isSearchResult;

  YoutubeLoaded({required this.contents, required this.isSearchResult});
}

class YoutubeDownloading extends YoutubeState {
  final double progress;

  YoutubeDownloading({required this.progress});
}

class YoutubeDownloaded extends YoutubeState {
  final String filePath;
  final bool isAudioOnly;
  final String videoId;
  final String title;

  YoutubeDownloaded({
    required this.filePath,
    required this.isAudioOnly,
    required this.videoId,
    required this.title,
  });
}

class YoutubeError extends YoutubeState {
  final String message;

  YoutubeError(this.message);
}
