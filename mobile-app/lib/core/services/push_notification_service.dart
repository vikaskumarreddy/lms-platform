import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import 'app_messenger.dart';

/// Handles the mobile side of push notifications: requesting permission,
/// registering the device's FCM token with the backend (so admin-configured
/// pushes, deadline reminders, class reminders, and interview confirmations
/// can actually reach this device), and routing a tap on a notification to
/// the right in-app screen via `actionUrl`.
///
/// This is intentionally "dumb" about *whether* push is actually enabled --
/// that's entirely controlled by the admin's System Config (firebase.* +
/// push.enabled). If Firebase isn't configured yet, every call here just
/// silently no-ops so the rest of the app is unaffected.
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  GoRouter? _router;
  bool _initialized = false;

  /// Call once after Firebase.initializeApp() succeeds and a router exists.
  Future<void> initialize(GoRouter router) async {
    _router = router;
    if (_initialized) return;
    _initialized = true;

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      // Register/refresh the token now, and whenever Firebase rotates it.
      final token = await messaging.getToken();
      if (token != null) await _registerToken(token);
      messaging.onTokenRefresh.listen(_registerToken);

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // If the app was launched by tapping a notification while terminated.
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) _handleNotificationTap(initialMessage);
    } catch (e) {
      if (kDebugMode) print('Push notification init skipped: $e');
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      final accessToken = prefs.getString('access_token');
      if (userId == null || accessToken == null) return;

      await http.put(
        Uri.parse('${AppConfig.apiBaseUrl}/students/$userId/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({'fcmToken': token}),
      );
    } catch (e) {
      if (kDebugMode) print('Failed to register FCM token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('Foreground push received: ${message.notification?.title}');
    }
    // The OS tray notification is only shown automatically while the app is
    // backgrounded/terminated; in the foreground FCM delivers silently, so
    // surface it ourselves via a SnackBar.
    final title = message.notification?.title;
    final body = message.notification?.body;
    if (title == null && body == null) return;

    final messengerState = rootScaffoldMessengerKey.currentState;
    if (messengerState == null) return;

    final actionUrl = message.data['actionUrl'];
    messengerState.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (body != null) Text(body),
          ],
        ),
        duration: const Duration(seconds: 5),
        action: (actionUrl is String && actionUrl.isNotEmpty)
            ? SnackBarAction(
                label: 'View',
                onPressed: () => _handleNotificationTap(message),
              )
            : null,
      ),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    final actionUrl = message.data['actionUrl'];
    if (actionUrl != null && actionUrl is String && actionUrl.isNotEmpty && _router != null) {
      _router!.go(actionUrl);
    }
  }

  /// Called on logout so a stale token isn't left pointing at a previous user.
  Future<void> clearToken() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      if (kDebugMode) print('Failed to clear FCM token: $e');
    }
  }
}
