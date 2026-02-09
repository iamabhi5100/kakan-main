import 'package:flutter/material.dart';
import 'package:kakan/config/theme.dart';
import 'package:kakan/features/myfiles/domain/entities/download_entity.dart';
import 'package:kakan/features/myfiles/presentation/widgets/audio_post.dart';

/// Full-screen page that shows a single My Files audio using [AudioPost].
class MyFilesAudioFeedPage extends StatelessWidget {
  final DownloadEntity download;

  const MyFilesAudioFeedPage({super.key, required this.download});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F8),
      appBar: AppBar(
        title: Text(
          download.title ?? 'Audio',
          style: appTheme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: appTheme.primaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: AudioPost(download: download),
      ),
    );
  }
}
