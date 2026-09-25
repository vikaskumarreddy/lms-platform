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
          return 'http://axisoraforge.in:8080/api';
        }
      } catch (_) {}
    }
    return isLocal ? EnvLocal.apiBaseUrl : EnvStaging.apiBaseUrl;
  }

  /// Official certificate verification URL (publicly viewable / verifiable).
  static String certificateVerifyUrl(String credentialId) {
    return '$webBaseUrl/verify/$credentialId';
  }

  /// Payment gateway server-side callback URL.
  static String paymentCallbackUrl(String gateway, String orderId) {
    return '$apiBaseUrl/payments/callback/${gateway.toLowerCase()}/$orderId';
  }
}