import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import 'package:lms_student_app/data/models/notification_item.dart';
import '../../presentation/widgets/in_app_notification_overlay.dart';

bool _isReminderItem(NotificationItem item) =>
    item.type.toLowerCase() == 'reminder' ||
    item.title.toLowerCase().contains('reminder') ||
    (item.actionUrl != null && item.actionUrl!.contains('reminders'));

bool _isPlacementItem(NotificationItem item) =>
    item.type.toLowerCase() == 'placement' ||
    item.title.toLowerCase().contains('placement') ||
    item.title.toLowerCase().contains('drive') ||
    (item.actionUrl != null && item.actionUrl!.contains('placement'));

String _categoryBadgeText(NotificationItem item) {
  if (_isReminderItem(item)) return 'REMINDER';
  if (_isPlacementItem(item)) return 'PLACEMENT DRIVE';
  if (item.type.toLowerCase() == 'exam' || item.title.toLowerCase().contains('exam')) return 'EXAM ALERT';
  if (item.type.toLowerCase() == 'assignment' || item.title.toLowerCase().contains('assignment')) return 'ASSIGNMENT';
  if (item.type.toLowerCase() == 'course' || item.title.toLowerCase().contains('course')) return 'COURSE UPDATE';
  if (item.type.toLowerCase() == 'announcement') return 'ANNOUNCEMENT';
  return 'LMS NOTIFICATION';
}

/// Must match android/app/src/main/AndroidManifest.xml's
/// com.google.firebase.messaging.default_notification_channel_id meta-data.
const String _kAndroidChannelId = 'lms_default_channel';
const String _kAndroidChannelName = 'Axisora Forge Academy Notifications';
const String _kAndroidChannelDescription =
    'Announcements, deadline reminders, and updates from Axisora Forge Academy';

const String _kAndroidReminderChannelId = 'lms_reminder_channel';
const String _kAndroidPlacementChannelId = 'lms_placement_channel';

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
    if (kIsWeb) return; // Push notification and local notification channels are native-only
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

  /// Creates Android notification channels for general updates, personal reminders,
  /// and career/placement alerts with high visibility and custom LED/vibration settings.
  Future<void> _initLocalNotifications() async {
    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    const defaultChannel = AndroidNotificationChannel(
      _kAndroidChannelId,
      _kAndroidChannelName,
      description: _kAndroidChannelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const reminderChannel = AndroidNotificationChannel(
      _kAndroidReminderChannelId,
      'Personal Reminders',
      description: 'Scheduled reminders, alerts, and task deadlines',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color(0xFF27D9D3),
    );

    const placementChannel = AndroidNotificationChannel(
      _kAndroidPlacementChannelId,
      'Placement Drives & Careers',
      description: 'Placement drives, job postings, and interview schedules',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color(0xFF10B981),
    );

    const androidInit = AndroidInitializationSettings('ic_notification');
    final initSettings = const InitializationSettings(android: androidInit);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty && _router != null) {
          final uri = Uri.tryParse(payload);
          if (uri != null && uri.host.isEmpty) {
            try {
              _router!.go(uri.path);
            } catch (e) {
              if (kDebugMode) print('Failed to route notification response tap: $e');
            }
          }
        }
      },
    );

    if (android != null) {
      await android.createNotificationChannel(defaultChannel);
      await android.createNotificationChannel(reminderChannel);
      await android.createNotificationChannel(placementChannel);
      debugPrint('FCM: Android notification channels registered');
    }
  }

  /// Displays an Android system notification banner formatted with BigTextStyle
  /// and category indicators when triggered.
  Future<void> showRichLocalNotification(NotificationItem item) async {
    final isReminder = _isReminderItem(item);
    final isPlacement = _isPlacementItem(item);

    final channelId = isReminder
        ? _kAndroidReminderChannelId
        : isPlacement
            ? _kAndroidPlacementChannelId
            : _kAndroidChannelId;

    final channelName = isReminder
        ? 'Personal Reminders'
        : isPlacement
            ? 'Placement Drives & Careers'
            : _kAndroidChannelName;

    final detailsList = item.detailFields;
    final bigTextBuffer = StringBuffer();
    if (item.message.isNotEmpty) {
      bigTextBuffer.writeln(item.message);
    }
    if (detailsList.isNotEmpty) {
      bigTextBuffer.writeln('');
      for (final entry in detailsList.entries) {
        bigTextBuffer.writeln('• ${entry.key}: ${entry.value}');
      }
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: isReminder
          ? 'Scheduled reminders, alerts, and task deadlines'
          : isPlacement
              ? 'Placement drives, job postings, and interview schedules'
              : _kAndroidChannelDescription,
      importance: isReminder ? Importance.max : Importance.high,
      priority: isReminder ? Priority.max : Priority.high,
      color: const Color(0xFF27D9D3),
      enableLights: true,
      ledColor: const Color(0xFF27D9D3),
      ledOnMs: 1000,
      ledOffMs: 500,
      styleInformation: BigTextStyleInformation(
        bigTextBuffer.toString().trim(),
        contentTitle: item.title,
        summaryText: _categoryBadgeText(item),
      ),
      category: isReminder
          ? AndroidNotificationCategory.reminder
          : isPlacement
              ? AndroidNotificationCategory.recommendation
              : AndroidNotificationCategory.event,
    );

    await _localNotifications.show(
      item.id,
      item.title,
      item.message,
      NotificationDetails(android: androidDetails),
      payload: item.actionUrl,
    );
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
    if (kIsWeb) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      if (kDebugMode) print('Failed to clear FCM token: $e');
    }
  }
}