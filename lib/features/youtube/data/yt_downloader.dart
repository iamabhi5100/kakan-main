// lib/features/youtube/data/yt_downloader.dart
// Robust YouTube downloader (RapidAPI DataFanatic)
// - Fixes green/diagonal artifacts (no bwdif; safe yuv420p+even-dims)
// - Resilient details() with parameter-shape fallbacks (handles 400/403)
// - Safe mux with FFmpeg and copy fallback

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';

class RapidApiConfig {
  final String baseUrl;
  final String detailsPath;
  final Map<String, String> headers;
  const RapidApiConfig({
    required this.baseUrl,
    required this.detailsPath,
    required this.headers,
  });
}

RapidApiConfig buildRapidApiConfigFromEnv({required String rapidApiKey}) {
  final host = (dotenv.env['RAPIDAPI_HOST'] ?? '').trim().isNotEmpty
      ? dotenv.env['RAPIDAPI_HOST']!.trim()
      : 'yt-api.p.rapidapi.com';
  final baseUrl = (dotenv.env['RAPIDAPI_BASE_URL'] ?? '').trim().isNotEmpty
      ? dotenv.env['RAPIDAPI_BASE_URL']!.trim()
      : 'https://yt-api.p.rapidapi.com';
  final detailsPath = (dotenv.env['RAPIDAPI_DETAILS_PATH'] ?? '').trim().isNotEmpty
      ? dotenv.env['RAPIDAPI_DETAILS_PATH']!.trim()
      : '/dl';

  return RapidApiConfig(
    baseUrl: baseUrl,
    detailsPath: detailsPath,
    headers: {
      'X-RapidAPI-Key': rapidApiKey,
      'X-RapidAPI-Host': host,
      'Accept': 'application/json',
    },
  );
}

/// Artifact-safe filter (no deinterlace). Forces even dims, caps width, yuv420p.
const _ffmpegSafeFilter =
    'scale=min(960\\,trunc(iw/2)*2):-2,setsar=1,format=yuv420p';

class YtDownloader {
  final Dio _dio;
  final RapidApiConfig _rapid;

  static const List<String> _uas = [
    'Mozilla/5.0 (Linux; Android 13; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15',
  ];

