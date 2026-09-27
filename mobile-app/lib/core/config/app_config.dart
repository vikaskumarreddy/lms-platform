import 'package:flutter/foundation.dart';
import 'env_local.dart';
import 'env_staging.dart';

/// Centralized application configuration.
/// Defaults to [EnvStaging] pointing to the live AWS EC2 server (axisoraforge.in).
///
/// To run against local development backend:
///   flutter run --dart-define=ENV=local
///
/// To run against live AWS EC2 staging backend:
///   flutter run --dart-define=ENV=staging   (or plain 'flutter run')
class AppConfig {
  static const String _env = String.fromEnvironment('ENV', defaultValue: 'staging');

  /// True when running in local development mode.
  static const bool isLocal = _env == 'local';

  /// True when running against staging AWS EC2 backend.
  static const bool isStaging = !isLocal;

  /// Active environment name ('staging' or 'local').
  static String get environmentName => isLocal ? EnvLocal.environmentName : EnvStaging.environmentName;

  /// Host IP / DNS name of the active backend.
  static String get host => isLocal ? EnvLocal.host : EnvStaging.host;

  /// Public web base URL (for web views, certificate verification, and portal redirects).
  static String get webBaseUrl => isLocal ? EnvLocal.webBaseUrl : EnvStaging.webBaseUrl;

  /// Base URL for the backend API.
  /// On Web/PWA running under HTTPS (e.g. Vercel or custom domain), direct HTTP
  /// calls are blocked by browser Mixed Content security rules. When served over
  /// HTTPS, we route API calls to the same origin's /api endpoint which is reverse-proxied
  /// to the backend.
  static String get apiBaseUrl {
    if (kIsWeb) {
      try {
        final origin = Uri.base.origin;
        final scheme = Uri.base.scheme;
        if (scheme == 'https') {
          return '$origin/api';
        }
        if (Uri.base.host.contains('axisoraforge.in')) {
          return 'https://axisoraforge.in/api';
        }
      } catch (_) {}
    }
    return isLocal ? EnvLocal.apiBaseUrl : EnvStaging.apiBaseUrl;
  }

  /// Returns the tenant-scoped web portal URL for the given [tenantSlug].
  /// For example:
  /// - Staging with slug 'manyasree' -> http://manyasree.axisoraforge.in
  /// - Staging with slug 'axisora' (or empty/admin) -> http://axisoraforge.in
  /// - Local dev -> http://localhost (or Android emulator loopback http://10.0.2.2)
  static String tenantWebBaseUrl([String? tenantSlug]) {
    final slug = (tenantSlug ?? '').trim().toLowerCase();
    if (isLocal) {
      return defaultTargetPlatform == TargetPlatform.android
          ? EnvLocal.androidEmulatorWebBaseUrl
          : EnvLocal.webBaseUrl;
    }
    if (slug.isEmpty || slug == 'axisora' || slug == 'admin' || slug == 'www') {
      return EnvStaging.webBaseUrl;
    }
    return EnvStaging.tenantWebUrl(slug);
  }

  /// Official certificate verification URL (publicly viewable / verifiable).
  static String certificateVerifyUrl(String credentialId, [String? tenantSlug]) {
    final base = tenantWebBaseUrl(tenantSlug);
    return '$base/verify/$credentialId';
  }

  /// Returns the full URL to open the Realtime Coding Playground for a question,
  /// preserving the tenant subdomain and passing the tenant parameters.
  static String codeEditorUrl({
    required int questionId,
    required String assessmentType,
    required int assessmentId,
    int? userId,
    String? tenantSlug,
    String? token,
  }) {
    final slug = (tenantSlug ?? '').trim().toLowerCase();
    final baseUrl = tenantWebBaseUrl(slug);
    final params = <String, String>{
      'assessmentType': assessmentType,
      'assessmentId': assessmentId.toString(),
    };
    if (userId != null) {
      params['userId'] = userId.toString();
    }
    if (slug.isNotEmpty) {
      params['tenant'] = slug;
      params['tenantSlug'] = slug;
    }
    if (token != null && token.trim().isNotEmpty) {
      params['token'] = token.trim();
    }
    final query = Uri(queryParameters: params).query;
    return '$baseUrl/code-editor/$questionId?$query';
  }

  /// Payment gateway server-side callback URL.
  static String paymentCallbackUrl(String gateway, String orderId) {
    return '$apiBaseUrl/payments/callback/${gateway.toLowerCase()}/$orderId';
  }
}