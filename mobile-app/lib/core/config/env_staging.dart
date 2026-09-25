/// Staging / Production environment configuration.
/// Points to the live cloud instance at axisoraforge.in.
class EnvStaging {
  static const String environmentName = 'staging';

  /// The root domain (no subdomain) — used for the main platform / super admin.
  static const String rootDomain = 'axisoraforge.in';

  /// Backend API accessed directly on port 8080.
  /// In production with HTTPS/Nginx proxy this will become https://api.axisoraforge.in/api
  static const String host = 'axisoraforge.in';
  static const String port = '8080';

  /// Live API base URL.
  /// The backend is proxied through Nginx at the root domain on port 8080.
  static const String apiBaseUrl = 'http://axisoraforge.in:8080/api';

  /// Live Admin / Web Portal base URL.
  static const String webBaseUrl = 'http://axisoraforge.in';

  /// Android emulator URL (identical to host because axisoraforge.in is a public domain).
  static const String androidEmulatorApiBaseUrl = 'http://axisoraforge.in:8080/api';
  static const String androidEmulatorWebBaseUrl = 'http://axisoraforge.in';

  /// Returns the tenant-scoped web portal URL for a given tenant slug.
  /// e.g., tenantWebUrl('axisora')    → http://axisora.axisoraforge.in
  /// e.g., tenantWebUrl('manyasree')  → http://manyasree.axisoraforge.in
  static String tenantWebUrl(String tenantSlug) => 'http://$tenantSlug.$rootDomain';

  /// Public certificate verification URL template.
  static String certificateVerifyUrl(String credentialId) =>
      '$webBaseUrl/verify/$credentialId';
}
