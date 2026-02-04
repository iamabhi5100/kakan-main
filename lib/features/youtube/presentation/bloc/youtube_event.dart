// lib/features/youtube/presentation/bloc/youtube_event.dart
import 'package:equatable/equatable.dart';

abstract class YoutubeEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class SearchVideosEvent extends YoutubeEvent {
  final String query;

  SearchVideosEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class DownloadVideoEvent extends YoutubeEvent {
  final String videoId;
  final String title;
  final bool isAudioOnly;
  final String? preferredQuality;

  DownloadVideoEvent({
    required this.videoId,
    required this.title,
    this.isAudioOnly = false,
    this.preferredQuality,
  });

  @override
  List<Object?> get props => [videoId, title, isAudioOnly, preferredQuality];
}

class FetchHomeVideosEvent extends YoutubeEvent {}
