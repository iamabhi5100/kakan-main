// // lib/features/youtube/data/piped_service.dart
// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';

// class PipedService {
//   // Keep a few reliable public instances. Order matters (we try top-down).
//   // IMPORTANT: This list intentionally avoids instances that frequently 502 or sit behind strict CF.
//   static const List<String> _instances = [
//     'https://piped.video',                 // main
//     'https://piped.projectsegfau.lt',      // alt
//     'https://piped.video.lunar.icu',       // alt (sometimes strict TLS)
//     'https://piped.privacydev.net',        // alt
//   ];

//   final Duration timeout;
//   final HttpClient _http;

//   PipedService({
//     Duration connectTimeout = const Duration(seconds: 6),
//     Duration readTimeout = const Duration(seconds: 20),
//   })  : timeout = readTimeout,
//         _http = HttpClient()
//           ..connectionTimeout = connectTimeout
//           ..userAgent = 'Kakan/1.0 (+https://example.app)';

//   /// Query /api/v1/streams/{videoId} from the first working instance.
//   /// Returns the raw JSON map with at least one of: "muxedStreams", "videoStreams", "audioStreams".
//   Future<Map<String, dynamic>> getStreams(String videoId) async {
//     final path = '/api/v1/streams/$videoId';
//     for (final base in _instances) {
//       try {
//         final uri = Uri.parse(base).replace(path: path);
//         final json = await _getJson(uri);
//         // Validate it looks like a Piped response (has any stream list)
//         if (json is Map &&
//             (json['muxedStreams'] is List ||
//              json['videoStreams'] is List ||
//              json['audioStreams'] is List)) {
//           return Map<String, dynamic>.from(json);
//         }
//       } on HandshakeException {
//         // TLS mismatch/cert issues on some mirrors; move on to next instance.
//         continue;
//       } on PipedHttpException {
//         // 502 / HTML / not JSON — try next.
//         continue;
//       } catch (_) {
//         // Network flake — try next.
//         continue;
//       }
//     }
//     throw PipedHttpException('All Piped instances failed');
//   }

//   Future<Map<String, dynamic>> _getJson(Uri uri) async {
//     final req = await _http.getUrl(uri);
//     // Encourage JSON
//     req.headers.set(HttpHeaders.acceptHeader, 'application/json');
//     final resp = await req.close().timeout(timeout);
//     final body = await resp.transform(utf8.decoder).join();

//     if (resp.statusCode != 200) {
//       throw PipedHttpException('HTTP ${resp.statusCode} ${resp.reasonPhrase}');
//     }

//     // Some instances reply with HTML (Cloudflare block). Guard it.
//     if (body.startsWith('<!DOCTYPE html>') || body.trimLeft().startsWith('<html')) {
//       throw PipedHttpException('Received HTML instead of JSON');
//     }

//     try {
//       final decoded = jsonDecode(body);
//       if (decoded is Map<String, dynamic>) return decoded;
//       throw const FormatException('JSON root is not an object');
//     } on FormatException catch (e) {
//       throw PipedHttpException('Invalid JSON: $e');
//     }
//   }

//   void close() => _http.close(force: true);
// }

// class PipedHttpException implements Exception {
//   final String message;
//   const PipedHttpException(this.message);
//   @override
//   String toString() => 'PipedHttpException: $message';
// }
