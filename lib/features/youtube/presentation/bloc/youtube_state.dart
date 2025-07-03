// lib/features/youtube/presentation/bloc/youtube_state.dart
import 'package:kakan/features/youtube/domain/entities/video_entity.dart';

abstract class YoutubeState {}

class YoutubeInitial extends YoutubeState {}

class YoutubeLoading extends YoutubeState {}

class YoutubeLoaded extends YoutubeState {
  final List<VideoEntity> videos;
  final bool isSearchResult;

  YoutubeLoaded({required this.videos, required this.isSearchResult});
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