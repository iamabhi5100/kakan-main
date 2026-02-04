// lib/features/youtube/data/youtube_service.dart
// RapidAPI DataFanatic search/trending with caching & retries.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/features/youtube/model/video.dart';
import 'package:kakan/features/youtube/model/youtube_home_model.dart';

class YoutubeService {
  final String _apiKey;
  final String _host;
  final String _baseUrl;
  static const String _searchPath = '/search';

  final DefaultCacheManager _cacheManager;

  static const int _maxRetries = 3;
  static const Duration _initialRetryDelay = Duration(seconds: 2);
  static const Duration _httpTimeout = Duration(seconds: 20);
  static const Duration _cacheDuration = Duration(hours: 1);

  YoutubeService({required DefaultCacheManager cacheManager})
      : _cacheManager = cacheManager,
        _apiKey = dotenv.env['RAPIDAPI_KEY']?.trim() ?? '',
        _host = (dotenv.env['RAPIDAPI_HOST']?.trim().isNotEmpty ?? false)
            ? dotenv.env['RAPIDAPI_HOST']!.trim()
            : 'yt-api.p.rapidapi.com',
        _baseUrl = (dotenv.env['RAPIDAPI_BASE_URL']?.trim().isNotEmpty ?? false)
            ? dotenv.env['RAPIDAPI_BASE_URL']!.trim()
            : 'https://yt-api.p.rapidapi.com' {
    if (_apiKey.isEmpty) {
      throw ServerException(message: 'RAPIDAPI_KEY missing in .env');
    }
    _log('INIT: using RapidAPI host=$_host');
  }

  // -------------------- TRENDING --------------------
  Future<YoutubeHomeResponse> fetchHomeVideos() async {
    final rid = _rid('TREND');
    const cacheKey = 'trending_videos_US';

    final cached = await _tryReadCacheMap(rid, cacheKey);
    if (cached != null) {
      try {
        final response = YoutubeHomeResponse.fromJson(cached);
        if (response.contents.isNotEmpty) {
          _log('$rid CACHE HIT (items=${response.contents.length})');
          return response;
        }
      } catch (_) {}
    }

    await _netProbe(rid);

    final url = Uri.parse('$_baseUrl$_searchPath')
        .replace(queryParameters: {'query': 'trending'});

    final headers = {
      'X-RapidAPI-Key': _apiKey,
      'X-RapidAPI-Host': _host,
      'Accept': 'application/json',
    };

    final data = await _doGetWithRetry<Map<String, dynamic>>(
      rid: rid,
      url: url,
      headers: headers,
      on200: (json) => json,
    );

    final normalized = _normalizeRapidSearchToYtApiData(data);
    await _putCacheMap(rid, cacheKey, normalized, maxAge: _cacheDuration);
    return YoutubeHomeResponse.fromJson(normalized);
  }

  // -------------------- SEARCH --------------------
  Future<List<Content>> searchVideos(String query) async {
    final rid = _rid('SRCH');
    final q = query.trim();
    final cacheKey = 'search_videos_$q';

    final cached = await _tryReadCacheMap(rid, cacheKey);
    if (cached != null) {
      try {
        final apiData = (cached['data'] as List?) ?? const [];
        final contents = _processSearchResults(apiData);
        if (contents.isNotEmpty) {
          _log('$rid CACHE HIT (items=${contents.length})');
          return contents;
        }
      } catch (_) {}
    }

    await _netProbe(rid);

    final url = Uri.parse('$_baseUrl$_searchPath')
        .replace(queryParameters: {'query': q});

    final headers = {
      'X-RapidAPI-Key': _apiKey,
      'X-RapidAPI-Host': _host,
      'Accept': 'application/json',
    };

    final data = await _doGetWithRetry<Map<String, dynamic>>(
      rid: rid,
      url: url,
      headers: headers,
      on200: (json) => json,
    );

    final normalized = _normalizeRapidSearchToYtApiData(data);
    await _putCacheMap(rid, cacheKey, normalized, maxAge: _cacheDuration);

    final apiData = (normalized['data'] as List?) ?? const [];
    final contents = _processSearchResults(apiData);
    return contents;
  }

