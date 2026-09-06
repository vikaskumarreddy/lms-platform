import '../config/app_config.dart';

/// Resolves a possibly-relative image/media URL to an absolute one the app can
/// load (e.g. `Image.network`). Self-hosted uploads and admin-set images are
/// often stored relative to the backend origin, so they need that origin
/// prepended before they can be fetched from the device.
String resolveMediaUrl(String url) {
  if (url.isEmpty) return url;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  final origin = Uri.parse(AppConfig.apiBaseUrl).origin;
  if (url.startsWith('/api/')) return '$origin$url';
  return '$origin$url';
}