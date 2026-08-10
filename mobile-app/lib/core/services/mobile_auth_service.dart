import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/auth_user.dart';

/// Mobile authentication service that communicates with the backend
/// to handle login, registration, token persistence, and user profile retrieval.
class MobileAuthService {
  static const String _baseUrl = AppConfig.apiBaseUrl;

  /// The key used to store the JWT token in SharedPreferences.
  static const String _tokenKey = 'access_token';
  static const String _userKey = 'auth_user';
  static const String _userIdKey = 'userId';
  static const String _batchIdKey = 'batchId';

  /// Checks whether the user is currently logged in by verifying
  /// that a non-empty token exists in local storage.
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    return token != null && token.isNotEmpty;
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
      headers: {'Content-Type': 'application/json'},
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
      await prefs.setInt(_batchIdKey, user.batchId!);
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
      headers: {'Content-Type': 'application/json'},
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
    }

    return AuthResponse(token: token, user: user);
  }

  /// Clears all stored auth data, effectively logging the user out.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_userIdKey);
  }
}

/// Simple wrapper returned by [MobileAuthService.login] and
/// [MobileAuthService.register] containing the JWT token and user info.
class AuthResponse {
  final String token;
  final AuthUser user;

  AuthResponse({required this.token, required this.user});
}
