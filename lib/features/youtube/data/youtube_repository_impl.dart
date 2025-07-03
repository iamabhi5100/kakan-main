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
    for (var path in paths) {
      for (var attempt = 0; attempt < _cleanupRetries; attempt++) {
        try {
          if (await File(path).exists()) {
            await File(path).delete();
            _log('Deleted temp file: $path');
            break;
          }
        } catch (e) {
          _log('Failed to delete $path (attempt ${attempt + 1}): $e');
          if (attempt < _cleanupRetries - 1) {
            await Future.delayed(_cleanupRetryDelay);
          }
        }
      }
    }
  }

  bool _isValidVideoId(String videoId) =>
      RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(videoId);

  @override
  Future<Either<Failure, List<VideoEntity>>> searchVideos(String query) async {
    _log('Search videos: $query');
    try {
      final videos = await youtubeService.searchVideos(query);
      return Right(videos.map((v) => v.toEntity()).toList());
    } on ServerException catch (e) {
      _log('Search failed: ${e.message}');
      return Left(ServerFailure(exception: e));
    } catch (e, stackTrace) {
      _log('Search failed with unexpected error: $e, stackTrace: $stackTrace');
      return Left(ServerFailure(
          exception: ServerException(message: 'Unexpected error: $e')));
    }
  }

  @override
  Future<Either<Failure, List<VideoEntity>>> fetchHomeVideos() async {
    _log('Fetch home videos');
    try {
      final resp = await youtubeService.fetchHomeVideos();
      final videos = resp.contents
          .where((c) => c.type == 'video')
          .map((c) => c.video.toEntity())
          .toList();
      return Right(videos);
    } on ServerException catch (e) {
      _log('Fetch home failed: ${e.message}');
      return Left(ServerFailure(exception: e));
    } catch (e, stackTrace) {
      _log('Fetch home failed with unexpected error: $e, stackTrace: $stackTrace');
      return Left(ServerFailure(
          exception: ServerException(message: 'Unexpected error: $e')));
    }
  }

  Future<void> _downloadStreamToFile(
    Stream<List<int>> stream,
    String outPath,
    void Function(double)? progressCallback,
    int total,
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
        if (total > 0 && progressCallback != null) {
          final progress =
              progressOffset + (received / total).clamp(0.0, 1.0) * progressRange;
          progressCallback(progress);
        }
      }
      await sink.flush();
      await sink.close();
      if (!await file.exists() || await file.length() < 1024) {
        throw Exception(
            '$logName download failed: File missing or too small (${await file.length()} bytes)');
      }
    } catch (e) {
      await sink.close();
      if (await file.exists()) await file.delete();
      throw Exception('$logName download failed: $e');
    }
  }

  int _mapPreferredQualityToHeight(String? quality) {
    switch (quality?.toLowerCase()) {
      case 'high':
        return 1080;
      case 'medium':
        return 720;
      case 'low':
        return 360;
      default:
        return 720;
    }
  }

  int _mapQualityToHeight(String qualityLabel) {
    final match = RegExp(r'(\d+)p').firstMatch(qualityLabel);
    return match != null ? int.parse(match.group(1)!) : 720;
  }

  @override
  Future<Either<Failure, String>> downloadVideo(
    String videoId,
    String title, {
    bool isAudioOnly = false,
    void Function(double)? progressCallback,
    String? preferredQuality,
  }) async {
    YoutubeExplode? yt;
    try {
      yt = YoutubeExplode();
      _log('Starting download for videoId: $videoId, isAudioOnly: $isAudioOnly, preferredQuality: $preferredQuality');

      if (!_isValidVideoId(videoId)) {
        throw ServerException(message: 'Invalid video ID: $videoId');
      }

      // Get video metadata
      Video? video;
      for (var attempt = 0; attempt < _maxRetries; attempt++) {
        try {
          video = await yt.videos.get(videoId);
          _log('Fetched video metadata: ${video.title}');
          break;
        } catch (e) {
          _log('Failed to fetch video metadata (attempt ${attempt + 1}): $e');
          if (attempt < _maxRetries - 1) {
            await Future.delayed(_retryDelay);
            continue;
          }
          throw ServerException(message: 'Failed to fetch video metadata: $e');
        }
      }
      if (video == null) throw ServerException(message: 'Video metadata missing');
      if (video.isLive) throw ServerException(message: 'Live videos cannot be downloaded');

      // Get manifest with retries for 403 errors
      StreamManifest? manifest;
      for (var attempt = 0; attempt < _maxRetries; attempt++) {
        try {
          manifest = await yt!.videos.streams.getManifest(videoId);
          _log(
              'Fetched manifest with ${manifest.muxed.length} muxed, ${manifest.video.length} video, ${manifest.audio.length} audio streams');
          break;
        } catch (e) {
          _log('Failed to fetch stream manifest (attempt ${attempt + 1}): $e');
          if (e.toString().contains('403')) {
            await Future.delayed(Duration(seconds: 3 * (attempt + 1)));
            yt?.close();
            yt = YoutubeExplode();
            _log('Reinitialized YoutubeExplode client for attempt ${attempt + 2}');
          }
          if (attempt == _maxRetries - 1) {
            throw ServerException(message: 'Failed to fetch stream manifest: $e');
          }
        }
      }
      if (manifest == null)
        throw ServerException(message: 'Stream manifest could not be retrieved');

      final dir = await getApplicationDocumentsDirectory();
      final baseName =
          'video_${videoId}_${DateTime.now().millisecondsSinceEpoch}';

      // Audio-only mode
      if (isAudioOnly) {
        if (manifest.audio.isEmpty)
          throw ServerException(message: 'No audio streams available');
        final aStream = manifest.audio
            .where((s) => s.container.name == 'mp4' || s.container.name == 'm4a')
            .toList()
            .withHighestBitrate();
        final ext = aStream.container.name;
        final audioPath = '${dir.path}/$baseName.$ext';

        try {
          _log('Attempting to download audio stream: ${aStream.bitrate}');
          await _downloadStreamToFile(
            yt!.videos.streams.get(aStream),
            audioPath,
            progressCallback,
            aStream.size.totalBytes,
            'Audio',
            0,
            1,
          );
        } catch (e) {
          yt?.close();
          return Left(ServerFailure(
              exception:
                  ServerException(message: 'Audio stream download failed: $e')));
        }

        String outputPath = audioPath;
        if (ext == 'webm') {
          outputPath = '${dir.path}/$baseName.m4a';
          final cmd =
              '-y -i "$audioPath" -vn -acodec aac -b:a 128k "$outputPath" -loglevel verbose';
          _log('Executing FFmpeg command: $cmd');
          final sess = await FFmpegKit.execute(cmd);
          final rc = await sess.getReturnCode();
          if (ReturnCode.isSuccess(rc)) {
            await _cleanupFiles([audioPath]);
            _log('Audio conversion successful: $outputPath');
          } else {
            final logs = await sess.getAllLogs();
            final errorMessage =
                logs.map((log) => log.getMessage()).join('\n');
            _log('Audio conversion failed: $errorMessage');
            yt?.close();
            return Left(ServerFailure(
                exception: ServerException(
                    message: 'Audio conversion failed: $errorMessage')));
          }
        }

        yt?.close();
        return Right(outputPath);
      }

      // Video (muxed) mode with format prioritization
      final muxed = manifest.muxed
          .where((s) => s.container.name == 'mp4')
          .toList();
      if (muxed.isNotEmpty) {
        if (preferredQuality != null) {
          muxed.sort((a, b) {
            final qualityA = _mapQualityToHeight(a.videoQualityLabel);
            final qualityB = _mapQualityToHeight(b.videoQualityLabel);
            final targetHeight = _mapPreferredQualityToHeight(preferredQuality);
            return (qualityB - targetHeight)
                .abs()
                .compareTo((qualityA - targetHeight).abs());
          });
        } else {
          muxed.sort(
              (a, b) => b.videoQualityLabel.compareTo(a.videoQualityLabel));
        }

        for (final s in muxed) {
          final ext = s.container.name;
          final out = '${dir.path}/$baseName.$ext';
          try {
            _log('Attempting to download muxed stream: ${s.videoQualityLabel}');
            await _downloadStreamToFile(
              yt!.videos.streams.get(s),
              out,
              progressCallback,
              s.size.totalBytes,
              'Muxed',
              0,
              1,
            );
            yt?.close();
            return Right(out);
          } catch (e) {
            _log('Muxed stream ${s.videoQualityLabel} failed: $e');
            continue;
          }
        }
      }

      // Fallback to separate video + audio with quality fallback
      _log('No muxed MP4 streams available—falling back to separate V/A + FFmpeg');
      final vids = manifest.video
          .where((v) => v.container.name == 'mp4' && v.container.name != 'm3u8')
          .toList();
      final qualityFallbacks = ['medium', 'low'];
      VideoStreamInfo? selV;

      for (var quality in qualityFallbacks) {
        _log('Trying quality: $quality');
        vids.sort((a, b) {
          final heightA = a.videoResolution.height;
          final heightB = b.videoResolution.height;
          final targetHeight = _mapPreferredQualityToHeight(quality);
          return (heightB - targetHeight)
              .abs()
              .compareTo((heightA - targetHeight).abs());
        });

        for (var vs in vids) {
          try {
            _log('Testing video stream: ${vs.qualityLabel}');
            await yt!.videos.streams.get(vs).first;
            selV = vs;
            _log('Selected video stream: ${vs.qualityLabel}');
            break;
          } catch (e) {
            _log('Video stream ${vs.qualityLabel} unavailable: $e');
          }
        }
        if (selV != null) break;
      }

      if (selV == null) {
        _log('No available video streams');
        yt?.close();
        return Left(ServerFailure(
            exception: ServerException(
                message: 'No available video streams for this video')));
      }

      final auds = manifest.audio
          .where((a) => a.container.name == 'mp4' || a.container.name == 'm4a')
          .toList()
        ..sort((a, b) => b.bitrate.kiloBitsPerSecond
            .compareTo(a.bitrate.kiloBitsPerSecond));
      final selA = auds.isNotEmpty ? auds.first : null;
      if (selA == null) {
        yt?.close();
        return Left(ServerFailure(
            exception: ServerException(message: 'No available audio streams')));
      }

      // Download video
      final vPath = '${dir.path}/${baseName}_video.${selV.container.name}';
      try {
        _log('Downloading video stream: ${selV.qualityLabel}');
        await _downloadStreamToFile(
          yt!.videos.streams.get(selV),
          vPath,
          (prog) => progressCallback?.call(prog * 0.5),
          selV.size.totalBytes,
          'Video',
          0,
          0.5,
        );
        _log('Video stream download finished: $vPath');
      } catch (e) {
        _log('Video stream download failed: $e');
        yt?.close();
        return Left(ServerFailure(
            exception:
                ServerException(message: 'Video stream download failed: $e')));
      }

      // Download audio
      final aPath = '${dir.path}/${baseName}_audio.${selA.container.name}';
      try {
        _log('Downloading audio stream: ${selA.bitrate}');
        await _downloadStreamToFile(
          yt.videos.streams.get(selA),
          aPath,
          (prog) => progressCallback?.call(0.5 + prog * 0.5),
          selA.size.totalBytes,
          'Audio',
          0.5,
          0.5,
        );
        _log('Audio stream download finished: $aPath');
      } catch (e) {
        _log('Audio stream download failed: $e');
        if (await File(vPath).exists()) await File(vPath).delete();
        yt.close();
        return Left(ServerFailure(
            exception:
                ServerException(message: 'Audio stream download failed: $e')));
      }

      // Ensure both files exist before mux
      if (!(await File(vPath).exists())) {
        _log('Video file missing after download!');
        yt.close();
        return Left(ServerFailure(
            exception:
                ServerException(message: 'Video file missing after download')));
      }
      if (!(await File(aPath).exists())) {
        _log('Audio file missing after download!');
        yt.close();
        return Left(ServerFailure(
            exception:
                ServerException(message: 'Audio file missing after download')));
      }

      // FFmpeg mux
      final outPath = '${dir.path}/$baseName.mp4';
      final aCodec = selA.container.name == 'webm' ? 'aac' : 'copy';
      final cmd =
          '-y -i "$vPath" -i "$aPath" -c:v copy -c:a $aCodec -ac 2 -ar 44100 '
          '-map 0:v:0 -map 1:a:0 -loglevel verbose -max_muxing_queue_size $_maxMuxingQueueSize "$outPath"';
      _log('Executing FFmpeg command: $cmd');
      final sess = await FFmpegKit.execute(cmd);
      final rc = await sess.getReturnCode();
      if (!ReturnCode.isSuccess(rc)) {
        final logs = await sess.getAllLogs();
        final errorMessage = logs.map((log) => log.getMessage()).join('\n');
        _log('Muxing failed: $errorMessage');
        yt.close();
        return Left(ServerFailure(
            exception: ServerException(message: 'Muxing failed: $errorMessage')));
      }
      _log('Muxing completed successfully');

      // Clean up
      await _cleanupFiles([vPath, aPath]);

      // Check output file
      if (!await File(outPath).exists() || await File(outPath).length() < 1024 * 10) {
        _log('Output file missing after mux!');
        yt.close();
        return Left(ServerFailure(
            exception: ServerException(message: 'Output file missing after mux')));
      }

      yt.close();
      return Right(outPath);
    } on ServerException catch (e) {
      _log('Download failed with ServerException: ${e.message}');
      yt?.close();
      return Left(ServerFailure(exception: e));
    } on YoutubeExplodeException catch (e) {
      _log('Download failed with YoutubeExplodeException: ${e.message}');
      yt?.close();
      return Left(ServerFailure(
          exception:
              ServerException(message: 'Video unavailable: ${e.message}')));
    } catch (e, stackTrace) {
      _log('Download failed with unexpected error: $e, stackTrace: $stackTrace');
      yt?.close();
      return Left(ServerFailure(
          exception: ServerException(message: 'Unexpected error: $e')));
    }
  }
}
