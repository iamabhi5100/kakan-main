abstract class DownloadsEvent {}

class GetDownloadsEvent extends DownloadsEvent {
  final String mediaType;

  GetDownloadsEvent({required this.mediaType});
}