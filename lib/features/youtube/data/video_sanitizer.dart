// import 'dart:io';
// import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
// import 'package:path_provider/path_provider.dart';

// /// Ensures the video is playable on all Android/iOS devices (Mali, Adreno, PowerVR)
// class VideoSanitizer {
//   static Future<File> sanitizeVideo(File input) async {
//     final dir = await getTemporaryDirectory();
//     final safePath =
//         '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_safe.mp4';

//     // Universal H.264 + AAC re-encode (yuv420p ensures full GPU compatibility)
//     final cmd = [
//       '-y',
//       '-i', input.path,
//       '-c:v', 'libx264',
//       '-pix_fmt', 'yuv420p',
//       '-preset', 'ultrafast',
//       '-profile:v', 'baseline',
//       '-level', '3.1',
//       '-movflags', '+faststart',
//       '-c:a', 'aac',
//       '-b:a', '128k',
//       safePath,
//     ].join(' ');

//     final session = await FFmpegKit.execute(cmd);
//     final rc = await session.getReturnCode();

//     if (rc?.isValueSuccess() ?? false) {
//       final outFile = File(safePath);
//       if (await outFile.exists() && await outFile.length() > 1000) {
//         return outFile;
//       }
//     }

//     // fallback to original if FFmpeg fails
//     return input;
//   }
// }