  YtDownloader({required RapidApiConfig rapidConfig, Dio? dio})
      : _rapid = rapidConfig,
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 20),
                followRedirects: true,
                validateStatus: (code) => code != null && code < 500, // we'll handle 4xx
                headers: {
                  'User-Agent': _uas.first,
                },
              ),
            );

  /// Public API
  Future<String> download({
    required String videoIdOrUrl,
    bool audioOnly = false,
    String? customName,
    void Function(int received, int total)? onProgress,
  }) async {
    final id = _extractVideoId(videoIdOrUrl) ?? videoIdOrUrl;

    // ---- details() with resilient fallbacks
    final root = await _getDetailsResilient(id);

    // ---- candidate extraction
    final muxed = _collectMuxedMp4Candidates(root);
    final videoOnly = _collectVideoOnlyMp4H264(root);
    final audioOnlyList = _collectM4a(root);

    // If nothing yet, try URL-based query once
    if (muxed.isEmpty && videoOnly.isEmpty && audioOnlyList.isEmpty) {
      final alt = await _getDetailsResilient('https://www.youtube.com/watch?v=$id',
          preferUrlParam: true);
      muxed.addAll(_collectMuxedMp4Candidates(alt));
      videoOnly.addAll(_collectVideoOnlyMp4H264(alt));
      audioOnlyList.addAll(_collectM4a(alt));
    }

    if (audioOnly) {
      if (audioOnlyList.isEmpty) {
        throw Exception('No M4A candidate found for this video.');
      }
      final dir = await getApplicationDocumentsDirectory();
      final audioPath =
          '${dir.path}/${_sanitizeFileName(customName ?? 'yt_$id')}.m4a';
      await _downloadFileFromCandidates(
        audioOnlyList,
        audioPath,
        onProgress: onProgress,
      );
      return audioPath;
    }

    // muxed preferred
    if (muxed.isNotEmpty) {
      final dir = await getApplicationDocumentsDirectory();
      final muxPath =
          '${dir.path}/${_sanitizeFileName(customName ?? 'yt_$id')}.mp4';
      await _downloadFileFromCandidates(
        muxed,
        muxPath,
        onProgress: onProgress,
      );
      return await _normalizeVideo(muxPath);
    }

    // otherwise separate video+audio
    if (videoOnly.isEmpty || audioOnlyList.isEmpty) {
      throw Exception('No compatible MP4/M4A streams found.');
    }

    final appDir = await getApplicationDocumentsDirectory();
    final base = _sanitizeFileName(customName ?? 'yt_$id');
    final vTmp = File('${appDir.path}/$base.__video.mp4');
    final aTmp = File('${appDir.path}/$base.__audio.m4a');
    final outFile = File('${appDir.path}/$base.mp4');

    await _downloadFileFromCandidates(
      videoOnly,
      vTmp.path,
      onProgress: (r, t) {
        onProgress?.call(r ~/ 2, math.max(1, t ~/ 2));
      },
    );
    await _downloadFileFromCandidates(
      audioOnlyList,
      aTmp.path,
      onProgress: (r, t) {
        onProgress?.call(
            math.max(1, r ~/ 2) + math.max(1, t ~/ 2), math.max(1, t));
      },
    );

    // Safe mux
    final cmd =
        '-y -i "${vTmp.path}" -i "${aTmp.path}" -map 0:v:0 -map 1:a:0 '
        '-vf $_ffmpegSafeFilter -c:v libx264 -profile:v baseline -level 3.1 '
        '-pix_fmt yuv420p -preset veryfast -crf 22 -c:a aac -b:a 128k '
        '-movflags +faststart "${outFile.path}"';

    var session = await FFmpegKit.execute(cmd);
    var rc = await session.getReturnCode();
    if (!ReturnCode.isSuccess(rc)) {
      // Fallback to stream copy if filter path fails
      final fallback = '-y -i "${vTmp.path}" -i "${aTmp.path}" -c copy "${outFile.path}"';
      await FFmpegKit.execute(fallback);
    }

    await Future.wait([
      if (vTmp.existsSync()) vTmp.delete(),
      if (aTmp.existsSync()) aTmp.delete(),
    ]);

    return await _normalizeVideo(outFile.path);
  }

  // ---------------- internals ----------------

  Future<String> _normalizeVideo(String inputPath) async {
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) return inputPath;

    final safeSuffix = inputPath.contains('.')
        ? inputPath.replaceFirst(RegExp(r'\.[^.]+$'), '_safe.mp4')
        : '${inputPath}_safe.mp4';
    final out = safeSuffix == inputPath ? '${inputPath}_safe.mp4' : safeSuffix;

    debugPrint('[YT_DL] normalize start → $inputPath');

    // Try H.264 codecs first, then mpeg4 (often available when libx264 is not)
    const h264Codecs = [
      'libx264',
      'c2.android.avc.encoder',
      'h264',
      'h264_mediacodec',
      'libopenh264',
    ];
    const mpeg4Codecs = ['mpeg4'];
    for (final rawCodec in [...h264Codecs, ...mpeg4Codecs]) {
      final codec = rawCodec;
      final isH264 = h264Codecs.contains(codec);
      final isLibx264 = codec == 'libx264';
      final cmd = isH264
          ? (isLibx264
              ? '-y -i "$inputPath" -vf $_ffmpegSafeFilter -c:v $codec '
                  '-profile:v baseline -level 3.1 -pix_fmt yuv420p '
                  '-preset veryfast -crf 22 -c:a aac -b:a 128k '
                  '-movflags +faststart "$out"'
              : '-y -i "$inputPath" -vf $_ffmpegSafeFilter -c:v $codec '
                  '-profile:v baseline -level 3.1 -pix_fmt yuv420p '
                  '-b:v 2500k -maxrate 4000k -bufsize 8000k '
                  '-c:a aac -b:a 128k -movflags +faststart "$out"')
          : '-y -i "$inputPath" -vf $_ffmpegSafeFilter -c:v $codec -pix_fmt yuv420p '
              '-q:v 5 -c:a aac -b:a 128k -movflags +faststart "$out"';
      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();
      if (ReturnCode.isSuccess(rc)) {
        final outFile = File(out);
        if (!await outFile.exists() || await outFile.length() == 0) {
          debugPrint('[YT_DL] normalize produced empty output with $codec');
          continue;
        }
        try {
          await outFile.rename(inputPath);
          debugPrint('[YT_DL] normalize success ($codec rename) → $inputPath');
          return inputPath;
        } catch (e) {
          try {
            await outFile.copy(inputPath);
            await outFile.delete();
            debugPrint('[YT_DL] normalize success ($codec copy) → $inputPath');
            return inputPath;
          } catch (err) {
            debugPrint('[YT_DL] normalize copy fallback failed ($codec): $err');
            continue;
          }
        }
      } else {
        final logs = await session.getAllLogsAsString();
        debugPrint('[YT_DL] normalize failed rc=${rc?.getValue()} codec=$codec logs=$logs');
      }
    }

    debugPrint('[YT_DL] normalize falling back to original file.');
    return inputPath;
  }

  Future<void> _downloadToFile(Uri url, String path,
      {void Function(int, int)? onProgress}) async {
    final res = await _dio.get<List<int>>(
      url.toString(),
      options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: onProgress,
    );

    final statusCode = res.statusCode ?? 0;
    if (statusCode >= 400) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        error: 'HTTP $statusCode while downloading $url',
      );
    }

    final contentType =
        (res.headers.value('content-type') ?? '').toLowerCase();
    if (contentType.isNotEmpty &&
        !contentType.startsWith('video/') &&
        !contentType.startsWith('audio/')) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        error: 'Unexpected content-type "$contentType" for $url',
      );
    }

    final data = res.data;
    if (data == null || data.isEmpty) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        error: 'Empty response when downloading $url',
      );
    }

    await File(path).writeAsBytes(data, flush: true);
  }

  Future<void> _downloadFileFromCandidates(
    List<Uri> candidates,
    String outputPath, {
    void Function(int, int)? onProgress,
  }) async {
    if (candidates.isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(path: 'no-candidates'),
        error: 'No downloadable candidates provided.',
      );
    }

    final tried = <String>{};
    DioException? lastErr;

    for (final candidate in candidates) {
      final key = candidate.toString();
      if (!tried.add(key)) continue;

      final headOk = await _passesHeadPreflight(candidate);
      if (!headOk) continue;

      try {
        final file = File(outputPath);
        if (await file.exists()) {
          await file.delete();
        }
        await _downloadToFile(candidate, outputPath, onProgress: onProgress);
        if (await file.exists() && await file.length() > 0) {
          if (outputPath.toLowerCase().endsWith('.mp4')) {
            final hasMoov = await _fileContainsMoovAtom(outputPath);
            if (!hasMoov) {
              lastErr = DioException(
                requestOptions: RequestOptions(path: key),
                error: 'Downloaded MP4 missing moov atom.',
              );
              continue;
            }
          }
          return;
        }
        lastErr = DioException(
          requestOptions: RequestOptions(path: key),
          error: 'Downloaded file is empty.',
        );
      } on DioException catch (e) {
        lastErr = e;
        continue;
      } catch (e) {
        lastErr = DioException(
          requestOptions: RequestOptions(path: key),
          error: e,
        );
        continue;
      }
    }

    throw lastErr ??
        DioException(
          requestOptions: RequestOptions(path: candidates.first.toString()),
          error: 'Failed to download any candidate',
        );
  }

  Future<bool> _fileContainsMoovAtom(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;
    final pattern = 'moov'.codeUnits;
    var matchIndex = 0;

    await for (final chunk in file.openRead()) {
      for (final byte in chunk) {
        if (byte == pattern[matchIndex]) {
          matchIndex++;
          if (matchIndex == pattern.length) return true;
        } else {
          matchIndex = byte == pattern[0] ? 1 : 0;
        }
      }
    }
    return false;
  }

  // ---- details(): yt-api /dl?id=...&cgeo=... (back off on 400/403/429)
  Future<dynamic> _getDetailsResilient(String idOrUrl,
      {bool preferUrlParam = false}) async {
    final id = _extractVideoId(idOrUrl) ?? idOrUrl;
    final cgeoRaw = (dotenv.env['RAPIDAPI_CGEO'] ?? '').trim();
    final langRaw = (dotenv.env['RAPIDAPI_LANG'] ?? '').trim();

    final attempts = <Map<String, String>>[];
    final base = <String, String>{
      'id': id,
      'cgeo': cgeoRaw.isNotEmpty ? cgeoRaw : 'US',
    };
    if (langRaw.isNotEmpty) {
      base['lang'] = langRaw;
    }
    attempts.add(base);
    // fallback without cgeo if needed
    final noCgeo = <String, String>{'id': id};
    if (langRaw.isNotEmpty) {
      noCgeo['lang'] = langRaw;
    }
    attempts.add(noCgeo);

    DioException? lastErr;
    for (var i = 0; i < attempts.length; i++) {
      try {
        return await _rapidGetDetails(attempts[i]);
      } on DioException catch (e) {
        lastErr = e;
        final code = e.response?.statusCode ?? 0;
        if (code == 400 || code == 403 || code == 429) {
          // jittered backoff
          final delayMs = 300 * (i + 1);
          await Future.delayed(Duration(milliseconds: delayMs));
          continue;
        }
        rethrow;
      }
    }
    throw lastErr ??
        DioException(
          requestOptions: RequestOptions(path: 'details'),
          error: 'Unknown error',
        );
  }

  Future<dynamic> _rapidGetDetails(Map<String, String> qp) async {
    final url = Uri.parse('${_rapid.baseUrl}${_rapid.detailsPath}')
        .replace(queryParameters: qp);
    final res = await _dio.get(
      url.toString(),
      options: Options(headers: _rapid.headers),
    );

    final sc = res.statusCode ?? 0;
    if (sc >= 400) {
      throw DioException(requestOptions: res.requestOptions, response: res);
    }
    return res.data;
  }

  Future<bool> _passesHeadPreflight(Uri url) async {
    try {
      final r = await _dio.head(url.toString(),
          options: Options(validateStatus: (c) => c != null && c < 400));
      final ct = (r.headers.value('content-type') ?? '').toLowerCase();
      return ct.startsWith('video/') || ct.startsWith('audio/') || ct.isEmpty;
    } catch (_) {
      return true; // don’t block downloads on HEAD errors
    }
  }

  // ---- JSON collectors
  List<Uri> _collectMuxedMp4Candidates(dynamic json) {
    final fromFormats = _extractStreams(
      json,
      listKey: 'formats',
      accept: (mime, codecs) {
        if (!mime.contains('video/mp4')) return false;
        final lc = codecs.toLowerCase();
        if (lc.contains('av01') || lc.contains('vp9')) return false;
        return true;
      },
    );
    if (fromFormats.isNotEmpty) return fromFormats;
    return _legacyCollectUris(json, '.mp4');
  }

  List<Uri> _collectVideoOnlyMp4H264(dynamic json) {
    final adaptive = _extractStreams(
      json,
      listKey: 'adaptiveFormats',
      accept: (mime, codecs) {
        if (!mime.contains('video/mp4')) return false;
        final lc = codecs.toLowerCase();
        if (lc.contains('av01') || lc.contains('vp9')) return false;
        return true;
      },
    );
    if (adaptive.isNotEmpty) return adaptive;
    return _legacyCollectUris(json, '.mp4', filter: ['av01', 'vp9', '.m3u8']);
  }

  List<Uri> _collectM4a(dynamic json) {
    final audio = _extractStreams(
      json,
      listKey: 'adaptiveFormats',
      accept: (mime, codecs) => mime.contains('audio/mp4'),
    );
    if (audio.isNotEmpty) return audio;
    // legacy fallback (DataFanatic style)
    return _legacyCollectUris(json, '.m4a');
  }

  List<Uri> _legacyCollectUris(dynamic json, String ext, {List<String> filter = const []}) {
    final out = <Uri>[];
    void scan(dynamic n) {
      if (n is Map) {
        n.values.forEach(scan);
      } else if (n is List) {
        n.forEach(scan);
      } else if (n is String && n.contains(ext) && !filter.any((f) => n.contains(f))) {
        final u = Uri.tryParse(n);
        if (u != null) out.add(u);
      }
    }
    scan(json);
    return out;
  }

  List<Uri> _extractStreams(
    dynamic root, {
    required String listKey,
    required bool Function(String mime, String codecs) accept,
  }) {
    if (root is! Map) return const [];
    final list = root[listKey];
    if (list is! List) return const [];
    final out = <Uri>[];
    for (final raw in list) {
      if (raw is! Map) continue;
      final entry = Map<String, dynamic>.from(raw);
      final urlStr = entry['url']?.toString();
      if (urlStr == null || urlStr.isEmpty) continue;
      final mime = (entry['mimeType'] ?? '').toString().toLowerCase();
      if (mime.isEmpty) continue;
      final codecs = _extractCodecs(entry);
      if (!accept(mime, codecs)) continue;
      final uri = Uri.tryParse(urlStr);
      if (uri != null) out.add(uri);
    }
    return out;
  }

  String _extractCodecs(Map<String, dynamic> entry) {
    final field = (entry['codecs'] ?? '').toString();
    if (field.isNotEmpty) return field;
    final mime = (entry['mimeType'] ?? '').toString();
    final match = RegExp(r'codecs="([^"]+)"', caseSensitive: false).firstMatch(mime);
    return match?.group(1) ?? '';
  }

  // ---- utils
  String? _extractVideoId(String idOrUrl) {
    if (RegExp(r'^[0-9A-Za-z_-]{11}$').hasMatch(idOrUrl)) return idOrUrl;
    final m = RegExp(r'(?:v=|\/)([0-9A-Za-z_-]{11})').firstMatch(idOrUrl);
    return m?.group(1);
  }

  String _sanitizeFileName(String input) =>
      input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
}
