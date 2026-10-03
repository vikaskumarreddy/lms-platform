import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/routes.dart';
import '../providers/data_providers.dart';
import '../providers/org_theme_provider.dart';
import '../providers/router_provider.dart';
import '../utils/avatar_utils.dart';

/// The app-wide sidebar drawer, shared by the main shell AND the standalone
/// routes (courses, modules, lessons, placements, calendar) so the drawer
/// button in [GlassHeader] works on every screen.
class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});
  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  final Set<int> _openCourses = <int>{};
  final Set<int> _openModules = <int>{};
  bool _coursesOpen = false;
  bool _placementsOpen = false;

  static const _cyan = Color(0xFF27D9D3);
  static const _green = Color(0xFF10B981);

  void _go(String route) {
    context.go(route);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final rawName = (profile?['name'] as String?)?.trim();
    final displayName =
        rawName == null || rawName.isEmpty ? 'Student' : rawName;
    final batchName =
        (profile?['batchName'] as String?) ?? 'No batch assigned';
    final isActive = profile?['isActive'] != false;
    final org = ref.watch(orgThemeProvider);
    final mode = ref.watch(themeModeProvider);
    final courses = ref.watch(coursesProvider).asData?.value ?? const [];

    return Drawer(
      backgroundColor: const Color(0xFF071D43),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF051838),
              Color(0xFF071D43),
              Color(0xFF0B2860),
            ],
          ),
        ),
        child: Column(
          children: [
            _DrawerProfile(
              name: displayName,
              batch: batchName,
              active: isActive,
              org: org,
              onTap: () => _go(AppRoutes.profile),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 120),
                children: [
                  _sectionLabel('MAIN'),
                  _drawerItem(
                    icon: Icons.dashboard_rounded,
                    iconColor: const Color(0xFF38BDF8),
                    title: 'Dashboard',
                    route: AppRoutes.home,
                  ),
                  _expandable(
                    icon: Icons.grid_view_rounded,
                    iconColor: const Color(0xFFA855F7),
                    title: 'Courses',
                    open: _coursesOpen,
                    onToggle: () =>
                        setState(() => _coursesOpen = !_coursesOpen),
                    children: courses.isEmpty
                        ? [_childLabel('No courses available')]
                        : courses
                            .map((course) => _courseBranch(course))
                            .toList(),
                  ),
                  _expandable(
                    icon: Icons.work_rounded,
                    iconColor: const Color(0xFF3B82F6),
                    title: 'Placements',
                    open: _placementsOpen,
                    onToggle: () =>
                        setState(() => _placementsOpen = !_placementsOpen),
                    children: [
                      _placementChild('All', 'all', Icons.apps_rounded),
                      _placementChild('Open', 'open', Icons.access_time_rounded),
                      _placementChild('Applied', 'applied', Icons.outgoing_mail),
                      _placementChild('Selected', 'selected',
                          Icons.verified_rounded),
                      _placementChild('Rejected', 'rejected',
                          Icons.cancel_rounded),
                    ],
                  ),
                  _drawerItem(
                    icon: Icons.calendar_month_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Calendar',
                    route: AppRoutes.calendar,
                  ),
                  const SizedBox(height: 10),
                  _sectionLabel('WORKSPACE'),
                  _drawerItem(
                    icon: Icons.assignment_rounded,
                    iconColor: const Color(0xFFEC4899),
                    title: 'Assignments',
                    route: AppRoutes.assignments,
                  ),
                  _drawerItem(
                    icon: Icons.quiz_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    title: 'Exams',
                    route: AppRoutes.exams,
                  ),
                  _drawerItem(
                    icon: Icons.fact_check_rounded,
                    iconColor: const Color(0xFF10B981),
                    title: 'Attendance',
                    route: AppRoutes.attendance,
                  ),
                  _drawerItem(
                    icon: Icons.videocam_rounded,
                    iconColor: const Color(0xFF27D9D3),
                    title: '1-on-1 Mock Interviews',
                    route: AppRoutes.interviewHistory,
                  ),
                  _drawerItem(
                    icon: Icons.rate_review_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Feedback',
                    route: AppRoutes.feedback,
                  ),
                  _drawerItem(
                    icon: Icons.forum_rounded,
                    iconColor: const Color(0xFF06B6D4),
                    title: 'Q&A',
                    route: AppRoutes.qa,
                  ),
                  _drawerItem(
                    icon: Icons.chat_bubble_rounded,
                    iconColor: const Color(0xFF27D9D3),
                    title: 'Batch Community Chat',
                    route: AppRoutes.chat,
                  ),
                  _drawerItem(
                    icon: Icons.help_center_rounded,
                    iconColor: const Color(0xFFEAB308),
                    title: 'Company Questions',
                    route: AppRoutes.companyQuestions,
                  ),
                  _drawerItem(
                    icon: Icons.notes_rounded,
                    iconColor: const Color(0xFF2DD4BF),
                    title: 'Notes',
                    route: AppRoutes.notes.replaceAll(':lessonId', '0'),
                  ),
                  _drawerItem(
                    icon: Icons.bookmark_rounded,
                    iconColor: const Color(0xFFF43F5E),
                    title: 'Bookmarks',
                    route: AppRoutes.bookmarks,
                  ),
                  _drawerItem(
                    icon: Icons.psychology_rounded,
                    iconColor: const Color(0xFF27D9D3),
                    title: 'Daily AI Challenge',
                    route: AppRoutes.dailyChallenge,
                  ),
                  _drawerItem(
                    icon: Icons.leaderboard_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Leaderboard',
                    route: AppRoutes.leaderboard,
                  ),
                  _drawerItem(
                    icon: Icons.workspace_premium_rounded,
                    iconColor: const Color(0xFFFBBF24),
                    title: 'Certificates',
                    route: AppRoutes.certificates,
                  ),
                  const SizedBox(height: 10),
                  _sectionLabel('ACCOUNT'),
                  _drawerItem(
                    icon: Icons.person_rounded,
                    iconColor: const Color(0xFF38BDF8),
                    title: 'Profile',
                    route: AppRoutes.profile,
                  ),
                  _drawerItem(
                    icon: Icons.settings_rounded,
                    iconColor: const Color(0xFF94A3B8),
                    title: 'Settings',
                    route: AppRoutes.settings,
                  ),
                  _drawerItem(
                    icon: Icons.support_agent_rounded,
                    iconColor: const Color(0xFF34D399),
                    title: 'Support',
                    route: AppRoutes.supportRequest,
                  ),
                  const SizedBox(height: 14),
                  _themeToggle(mode),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _courseBranch(dynamic course) {
    final open = _openCourses.contains(course.id);
    final sections =
        ref.watch(courseSectionsProvider(course.id)).asData?.value ?? const [];
    return Column(children: [
      _treeItem(Icons.menu_book_rounded, course.title, open, () {
        setState(() => open
            ? _openCourses.remove(course.id)
            : _openCourses.add(course.id));
        if (!open) _go('/courses/${course.id}');
      }),
      if (open) ...sections.map((section) => _moduleBranch(course.id, section)),
    ]);
  }

  Widget _moduleBranch(int courseId, dynamic module) {
    final open = _openModules.contains(module.id);
    final lessons =
        ref.watch(moduleLessonsProvider(module.id)).asData?.value ?? const [];
    return Padding(
      padding: const EdgeInsets.only(left: 14),
      child: Column(
        children: [
          _treeItem(Icons.folder_rounded, module.title, open, () {
            setState(() => open
                ? _openModules.remove(module.id)
                : _openModules.add(module.id));
            if (!open) _go('/courses/$courseId/sections/${module.id}');
          }),
          if (open)
            ...lessons.map((lesson) => Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: _leafItem(
                    Icons.play_circle_fill_rounded,
                    lesson.title,
                    () => _go('/lesson/${lesson.id}'),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _placementChild(String label, String filter, IconData icon) =>
      _leafItem(icon, label, () => _go('${AppRoutes.placementDrives}?filter=$filter'));

  Widget _expandable({
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool open,
    required VoidCallback onToggle,
    required List<Widget> children,
  }) =>
      Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: open
                    ? const Color(0xFF14457B).withOpacity(0.40)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: open
                    ? Border.all(color: const Color(0xFF1E5BB0).withOpacity(0.35))
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white54,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Container(
              margin: const EdgeInsets.only(left: 20, right: 4, bottom: 6),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: _cyan.withOpacity(0.30),
                    width: 1.4,
                  ),
                ),
              ),
              child: Column(children: children),
            ),
        ],
      );

  Widget _treeItem(
          IconData icon, String title, bool open, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF93C5FD), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                open
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: Colors.white38,
                size: 16,
              ),
            ],
          ),
        ),
      );

  Widget _leafItem(IconData icon, String title, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
          child: Row(
            children: [
              Icon(icon, color: _cyan, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _drawerItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String route,
  }) {
    final isCurrent = GoRouterState.of(context).uri.toString().startsWith(route);
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: InkWell(
        onTap: () => _go(route),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isCurrent
                ? const Color(0xFF14457B).withOpacity(0.50)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: isCurrent
                ? Border.all(color: const Color(0xFF1E5BB0).withOpacity(0.40))
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isCurrent ? Colors.white : Colors.white.withOpacity(0.85),
                    fontSize: 13.5,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _childLabel(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
        ),
      );

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF27D9D3),
            fontSize: 10,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _themeToggle(ThemeMode mode) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F3268).withOpacity(0.60),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1E5BB0).withOpacity(0.40)),
        ),
        child: Row(
          children: [
            Icon(
              mode == ThemeMode.dark
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
              color: const Color(0xFFFBBF24),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mode == ThemeMode.dark ? 'Dark theme' : 'Light theme',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Switch.adaptive(
              value: mode == ThemeMode.dark,
              activeColor: _cyan,
              activeTrackColor: _cyan.withOpacity(0.4),
              onChanged: (value) => ref.read(themeModeProvider.notifier).state =
                  value ? ThemeMode.dark : ThemeMode.light,
            ),
          ],
        ),
      );
}

class _DrawerProfile extends StatelessWidget {
  final String name;
  final String batch;
  final bool active;
  final dynamic org;
  final VoidCallback? onTap;
  const _DrawerProfile({
    required this.name,
    required this.batch,
    required this.active,
    required this.org,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, topPadding + 10, 12, 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F356B), Color(0xFF124385)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E5BB0).withOpacity(0.50)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF38BDF8), Color(0xFF8B5CF6)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withOpacity(0.45),
                      blurRadius: 8,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(2),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF071D43),
                  child: Text(
                    AvatarUtils.initialsFor(name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: active
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            batch,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF93C5FD),
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white60,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row inside [AppDrawer].
class DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const DrawerItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Colors.white70),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}