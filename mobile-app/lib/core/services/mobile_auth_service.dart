import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/auth_user.dart';

/// Mobile authentication service that communicates with the backend
/// to handle login, registration, token persistence, and user profile retrieval.
class MobileAuthService {
  static String get _baseUrl => AppConfig.apiBaseUrl;

  /// The key used to store the JWT token in SharedPreferences.
  static const String _tokenKey = 'access_token';
  static const String _userKey = 'auth_user';
  static const String _userIdKey = 'userId';
  static const String _batchIdKey = 'batchId';
  static const String _tenantSlugKey = 'tenant_slug';

  /// Checks whether the user is currently logged in.
  ///
  /// Previously this only checked that *some* token string was present in
  /// local storage, without verifying it was still valid. That meant a
  /// leftover/expired JWT from a previous session (e.g. after the backend's
  /// signing secret rotated, or the token's expiry passed) would still be
  /// treated as "logged in" on the next app launch, silently dropping the
  /// user into Home without ever re-authenticating. We now also decode the
  /// JWT payload and check its `exp` claim client-side.
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) return false;
    if (_isJwtExpired(token)) {
      // Stale/expired session: clear it so we don't keep re-checking a dead token.
      await logout();
      return false;
    }
    return true;
  }

  /// Decodes a JWT's payload (without verifying the signature, which the
  /// client can't do anyway) and checks whether its `exp` claim has passed.
  /// Returns true (treat as expired) if the token is malformed, to fail safe.
  bool _isJwtExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final normalized = base64Url.normalize(parts[1]);
      final payload = json.decode(utf8.decode(base64Url.decode(normalized))) as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp == null) return false; // No expiry claim: trust the backend to reject it if invalid.
      final expiryMillis = (exp is int ? exp : int.tryParse(exp.toString()) ?? 0) * 1000;
      return DateTime.now().millisecondsSinceEpoch >= expiryMillis;
    } catch (_) {
      return true;
    }
  }

  /// Returns the cached [AuthUser] from local storage, or `null` if not logged in.
  Future<AuthUser?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson == null || userJson.isEmpty) return null;
    try {
      return AuthUser.fromJson(json.decode(userJson) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Logs in with the given [email] and [password].
  /// Returns an [AuthResponse] containing the token and user info, or throws on failure.
  Future<AuthResponse> login(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
      body: json.encode({'email': email, 'password': password}),
    );

    if (response.statusCode != 200) {
      throw Exception('Login failed: ${response.body}');
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    final token = body['accessToken'] ?? '';
    final user = AuthUser.fromJson(body['user'] ?? body);

    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, json.encode(user.toJson()));
    if (user.id != null) {
      await prefs.setInt(_userIdKey, user.id!);
      if (user.batchId != null) {
        await prefs.setInt(_batchIdKey, user.batchId!);
      }
    }
    if (user.tenantSlug != null && user.tenantSlug!.isNotEmpty) {
      await prefs.setString(_tenantSlugKey, user.tenantSlug!.trim().toLowerCase());
    }

    return AuthResponse(token: token, user: user);
  }

  /// Registers a new user account.
  /// Returns an [AuthResponse] containing the token and user info.
  Future<AuthResponse> register(
    String fullName,
    String email,
    String password, [
    String? phone,
  ]) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> payload = {
      'fullName': fullName,
      'email': email,
      'password': password,
    };
    if (phone != null && phone.isNotEmpty) {
      payload['phone'] = phone;
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
      body: json.encode(payload),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Registration failed: ${response.body}');
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    final token = body['accessToken'] ?? '';
    final user = AuthUser.fromJson(body['user'] ?? body);

    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, json.encode(user.toJson()));
    if (user.id != null) {
      await prefs.setInt(_userIdKey, user.id!);
      if (user.batchId != null) {
        await prefs.setInt(_batchIdKey, user.batchId!);
      }
    }
    if (user.tenantSlug != null && user.tenantSlug!.isNotEmpty) {
      await prefs.setString(_tenantSlugKey, user.tenantSlug!.trim().toLowerCase());
    }

    return AuthResponse(token: token, user: user);
  }

  /// Returns the current tenant slug, if stored or associated with the user.
  Future<String?> getTenantSlug() async {
    final prefs = await SharedPreferences.getInstance();
    final slug = prefs.getString(_tenantSlugKey);
    if (slug != null && slug.isNotEmpty) return slug.trim().toLowerCase();
    final user = await getUser();
    return user?.tenantSlug?.trim().toLowerCase();
  }

  /// Clears all stored auth data, effectively logging the user out.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    // Best-effort: notify the backend about logout (token still available here).
    // Even if this fails, the local clear below guarantees the user is logged out.
    try {
      final token = prefs.getString(_tokenKey);
      if (token != null && token.isNotEmpty) {
        await http.post(
          Uri.parse('$_baseUrl/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }
    } catch (_) {
      // Ignore — local clear is what actually matters
    }

    // Clear ALL data from SharedPreferences — nuclear option that guarantees
    // no stale auth tokens survive an app restart.
    await prefs.clear();
  }
}

/// Simple wrapper returned by [MobileAuthService.login] and
/// [MobileAuthService.register] containing the JWT token and user info.
class AuthResponse {
  final String token;
  final AuthUser user;

  AuthResponse({required this.token, required this.user});
}
