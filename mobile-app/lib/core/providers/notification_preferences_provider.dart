import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local notification preferences persisted in SharedPreferences.
/// These are independent of backend notification settings and allow
/// the user to control push notifications, class reminders, assignment
/// alerts, and exam alerts from the app's Settings screen.
class NotificationPreferences {
  final bool pushNotifications;
  final bool classReminders;
  final bool assignmentAlerts;
  final bool examAlerts;

  const NotificationPreferences({
    this.pushNotifications = true,
    this.classReminders = true,
    this.assignmentAlerts = true,
    this.examAlerts = true,
  });

  NotificationPreferences copyWith({
    bool? pushNotifications,
    bool? classReminders,
    bool? assignmentAlerts,
    bool? examAlerts,
  }) {
    return NotificationPreferences(
      pushNotifications: pushNotifications ?? this.pushNotifications,
      classReminders: classReminders ?? this.classReminders,
      assignmentAlerts: assignmentAlerts ?? this.assignmentAlerts,
      examAlerts: examAlerts ?? this.examAlerts,
    );
  }

  factory NotificationPreferences.fromPrefs(SharedPreferences prefs) {
    return NotificationPreferences(
      pushNotifications: prefs.getBool('notif_push') ?? true,
      classReminders: prefs.getBool('notif_reminders') ?? true,
      assignmentAlerts: prefs.getBool('notif_assignments') ?? true,
      examAlerts: prefs.getBool('notif_exams') ?? true,
    );
  }

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setBool('notif_push', pushNotifications);
    await prefs.setBool('notif_reminders', classReminders);
    await prefs.setBool('notif_assignments', assignmentAlerts);
    await prefs.setBool('notif_exams', examAlerts);
  }
}

/// Provider for notification preferences, persisted locally.
final notificationPrefsProvider =
    StateNotifierProvider<NotificationPrefsNotifier, NotificationPreferences>(
        (ref) {
  return NotificationPrefsNotifier();
});

class NotificationPrefsNotifier
    extends StateNotifier<NotificationPreferences> {
  NotificationPrefsNotifier() : super(const NotificationPreferences()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = NotificationPreferences.fromPrefs(prefs);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await state.save(prefs);
  }

  void togglePushNotifications(bool value) {
    state = state.copyWith(pushNotifications: value);
    _save();
  }

  void toggleClassReminders(bool value) {
    state = state.copyWith(classReminders: value);
    _save();
  }

  void toggleAssignmentAlerts(bool value) {
    state = state.copyWith(assignmentAlerts: value);
    _save();
  }

  void toggleExamAlerts(bool value) {
    state = state.copyWith(examAlerts: value);
    _save();
  }
}