  // -------------------- Normalization --------------------
  Map<String, dynamic> _normalizeRapidSearchToYtApiData(
      Map<String, dynamic> raw) {
    // yt-api returns { data: [...] }. DataFanatic returned { items: [...] }.
    if (raw['data'] is List) {
      return raw;
    }
    final List<dynamic> items =
        (raw['items'] is List) ? List<dynamic>.from(raw['items']) : const [];
    if (items.isEmpty) return {'data': <dynamic>[]};

    final List<dynamic> out = [];
    for (final item in items) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      if ((m['type']?.toString() ?? '') != 'video') continue;

      final vid = (m['id'] ?? '').toString();
      if (vid.length != 11) continue;

      final title = (m['title'] ?? '').toString();
      final ch =
          (m['channel'] is Map) ? Map<String, dynamic>.from(m['channel']) : {};
      final channelName = (ch['name'] ?? ch['title'] ?? '').toString();
      final channelId = (ch['id'] ?? '').toString();

      final lengthText = (m['lengthText'] ?? '').toString();
      final viewCountText = (m['viewCountText'] ?? '').toString();

      String? thumbUrl;
      if (m['thumbnails'] is List && (m['thumbnails'] as List).isNotEmpty) {
        final t0 = (m['thumbnails'] as List).first;
        if (t0 is Map && t0['url'] != null) {
          thumbUrl = t0['url'].toString();
        }
      }

      out.add({
        'type': 'video',
        'videoId': vid,
        'title': title,
        'channelTitle': channelName,
        'channelId': channelId,
        'lengthText': lengthText,
        'viewCountText': viewCountText,
        'thumbnails': thumbUrl != null
            ? [
                {'url': thumbUrl, 'width': 320, 'height': 180}
              ]
            : [],
      });
    }
    return {'data': out};
  }

  // -------------------- Parser --------------------
  List<Content> _processSearchResults(List<dynamic> apiData) {
    final allShorts = <Short>[];
    final allVideos = <Video>[];

    for (final item in apiData) {
      final type = (item is Map) ? (item['type'] as String? ?? '') : '';
      if (type == 'shorts_listing') {
        final list = (item['data'] as List?) ?? const [];
        allShorts.addAll(
            list.map((s) => Short.fromJson(Map<String, dynamic>.from(s))));
      } else if (type == 'shorts') {
        allShorts.add(Short.fromJson(Map<String, dynamic>.from(item)));
      } else if (type == 'video' || (type.isEmpty && _looksLikeVideo(item))) {
        allVideos.add(Video.fromJson(Map<String, dynamic>.from(item)));
      }
    }

    final contents = <Content>[];
    if (allShorts.isNotEmpty) {
      contents.add(Content(type: 'shorts_listing', shorts: allShorts, title: 'Shorts'));
    }
    contents.addAll(allVideos.map((v) => Content(type: 'video', video: v)));
    return contents;
  }

  bool _looksLikeVideo(dynamic item) {
    if (item is! Map) return false;
    final id = (item['videoId'] ?? item['id'] ?? '').toString();
    final title = (item['title'] ?? '').toString();
    final thumbs = item['thumbnail'] ?? item['thumbnails'];
    return id.isNotEmpty && title.isNotEmpty && thumbs is List && thumbs.isNotEmpty;
  }

  // -------------------- HTTP core --------------------
  Future<T> _doGetWithRetry<T>({
    required String rid,
    required Uri url,
    required Map<String, String> headers,
    required T Function(Map<String, dynamic>) on200,
  }) async {
    int attempt = 0;
    while (attempt < _maxRetries) {
      try {
        final resp = await http.get(url, headers: headers).timeout(_httpTimeout);

        if (resp.statusCode == 200) {
          final json = jsonDecode(resp.body) as Map<String, dynamic>;
          return on200(json);
        }

        if ((resp.statusCode == 429 || resp.statusCode == 403 || resp.statusCode == 400) &&
            attempt < _maxRetries - 1) {
          final delay = _initialRetryDelay * (1 << attempt);
          await Future.delayed(delay);
          attempt++;
          continue;
        }

        throw ServerException(
          message: 'Failed: ${resp.statusCode} ${resp.reasonPhrase}\n'
              '${_truncate(resp.body, 400)}',
        );
      } on TimeoutException {
        if (attempt < _maxRetries - 1) {
          final delay = _initialRetryDelay * (1 << attempt);
          await Future.delayed(delay);
          attempt++;
          continue;
        }
        throw ServerException(message: 'Request timed out.');
      } catch (e) {
        if (attempt < _maxRetries - 1) {
          final delay = _initialRetryDelay * (1 << attempt);
          await Future.delayed(delay);
          attempt++;
          continue;
        }
        throw ServerException(message: 'Network error: $e');
      }
    }
    throw ServerException(message: 'Failed after $_maxRetries attempts');
  }

  // -------------------- Cache --------------------
  Future<Map<String, dynamic>?> _tryReadCacheMap(String rid, String key) async {
    try {
      final c = await _cacheManager.getFileFromCache(key);
      if (c == null) return null;
      if (c.validTill.isBefore(DateTime.now())) return null;
      final txt = await c.file.readAsString();
      return jsonDecode(txt) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _putCacheMap(
    String rid,
    String key,
    Map<String, dynamic> data, {
    Duration maxAge = _cacheDuration,
  }) async {
    try {
      final bytes = utf8.encode(jsonEncode(data));
      await _cacheManager.putFile(
        key,
        bytes,
        maxAge: maxAge,
        fileExtension: '.json',
      );
    } catch (e) {
      _log('$rid CACHE WRITE ERR: $e');
    }
  }

  Future<void> _netProbe(String rid) async {
    try {
      await http
          .get(Uri.parse('https://www.google.com/generate_204'))
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  // -------------------- Utils --------------------
  static void _log(String m) => debugPrint('[YT_SVC] $m');

  static String _rid(String tag) {
    final n = (DateTime.now().microsecondsSinceEpoch % 100000);
    return '$tag#${n.toString().padLeft(5, "0")}';
    }

  static String _truncate(String s, [int max = 800]) {
    if (s.length <= max) return s;
    return '${s.substring(0, max)}…(${s.length - max} more)';
  }
}
