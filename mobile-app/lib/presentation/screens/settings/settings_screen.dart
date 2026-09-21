import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/common_header.dart';
import '../../../core/constants/routes.dart';
import '../../../core/providers/router_provider.dart';
import '../../../core/providers/notification_preferences_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/avatar_utils.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _bgDark = Color(0xFF071D43);
  static const _cardDark = Color(0xFF0C2B64);
  static const _cyan = Color(0xFF27D9D3);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final prefs = ref.watch(notificationPrefsProvider);
    final authState = ref.watch(mobileAuthProvider);

    return CommonHeaderScaffold(
      subtitle: 'Settings',
      backgroundColor: _bgDark,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          // 1. Account Section
          _sectionHeader('ACCOUNT'),
          Container(
            decoration: BoxDecoration(
              color: _cardDark.withOpacity(0.70),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: const Color(0xFF1E5BB0).withOpacity(0.45)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF38BDF8), Color(0xFF8B5CF6)],
                          ),
                        ),
                        padding: const EdgeInsets.all(2),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFF071D43),
                          child: Text(
                            AvatarUtils.initialsFor(authState.user?.fullName),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authState.user?.fullName ?? 'Student User',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              authState.user?.email ?? '',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF93C5FD),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                InkWell(
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF092350),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: const Text('Logout',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        content: const Text(
                          'Are you sure you want to log out of your account?',
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel',
                                style: TextStyle(color: Colors.white60)),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true && context.mounted) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const Center(
                            child: CircularProgressIndicator(color: _cyan)),
                      );
                      await ref.read(mobileAuthProvider.notifier).logout();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        context.go(AppRoutes.login);
                      }
                    }
                  },
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20)),
                  child: const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded,
                            color: Color(0xFFEF4444), size: 20),
                        SizedBox(width: 12),
                        Text(
                          'Log Out',
                          style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Theme Section
          _sectionHeader('THEME PREFERENCES'),
          Container(
            decoration: BoxDecoration(
              color: _cardDark.withOpacity(0.70),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: const Color(0xFF1E5BB0).withOpacity(0.45)),
            ),
            child: Column(
              children: [
                _switchTile(
                  icon: Icons.dark_mode_rounded,
                  title: 'Dark Mode',
                  subtitle: 'Enable sleek dark theme',
                  value: isDark,
                  onChanged: (val) {
                    ref.read(themeModeProvider.notifier).state =
                        val ? ThemeMode.dark : ThemeMode.light;
                  },
                ),
                const Divider(color: Colors.white12, height: 1),
                _switchTile(
                  icon: Icons.brightness_auto_rounded,
                  title: 'System Theme',
                  subtitle: 'Follow device system appearance',
                  value: themeMode == ThemeMode.system,
                  onChanged: (val) {
                    ref.read(themeModeProvider.notifier).state = val
                        ? ThemeMode.system
                        : (isDark ? ThemeMode.dark : ThemeMode.light);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Notification Preferences
          _sectionHeader('NOTIFICATIONS'),
          Container(
            decoration: BoxDecoration(
              color: _cardDark.withOpacity(0.70),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: const Color(0xFF1E5BB0).withOpacity(0.45)),
            ),
            child: Column(
              children: [
                _switchTile(
                  icon: Icons.notifications_active_rounded,
                  title: 'Push Notifications',
                  subtitle: 'Receive timely learning updates',
                  value: prefs.pushNotifications,
                  onChanged: (val) => ref
                      .read(notificationPrefsProvider.notifier)
                      .togglePushNotifications(val),
                ),
                const Divider(color: Colors.white12, height: 1),
                _switchTile(
                  icon: Icons.alarm_rounded,
                  title: 'Class Reminders',
                  subtitle: 'Alerts 15 mins before scheduled class',
                  value: prefs.classReminders,
                  onChanged: (val) => ref
                      .read(notificationPrefsProvider.notifier)
                      .toggleClassReminders(val),
                ),
                const Divider(color: Colors.white12, height: 1),
                _switchTile(
                  icon: Icons.assignment_turned_in_rounded,
                  title: 'Assignment Alerts',
                  subtitle: 'Notified on new assignments and due dates',
                  value: prefs.assignmentAlerts,
                  onChanged: (val) => ref
                      .read(notificationPrefsProvider.notifier)
                      .toggleAssignmentAlerts(val),
                ),
                const Divider(color: Colors.white12, height: 1),
                _switchTile(
                  icon: Icons.quiz_rounded,
                  title: 'Exam Alerts',
                  subtitle: 'Reminders for upcoming test windows',
                  value: prefs.examAlerts,
                  onChanged: (val) => ref
                      .read(notificationPrefsProvider.notifier)
                      .toggleExamAlerts(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. About Section
          _sectionHeader('ABOUT APP'),
          Container(
            decoration: BoxDecoration(
              color: _cardDark.withOpacity(0.70),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: const Color(0xFF1E5BB0).withOpacity(0.45)),
            ),
            padding: const EdgeInsets.all(16),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: Color(0xFF93C5FD), size: 22),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LMS Student Mobile App',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Version 1.0.0 (Production Build)',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: _cyan,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF104476).withOpacity(0.60),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _cyan, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: _cyan,
            activeTrackColor: _cyan.withOpacity(0.35),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
