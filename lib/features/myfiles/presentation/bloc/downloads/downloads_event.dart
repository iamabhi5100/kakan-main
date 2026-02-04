abstract class DownloadsEvent {}

class GetDownloadsEvent extends DownloadsEvent {
  final String mediaType;
  final String? search;

  GetDownloadsEvent({required this.mediaType, this.search});
}
