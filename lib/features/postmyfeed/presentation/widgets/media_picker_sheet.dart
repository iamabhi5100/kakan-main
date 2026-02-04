import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kakan/features/postmyfeed/presentation/video_post_screen.dart';
import 'package:kakan/features/postmyfeed/presentation/widgets/loading_overlay.dart';
import 'package:kakan/features/youtube/presentation/pages/video_editor_screen.dart';
import 'package:kakan/services/ffcap.dart';
import 'package:kakan/services/ffmpeg_exporter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

Future<void> showMediaPickerSheet(
  BuildContext context, {
  required String mediaId,
  required String mediaUrl,
  required String title,
}) async {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.video_file_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Open in editor? You can trim and then post.'),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _openEditor(context,
                          mediaId: mediaId, mediaUrl: mediaUrl, title: title);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

bool _capDumped = false;

Future<void> _openEditor(
  BuildContext context, {
  required String mediaId,
  required String mediaUrl,
  required String title,
}) async {
  try {
    LoadingOverlay.show(context, message: 'Preparing video…');

    // Optional: dump once so you see what encoders the device has
    if (!_capDumped) {
      _capDumped = true;
      await FFCap.dumpCapabilities();
    }

    final tmpDir = await getTemporaryDirectory();
    final localPath =
        p.join(tmpDir.path, 'media_${DateTime.now().millisecondsSinceEpoch}.mp4');

    final req = await HttpClient().getUrl(Uri.parse(mediaUrl));
    final res = await req.close();
    final file = File(localPath);
    final sink = file.openWrite();
    await res.forEach(sink.add);
    await sink.close();

    final controller = VideoPlayerController.file(file);
    await controller.initialize();
    await controller.dispose();

    LoadingOverlay.hide(context);

    final editResult = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => VideoEditorScreen(
          videoPath: localPath,
          videoId: mediaId,
          title: title,
        ),
      ),
    );

    if (editResult == null) return;

    final trimmedPath = editResult['trimmedPath'] as String;
    final cropAspect = editResult['cropAspect'] as CropAspect?;

    LoadingOverlay.show(context, message: 'Finalizing video…');
    final safePath = await FFmpegExporter.export(
      trimmedPath,
      copyIfNoEdits: false,
      crf: 21,
      preset: 'veryfast',
      cropAspect: cropAspect,
    );
    LoadingOverlay.hide(context);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoPostScreen(
          filePath: safePath,
          mediaId: mediaId,
          title: title,
        ),
      ),
    );
  } catch (e) {
    LoadingOverlay.hide(context);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open editor: $e')),
      );
    }
  }
}
