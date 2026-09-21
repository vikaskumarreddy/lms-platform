import 'dart:convert';

import '../../data/models/lesson.dart';

/// Resolve only backend-owned media paths; never attach session credentials
/// to third-party hosts. The backend supports token context for media elements.
String lessonMediaUrl(String value, String apiBaseUrl, {String? token}) {
  final base = Uri.parse(apiBaseUrl);
  final raw = value.trim();
  final uri = raw.startsWith('/api/')
      ? base.resolve(raw)
      : raw.startsWith('/')
          ? Uri.parse('$apiBaseUrl$raw')
          : base.resolve(raw.startsWith('api/') ? '/$raw' : raw);
  if (uri.origin != base.origin) return uri.toString();
  final query = Map<String, String>.from(uri.queryParameters);
  if ((token ?? '').isNotEmpty &&
      (uri.path.startsWith('/api/media/') ||
          uri.path.startsWith('/api/pdf-notes/'))) {
    query['token'] = token!;
  }
  return uri.replace(queryParameters: query.isEmpty ? null : query).toString();
}

String? youtubeVideoId(String value) {
  final raw = value.trim();
  final valid = RegExp(r'^[a-zA-Z0-9_-]{11}$');
  if (valid.hasMatch(raw)) return raw;
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  final host = uri.host.toLowerCase();
  if (host != 'youtu.be' &&
      host != 'youtube.com' &&
      !host.endsWith('.youtube.com') &&
      host != 'youtube-nocookie.com' &&
      !host.endsWith('.youtube-nocookie.com')) return null;
  final id = uri.queryParameters['v'] ??
      (uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '');
  return valid.hasMatch(id) ? id : null;
}

String videoDocument(String url, {bool youtube = false}) {
  final escaped = const HtmlEscape(HtmlEscapeMode.attribute).convert(url);
  return '''<!doctype html><html><head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="referrer" content="${youtube ? 'strict-origin-when-cross-origin' : 'no-referrer'}">
<style>html,body{margin:0;background:#000;height:100%;overflow:hidden}
video,iframe{width:100%;height:100%;border:0;object-fit:contain}</style>
</head><body>${youtube ? '<iframe src="$escaped" allow="autoplay; encrypted-media; picture-in-picture; fullscreen" allowfullscreen></iframe>' : '<video controls playsinline preload="metadata" src="$escaped"></video>'}
<script>
var video=document.querySelector('video');
function report(){if(video && video.error && window.flutter_inappwebview){
window.flutter_inappwebview.callHandler('videoError',video.error.code);}}
if(video)video.addEventListener('error',report);
window.addEventListener('flutterInAppWebViewPlatformReady',report);
</script></body></html>''';
}

/// Everything the lesson player's WebView needs to load [lesson]'s video.
class LessonVideoSource {
  /// The exact URL the WebView loads (absolute; token attached when needed).
  final String url;

  /// True when the URL must render in an iframe (YouTube embed) rather than
  /// a native HTML5 `<video>` element.
  final bool youtube;

  /// Origin of the backend API, used as the WebView's base URL.
  final String origin;

  const LessonVideoSource(
      {required this.url, required this.youtube, required this.origin});
}

/// Resolves the exact URL the lesson player loads for a backend-provided
/// [lesson]:
/// - `videoSource: 'URL'` lessons pointing at YouTube load through a real
///   youtube.com/embed page derived from the lesson's own video id (never a
///   hardcoded placeholder);
/// - backend-owned media (`/api/...` paths, or `videoSource: 'SELF'`) is made
///   absolute against [apiBaseUrl] and gets the student's session `token`
///   appended so the HTML5 `<video>` element passes the backend's
///   tenant/token check (plain browser GETs cannot send an Authorization
///   header);
/// - any other absolute URL is loaded verbatim with no credentials attached.
LessonVideoSource resolveLessonVideoSource(Lesson lesson, String apiBaseUrl,
    {String? token}) {
  final id = youtubeVideoId(lesson.videoUrl);
  final youtube = lesson.videoSource.toUpperCase() != 'SELF' && id != null;
  final origin = Uri.parse(apiBaseUrl).origin;
  final url = youtube
      ? 'https://www.youtube.com/embed/$id?playsinline=1&rel=0&origin=${Uri.encodeComponent(origin)}'
      : lessonMediaUrl(lesson.videoUrl, apiBaseUrl, token: token);
  return LessonVideoSource(url: url, youtube: youtube, origin: origin);
}
