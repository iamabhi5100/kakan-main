import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/core/error/failures.dart';
import 'package:kakan/features/youtube/data/api_service.dart';
import 'package:kakan/features/youtube/data/youtube_service.dart';
import 'package:kakan/features/youtube/domain/entities/video_entity.dart';
import 'package:kakan/features/youtube/domain/repositories/youtube_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YoutubeRepositoryImpl implements YoutubeRepository {
  final YoutubeService youtubeService;
  final YoutubeApiService apiService;

  static const _maxMuxingQueueSize = 9999;
  static const _maxRetries = 3;
  static const _retryDelay = Duration(seconds: 3);
  static const _cleanupRetries = 3;
  static const _cleanupRetryDelay = Duration(milliseconds: 500);

  YoutubeRepositoryImpl({
    required this.youtubeService,
    required this.apiService,
  });

  void _log(String message) => print('YoutubeRepositoryImpl: $message');

  Future<void> _cleanupFiles(List<String> paths) async {
    for (var p in paths) {
      for (var attempt = 0; attempt < _cleanupRetries; attempt++) {
        try {
          final file = File(p);
          if (await file.exists()) {
            await file.delete();
            _log('Deleted temp file: $p');
          }
          break;
        } catch (e) {
          _log('Cleanup failed for $p (attempt ${attempt + 1}): $e');
          if (attempt < _cleanupRetries - 1) {
            await Future.delayed(_cleanupRetryDelay);
          }
        }
      }
    }
  }

  @override
  Future<Either<Failure, List<VideoEntity>>> searchVideos(String query) async {
    _log('Searching videos for query: $query');
    try {
      final videos = await youtubeService.searchVideos(query);
      return Right(videos.map((v) => v.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(exception: e));
    } catch (e) {
      return Left(ServerFailure(exception: ServerException(message: e.toString())));
    }
  }

  @override
  Future<Either<Failure, List<VideoEntity>>> fetchHomeVideos() async {
    _log('Fetching home (trending) videos');
    try {
      final resp = await youtubeService.fetchHomeVideos();
      final videos = resp.contents
          .where((c) => c.type == 'video')
          .map((c) => c.video.toEntity())
          .toList();
      return Right(videos);
    } on ServerException catch (e) {
      return Left(ServerFailure(exception: e));
    } catch (e) {
      return Left(ServerFailure(exception: ServerException(message: e.toString())));
    }
  }

  @override
  Future<Either<Failure, String>> downloadVideo(
    String videoId,
    String title, {
    bool isAudioOnly = false,
    Function(double)? progressCallback,
    String? preferredQuality,
  }) async {
    YoutubeExplode? yt;
    try {
      yt = YoutubeExplode();
      _log('Downloading videoId=$videoId, audioOnly=$isAudioOnly, quality=$preferredQuality');

      // 1) fetch metadata with retries
      late Video video;
      for (var attempt = 0; attempt < _maxRetries; attempt++) {
        try {
          video = await yt.videos.get(videoId);
          break;
        } catch (e) {
          if (attempt == _maxRetries - 1) rethrow;
          await Future.delayed(_retryDelay);
        }
      }
      if (video.isLive) {
        throw ServerException(message: 'Live videos cannot be downloaded');
      }

      // 2) fetch manifest with retries
      late StreamManifest manifest;
      for (var attempt = 0; attempt < _maxRetries; attempt++) {
        try {
          manifest = await yt.videos.streams.getManifest(videoId);
          break;
        } catch (e) {
          if (attempt == _maxRetries - 1) rethrow;
          await Future.delayed(_retryDelay);
        }
      }

      final dir = await getApplicationDocumentsDirectory();
      final base =
          'video_${videoId}_${DateTime.now().millisecondsSinceEpoch}';

      // 3) audio‐only branch
      if (isAudioOnly) {
        final audioStreams = manifest.audio
            .where((s) => s.container.name == 'mp4' || s.container.name == 'm4a')
            .toList()
          ..sort((a, b) =>
              b.bitrate.kiloBitsPerSecond.compareTo(a.bitrate.kiloBitsPerSecond));
        if (audioStreams.isEmpty) {
          throw ServerException(message: 'No audio streams available');
        }
        final a = audioStreams.first;
        final ext = a.container.name;
        final aPath = '${dir.path}/$base.$ext';
        await _downloadStreamToFile(
          yt.videos.streams.get(a),
          aPath,
          progressCallback,
          a.size.totalBytes,
          'Audio',
          0,
          1,
        );
        String output = aPath;

        // if webm, convert to m4a
        if (ext == 'webm') {
          final out = '${dir.path}/$base.m4a';
          final cmd =
              '-y -i "$aPath" -vn -acodec aac -b:a 128k "$out" -loglevel verbose';
          _log('FFmpeg convert: $cmd');
          final sess = await FFmpegKit.execute(cmd);
          final rc = await sess.getReturnCode();
          if (!ReturnCode.isSuccess(rc)) {
            final logs = (await sess.getAllLogs())
                .map((l) => l.getMessage())
                .join('\n');
            throw ServerException(message: 'Audio conversion failed: $logs');
          }
          await _cleanupFiles([aPath]);
          output = out;
        }
        return Right(output);
      }

      // 4) prefer muxed streams if available
      final muxed = manifest.muxed.toList()
        ..sort((a, b) => b.size.totalBytes.compareTo(a.size.totalBytes));
      if (muxed.isNotEmpty) {
        final best = muxed.first;
        final outPath = '${dir.path}/$base.${best.container.name}';
        await _downloadStreamToFile(
          yt.videos.streams.get(best),
          outPath,
          progressCallback,
          best.size.totalBytes,
          'Muxed',
          0,
          1,
        );
        return Right(outPath);
      }

      // 5) fallback to separate video+audio + FFmpeg‐mux
      final videos = manifest.video.toList();
      final audios = manifest.audio.toList()
        ..sort((a, b) =>
            b.bitrate.kiloBitsPerSecond.compareTo(a.bitrate.kiloBitsPerSecond));
      if (videos.isEmpty) {
        throw ServerException(message: 'No video streams available');
      }
      if (audios.isEmpty) {
        throw ServerException(message: 'No audio streams available');
      }

      // pick video by preferredQuality label (e.g. "720p")
      final height = {
        'high': 1080,
        'medium': 720,
        'low': 360,
      }[preferredQuality?.toLowerCase()] ?? 720;
      var selV = videos.firstWhere(
        (v) => v.container.name == 'mp4' && v.videoResolution.height == height,
        orElse: () => videos.firstWhere((v) => v.container.name == 'mp4'),
      );
      var selA = audios.first;

      final vPath = '${dir.path}/${base}_v.${selV.container.name}';
      final aPath = '${dir.path}/${base}_a.${selA.container.name}';

      await _downloadStreamToFile(
        yt.videos.streams.get(selV),
        vPath,
        (p) => progressCallback?.call(p * 0.5),
        selV.size.totalBytes,
        'Video',
        0,
        0.5,
      );
      await _downloadStreamToFile(
        yt.videos.streams.get(selA),
        aPath,
        (p) => progressCallback?.call(0.5 + p * 0.5),
        selA.size.totalBytes,
        'Audio',
        0.5,
        0.5,
      );

      final outPath = '${dir.path}/$base.mp4';
      final aCodec = selA.container.name == 'webm' ? 'aac' : 'copy';
      final cmd =
          '-y -i "$vPath" -i "$aPath" -c:v copy -c:a $aCodec -ac 2 -ar 44100 '
          '-map 0:v:0 -map 1:a:0 -max_muxing_queue_size $_maxMuxingQueueSize '
          '"$outPath"';
      _log('FFmpeg mux: $cmd');
      final sess = await FFmpegKit.execute(cmd);
      final rc = await sess.getReturnCode();
      if (!ReturnCode.isSuccess(rc)) {
        final logs = (await sess.getAllLogs())
            .map((l) => l.getMessage())
            .join('\n');
        throw ServerException(message: 'Muxing failed: $logs');
      }

      await _cleanupFiles([vPath, aPath]);
      return Right(outPath);

    } on ServerException catch (e) {
      return Left(ServerFailure(exception: e));
    } catch (e) {
      return Left(ServerFailure(
          exception: ServerException(message: 'Unexpected: $e')));
    } finally {
      yt?.close();
    }
  }

  // helper for streaming files
  Future<void> _downloadStreamToFile(
    Stream<List<int>> stream,
    String outPath,
    Function(double)? progressCallback,
    int totalBytes,
    String logName,
    double progressOffset,
    double progressRange,
  ) async {
    final file = File(outPath)..createSync(recursive: true);
    final sink = file.openWrite();
    int received = 0;
    try {
      await for (final chunk in stream) {
        sink.add(chunk);
        received += chunk.length;
        if (totalBytes > 0 && progressCallback != null) {
          final prog =
              progressOffset + (received / totalBytes).clamp(0.0, 1.0) * progressRange;
          progressCallback(prog);
        }
      }
      await sink.flush();
      await sink.close();
      if (!await file.exists() || await file.length() < 1024) {
        throw Exception('$logName download failed: size=${await file.length()}');
      }
    } catch (e) {
      await sink.close();
      if (await file.exists()) await file.delete();
      throw Exception('$logName download failed: $e');
    }
  }
}
