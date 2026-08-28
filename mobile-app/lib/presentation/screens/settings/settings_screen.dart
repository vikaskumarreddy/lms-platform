import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/common_header.dart';
import '../../../core/providers/router_provider.dart';
import '../../../core/providers/notification_preferences_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/avatar_utils.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final prefs = ref.watch(notificationPrefsProvider);
    final authState = ref.watch(mobileAuthProvider);
    final secondaryColor = const Color(0xFFEAB308);

    return Scaffold(
      appBar: const CommonHeader(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account section
          Card(child: Column(children: [
            ListTile(
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF0F172A),
                child: Text(
                  AvatarUtils.initialsFor(authState.user?.fullName),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              title: Text(authState.user?.fullName ?? 'Student User', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(authState.user?.email ?? ''),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () => ref.read(mobileAuthProvider.notifier).logout(),
            ),
          ])),
          const SizedBox(height: 20),

          // Theme section
          Card(child: Column(children: [
            SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: const Text('Enable dark theme'),
              value: isDark,
              activeColor: secondaryColor,
              onChanged: (value) {
                ref.read(themeModeProvider.notifier).state = value ? ThemeMode.dark : ThemeMode.light;
              },
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('System Theme'),
              subtitle: const Text('Follow system settings'),
              value: themeMode == ThemeMode.system,
              activeColor: secondaryColor,
              onChanged: (value) {
                ref.read(themeModeProvider.notifier).state = value ? ThemeMode.system : (isDark ? ThemeMode.dark : ThemeMode.light);
              },
            ),
          ])),
          const SizedBox(height: 20),

          // Notification preferences (persisted locally)
          Card(child: Column(children: [
            SwitchListTile(
              title: const Text('Push Notifications'),
              subtitle: const Text('Receive push notifications'),
              value: prefs.pushNotifications,
              activeColor: secondaryColor,
              onChanged: (value) => ref.read(notificationPrefsProvider.notifier).togglePushNotifications(value),
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Class Reminders'),
              subtitle: const Text('Get reminded before classes'),
              value: prefs.classReminders,
              activeColor: secondaryColor,
              onChanged: (value) => ref.read(notificationPrefsProvider.notifier).toggleClassReminders(value),
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Assignment Alerts'),
              subtitle: const Text('New assignment notifications'),
              value: prefs.assignmentAlerts,
              activeColor: secondaryColor,
              onChanged: (value) => ref.read(notificationPrefsProvider.notifier).toggleAssignmentAlerts(value),
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Exam Alerts'),
              subtitle: const Text('Exam schedule notifications'),
              value: prefs.examAlerts,
              activeColor: secondaryColor,
              onChanged: (value) => ref.read(notificationPrefsProvider.notifier).toggleExamAlerts(value),
            ),
          ])),
          const SizedBox(height: 20),

          // About section
          Card(child: Column(children: [
            ListTile(leading: const Icon(Icons.info_outline), title: const Text('App Version'), subtitle: const Text('1.0.0')),
          ])),
        ],
      ),
    );
  }
}
