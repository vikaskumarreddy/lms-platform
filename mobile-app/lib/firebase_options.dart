import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'core/config/app_config.dart';

/// Firebase options are no longer hardcoded here. They are fetched at runtime from the
/// admin-configurable backend endpoint (/api/system-config/public/firebase) so credentials
/// can be rotated from the admin portal without shipping a new build. [currentPlatform]
/// is only a placeholder fallback; call [fetchFromBackend] during app startup for the
/// real, admin-managed values.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: 'unconfigured',
      appId: 'unconfigured',
      messagingSenderId: 'unconfigured',
      projectId: 'unconfigured',
    );
  }

  /// Fetches the Firebase config admin-managed via the System Config screen.
  /// Returns null if the backend is unreachable or config hasn't been set yet,
  /// in which case callers should skip Firebase initialization gracefully.
  static Future<FirebaseOptions?> fetchFromBackend() async {
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.apiBaseUrl}/system-config/public/firebase'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      final Map<String, dynamic> data = json.decode(response.body);
      final apiKey = data['apiKey'] as String?;
      final appId = data['appId'] as String?;
      final messagingSenderId = data['messagingSenderId'] as String?;
      final projectId = data['projectId'] as String?;
      if (apiKey == null || apiKey.isEmpty || appId == null || appId.isEmpty) {
        return null;
      }
      return FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId ?? '',
        projectId: projectId ?? '',
      );
    } catch (e) {
      print('Error fetching Firebase config from backend: $e');
      return null;
    }
  }
}
