import 'dart:convert';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kakan/core/error/exceptions.dart';
import 'package:kakan/features/youtube/model/video.dart';
import 'package:kakan/features/youtube/model/youtube_home_model.dart';

/// Service for interacting with the YouTube API via RapidAPI.
class YoutubeService {
  final String _apiKey;
  final String _apiHost = 'youtube138.p.rapidapi.com';
  final String _baseUrl = 'https://youtube138.p.rapidapi.com';
  final DefaultCacheManager _cacheManager;
  static const int _maxRetries = 3;
  static const Duration _initialRetryDelay = Duration(seconds: 2);
  static const Duration _cacheDuration = Duration(hours: 1);

  YoutubeService({required DefaultCacheManager cacheManager})
      : _apiKey = dotenv.env['YOUTUBE_API_KEY'] ?? '',
        _cacheManager = cacheManager {
    if (_apiKey.isEmpty) {
      _log('ERROR: YOUTUBE_API_KEY is not set in .env file');
      throw ServerException(message: 'YOUTUBE_API_KEY is not set in .env file');
    }
    _log('INFO: YoutubeService initialized with API key');
  }

  /// Logs messages with a timestamp and log level.
  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    print('[$timestamp] YoutubeService: $message');
  }

  /// Searches for videos based on a query with retry logic and caching.
  /// Returns a list of [Video] objects.
  /// Throws [ServerException] on failure.
  Future<List<Video>> searchVideos(String query) async {
    final cacheKey = 'search_videos_$query';
    _log('INFO: Starting video search for query: $query');
    final cachedFile = await _cacheManager.getFileFromCache(cacheKey);
    if (cachedFile != null && cachedFile.validTill.isAfter(DateTime.now())) {
      _log('INFO: Using cached search results for query: $query');
      try {
        final data = jsonDecode(await cachedFile.file.readAsString());
        final List<dynamic> contents = data['contents'] ?? [];
        _log('INFO: Cached data loaded, found ${contents.length} items');
        final videos = contents
            .where((item) => item['type'] == 'video')
            .map((item) => Video.fromJson(item['video']))
            .toList();
        if (videos.isNotEmpty) {
          _log('INFO: Returning ${videos.length} videos from cache');
          return videos;
        } else {
          _log('WARN: Cached data is empty, fetching fresh data');
        }
      } catch (e) {
        _log('ERROR: Failed to parse cached data for query: $query, error: $e');
      }
    } else {
      _log('INFO: No valid cache found for query: $query');
    }

    final url = Uri.parse('$_baseUrl/search/?q=$query&hl=en&gl=US');
    int attempt = 0;

    while (attempt < _maxRetries) {
      try {
        _log('INFO: Attempt ${attempt + 1} to search videos with query: $query');
        final response = await http.get(url, headers: {
          'X-Rapidapi-Key': _apiKey,
          'X-Rapidapi-Host': _apiHost,
        });
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          _log('DEBUG: Raw API response: $data');
          final List<dynamic> contents = data['contents'] ?? [];
          _log('INFO: Search successful, found ${contents.length} items');
          await _cacheManager.putFile(
            cacheKey,
            utf8.encode(jsonEncode(data)),
            maxAge: _cacheDuration,
          );
          _log('INFO: Cached search results for query: $query');
          final videos = contents
              .where((item) => item['type'] == 'video')
              .map((item) => Video.fromJson(item['video']))
              .toList();
          _log('INFO: Returning ${videos.length} videos from API');
          return videos;
        } else if (response.statusCode == 429) {
          _log('WARN: Rate limit hit (429) on attempt ${attempt + 1}');
          if (attempt < _maxRetries - 1) {
            final delay = _initialRetryDelay * (1 << attempt);
            _log('INFO: Retrying after ${delay.inMilliseconds}ms');
            await Future.delayed(delay);
            attempt++;
            continue;
          }
          throw ServerException(message: 'Rate limit exceeded. Please try again later.');
        } else {
          throw ServerException(message: 'Failed to load videos: ${response.reasonPhrase}');
        }
      } catch (e) {
        _log('ERROR: Search failed on attempt ${attempt + 1}: $e');
        if (e is ServerException && e.message?.contains('Too Many Requests') == true && attempt < _maxRetries - 1) {
          final delay = _initialRetryDelay * (1 << attempt);
          _log('INFO: Retrying after ${delay.inMilliseconds}ms due to rate limit');
          await Future.delayed(delay);
          attempt++;
          continue;
        }
        throw ServerException(message: 'Network error: ${e.toString()}');
      }
    }
    _log('ERROR: Failed to load videos after $_maxRetries attempts');
    throw ServerException(message: 'Failed to load videos after $_maxRetries attempts');
  }

  /// Fetches trending videos for the home screen with retry logic and caching.
  /// Returns a [YoutubeHomeResponse] containing video content.
  /// Throws [ServerException] on failure.
  Future<YoutubeHomeResponse> fetchHomeVideos() async {
    const cacheKey = 'home_videos';
    _log('INFO: Starting fetch of trending videos');
    final cachedFile = await _cacheManager.getFileFromCache(cacheKey);
    if (cachedFile != null && cachedFile.validTill.isAfter(DateTime.now())) {
      _log('INFO: Using cached trending videos');
      try {
        final data = jsonDecode(await cachedFile.file.readAsString());
        _log('INFO: Cached trending videos loaded');
        final response = YoutubeHomeResponse.fromJson(data);
        if (response.contents?.isNotEmpty == true) {
          _log('INFO: Returning cached trending videos');
          return response;
        } else {
          _log('WARN: Cached trending videos are empty, fetching fresh data');
        }
      } catch (e) {
        _log('ERROR: Failed to parse cached trending videos: $e');
      }
    } else {
      _log('INFO: No valid cache found for trending videos');
    }

    final url = Uri.parse('$_baseUrl/trending/?hl=en&gl=US');
    int attempt = 0;

    while (attempt < _maxRetries) {
      try {
        _log('INFO: Attempt ${attempt + 1} to fetch trending videos');
        final response = await http.get(url, headers: {
          'X-Rapidapi-Key': _apiKey,
          'X-Rapidapi-Host': _apiHost,
        });
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          _log('DEBUG: Raw API response: $data');
          _log('INFO: Fetch trending videos successful');
          await _cacheManager.putFile(
            cacheKey,
            utf8.encode(jsonEncode(data)),
            maxAge: _cacheDuration,
          );
          _log('INFO: Cached trending videos');
          return YoutubeHomeResponse.fromJson(data);
        } else if (response.statusCode == 429) {
          _log('WARN: Rate limit hit (429) on attempt ${attempt + 1}');
          if (attempt < _maxRetries - 1) {
            final delay = _initialRetryDelay * (1 << attempt);
            _log('INFO: Retrying after ${delay.inMilliseconds}ms');
            await Future.delayed(delay);
            attempt++;
            continue;
          }
          throw ServerException(message: 'Rate limit exceeded. Please try again later.');
        } else {
          throw ServerException(message: 'Failed to load trending videos: ${response.reasonPhrase}');
        }
      } catch (e) {
        _log('ERROR: Fetch trending videos failed on attempt ${attempt + 1}: $e');
        if (e is ServerException && e.message?.contains('Too Many Requests') == true && attempt < _maxRetries - 1) {
          final delay = _initialRetryDelay * (1 << attempt);
          _log('INFO: Retrying after ${delay.inMilliseconds}ms due to rate limit');
          await Future.delayed(delay);
          attempt++;
          continue;
        }
        throw ServerException(message: 'Network error: ${e.toString()}');
      }
    }
    _log('ERROR: Failed to load trending videos after $_maxRetries attempts');
    throw ServerException(message: 'Failed to load trending videos after $_maxRetries attempts');
  }
}