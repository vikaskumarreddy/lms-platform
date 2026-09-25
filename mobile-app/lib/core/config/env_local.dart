/// Local development environment configuration.
/// Used for local Docker Compose or local backend testing.
class EnvLocal {
  static const String environmentName = 'local';
  static const String host = 'localhost';
  static const String port = '8080';

  /// Local API base URL for Web and Desktop.
  static const String apiBaseUrl = 'http://localhost:8080/api';

  /// Local Web Portal base URL.
  static const String webBaseUrl = 'http://localhost';

  /// Android emulator loopback mapping (10.0.2.2 points to host localhost).
  static const String androidEmulatorApiBaseUrl = 'http://10.0.2.2:8080/api';
  static const String androidEmulatorWebBaseUrl = 'http://10.0.2.2';

  /// Local certificate verification URL template.
  static String certificateVerifyUrl(String credentialId) =>
      '$webBaseUrl/verify/$credentialId';
}
