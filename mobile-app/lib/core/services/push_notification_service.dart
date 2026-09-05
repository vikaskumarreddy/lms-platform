import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../../data/models/notification_item.dart';
import '../../presentation/widgets/in_app_notification_overlay.dart';

/// Must match android/app/src/main/AndroidManifest.xml's
/// com.google.firebase.messaging.default_notification_channel_id meta-data.
/// If this channel is never actually created on-device, Android silently
/// drops the title/body of background/killed-state notifications and shows
/// only the bare status-bar icon -- which is exactly the symptom this fixes.
const String _kAndroidChannelId = 'lms_default_channel';
const String _kAndroidChannelName = 'Axisora Forge Academy Notifications';
const String _kAndroidChannelDescription =
    'Announcements, deadline reminders, and updates from Axisora Forge Academy';

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  GoRouter? _router;
  bool _initialized = false;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize(GoRouter router) async {
    _router = router;
    if (_initialized) return;
    _initialized = true;

    try {
      await _initLocalNotifications();

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      // Ensures foreground FCM messages actually surface a system notification
      // (banner/heads-up + sound) on iOS; Android foreground display is handled
      // by our own in-app overlay below, so the local-notification channel is
      // only used for background/terminated delivery there.
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true,
      );

      final token = await messaging.getToken();
      if (token != null) await _registerToken(token);
      messaging.onTokenRefresh.listen(_registerToken);

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      debugPrint('FCM: onMessage listener registered');
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      debugPrint('FCM: onMessageOpenedApp listener registered');

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) _handleNotificationTap(initialMessage);
    } catch (e) {
      if (kDebugMode) print('Push notification init skipped: $e');
    }
  }

  /// Creates the Android notification channel referenced by the manifest's
  /// default_notification_channel_id. Without this explicit creation step,
  /// FCM's background auto-display falls back to a minimal/no-content
  /// notification on Android 8+ (channel must exist before a message using
  /// it ever arrives).
  Future<void> _initLocalNotifications() async {
    const androidChannel = AndroidNotificationChannel(
      _kAndroidChannelId,
      _kAndroidChannelName,
      description: _kAndroidChannelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const androidInit = AndroidInitializationSettings('ic_notification');
    const initSettings = InitializationSettings(android: androidInit);
    await _localNotifications.initialize(initSettings);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
    debugPrint('FCM: Android notification channel "$_kAndroidChannelId" created');
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
    final notification = message.notification;
    final data = message.data;
    final title = notification?.title ?? data['title'] ?? 'Notification';
    final body = notification?.body ?? data['body'] ?? '';
    final type = data['type'] ?? 'info';
    final actionUrl = data['actionUrl'];

    debugPrint('FCM foreground: title=$title, body=$body, type=$type, actionUrl=$actionUrl');

    final item = NotificationItem(
      id: DateTime.now().millisecondsSinceEpoch,
      title: title,
      message: body,
      type: type,
      isRead: false,
      actionUrl: actionUrl,
      createdAt: DateTime.now().toIso8601String(),
      date: data['date'],
      time: data['time'],
      name: data['name'],
      venue: data['venue'],
      criteria: data['criteria'],
      description: data['description'],
    );

    InAppNotificationOverlay.show(item, onAction: () {
      _handleNotificationTap(message);
    });
  }

  void _handleNotificationTap(RemoteMessage message) {
    final actionUrl = message.data['actionUrl'];
    if (actionUrl == null || _router == null) return;
    final uri = Uri.tryParse(actionUrl);
    if (uri == null || uri.host.isNotEmpty) return;
    try {
      _router!.go(uri.path);
    } catch (e) {
      if (kDebugMode) print('Failed to route notification tap: $e');
    }
  }

  Future<void> clearToken() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      if (kDebugMode) print('Failed to clear FCM token: $e');
    }
  }
}