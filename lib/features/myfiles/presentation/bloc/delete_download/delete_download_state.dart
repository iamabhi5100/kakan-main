abstract class DeleteDownloadState {}

class DeleteDownloadInitial extends DeleteDownloadState {}

class DeleteDownloadLoading extends DeleteDownloadState {}

class DeleteDownloadSuccess extends DeleteDownloadState {}

class DeleteDownloadError extends DeleteDownloadState {
  final String message;

  DeleteDownloadError(this.message);
}