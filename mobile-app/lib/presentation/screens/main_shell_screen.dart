import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/routes.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/utils/avatar_utils.dart';
import '../../../core/widgets/common_header.dart';
import '../widgets/modern_bottom_nav_bar.dart';

class MainShellScreen extends ConsumerStatefulWidget {
  final Widget child;
  const MainShellScreen({super.key, required this.child});
  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  final _tabs = [
    (AppRoutes.home, Icons.home_outlined, Icons.home_rounded, 'Home'),
    (AppRoutes.courses, Icons.book_outlined, Icons.menu_book_rounded, 'Courses'),
    (AppRoutes.calendar, Icons.calendar_today_outlined, Icons.calendar_month_rounded, 'Calendar'),
    (AppRoutes.placementDrives, Icons.work_outline_rounded, Icons.work_rounded, 'Placements'),
    (AppRoutes.profile, Icons.person_outline, Icons.person_rounded, 'Profile'),
  ];

  int _getCurrentIndex() {
    final uri = GoRouterState.of(context).uri.toString();
    for (int i = 0; i < _tabs.length; i++) {
      if (uri.startsWith(_tabs[i].$1)) return i;
    }
    return 0;
  }

  bool _isMainTab() {
    final uri = GoRouterState.of(context).uri.toString();
    for (int i = 0; i < _tabs.length; i++) {
      if (uri.startsWith(_tabs[i].$1)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          // If we're on a non-main-tab screen (like Placements, Assignments, etc.)
          // go back to Home
          if (!_isMainTab()) {
            context.go(AppRoutes.home);
          } else {
            // If we're on the Home tab, show exit dialog
            final currentIndex = _getCurrentIndex();
            if (currentIndex != 0) {
              context.go(_tabs[0].$1);
            } else {
              if (context.mounted) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Exit App'),
                    content: const Text('Do you want to exit the app?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          SystemNavigator.pop();
                        },
                        child: const Text('Yes'),
                      ),
                    ],
                  ),
                );
              }
            }
          }
        }
      },
      child: Scaffold(
        key: mainScaffoldKey,
        drawer: _buildDrawer(context),
        body: widget.child,
        bottomNavigationBar: ModernBottomNavBar(
          currentIndex: _getCurrentIndex(),
          tabs: _tabs,
          onTap: (index) => context.go(_tabs[index].$1),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.asData?.value;
    final rawName = (profile?['name'] as String?)?.trim();
    final displayName = (rawName == null || rawName.isEmpty) ? 'Student' : rawName;
    final batchName = (profile?['batchName'] as String?) ?? 'No batch assigned';
    final isActive = profile?['isActive'] != false;
    final primaryColor = const Color(0xFF0F172A);
    final secondaryColor = const Color(0xFFEAB308);
    
    return Drawer(
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primaryColor, primaryColor.withOpacity(0.8)]),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: secondaryColor,
                          child: Text(AvatarUtils.initialsFor(displayName), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(batchName, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: isActive ? secondaryColor : Colors.grey, borderRadius: BorderRadius.circular(12)),
                      child: Text(isActive ? 'Active' : 'Inactive', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _DrawerItem(
                  icon: Icons.home_outlined,
                  title: 'Home',
                  onTap: () {
                    context.go(AppRoutes.home);
                    Navigator.pop(context);
                  },
                ),
                _DrawerItem(
                  icon: Icons.book_outlined,
                  title: 'Courses',
                  onTap: () {
                    context.go(AppRoutes.courses);
                    Navigator.pop(context);
                  },
                ),
                _DrawerItem(
                  icon: Icons.calendar_today_outlined,
                  title: 'Calendar',
                  onTap: () {
                    context.go(AppRoutes.calendar);
                    Navigator.pop(context);
                  },
                ),
                _DrawerItem(
                  icon: Icons.work_outlined,
                  title: 'Placements',
                  onTap: () {
                    context.go(AppRoutes.placementDrives);
                    Navigator.pop(context);
                  },
                ),
                _DrawerItem(
                  icon: Icons.assignment_outlined,
                  title: 'Assignments',
                  onTap: () {
                    context.go(AppRoutes.assignments);
                    Navigator.pop(context);
                  },
                ),

                _DrawerItem(
                  icon: Icons.forum_outlined,
                  title: 'Q&A',
                  onTap: () {
                    context.go(AppRoutes.qa);
                    Navigator.pop(context);
                  },
                ),
                _DrawerItem(
                  icon: Icons.bookmark_outlined,
                  title: 'Bookmarks',
                  onTap: () {
                    context.go(AppRoutes.bookmarks);
                    Navigator.pop(context);
                  },
                ),
                _DrawerItem(
                  icon: Icons.leaderboard_outlined,
                  title: 'Leaderboard',
                  onTap: () {
                    context.go(AppRoutes.leaderboard);
                    Navigator.pop(context);
                  },
                ),
                _DrawerItem(
                  icon: Icons.assignment_outlined,
                  title: 'Exams',
                  onTap: () {
                    context.go(AppRoutes.exams);
                    Navigator.pop(context);
                  },
                ),
                _DrawerItem(
                  icon: Icons.fact_check_outlined,
                  title: 'Attendance',
                  onTap: () {
                    context.go(AppRoutes.attendance);
                    Navigator.pop(context);
                  },
                ),
                _DrawerItem(
                  icon: Icons.workspace_premium_outlined,
                  title: 'Certificates',
                  onTap: () {
                    context.go(AppRoutes.certificates);
                    Navigator.pop(context);
                  },
                ),
                _DrawerItem(
                  icon: Icons.notes_outlined,
                  title: 'Notes',
                  onTap: () {
                    context.go(AppRoutes.notes.replaceAll(':lessonId', '101'));
                    Navigator.pop(context);
                  },
                ),
                _DrawerItem(
                  icon: Icons.description_outlined,
                  title: 'Resume Builder',
                  onTap: () {
                    context.go(AppRoutes.resumeBuilder);
                    Navigator.pop(context);
                  },
                ),
                _DrawerItem(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () {
                    context.go(AppRoutes.settings);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _DrawerItem({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Colors.grey.shade700),
            const SizedBox(width: 16),
            Text(title, style: TextStyle(fontSize: 15, color: Colors.grey.shade800)),
          ],
        ),
      ),
    );
  }
}