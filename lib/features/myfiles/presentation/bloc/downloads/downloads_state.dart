import 'package:kakan/features/myfiles/domain/entities/download_entity.dart';

abstract class DownloadsState {}

class DownloadsInitial extends DownloadsState {}

class DownloadsLoading extends DownloadsState {}

class DownloadsLoaded extends DownloadsState {
  final List<DownloadEntity> downloads;

  DownloadsLoaded(this.downloads);
}

class DownloadsError extends DownloadsState {
  final String message;

  DownloadsError(this.message);
}