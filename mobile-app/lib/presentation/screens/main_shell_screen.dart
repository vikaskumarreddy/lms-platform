import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/routes.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/common_header.dart';
import '../../../core/widgets/app_drawer.dart';
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
    (
      AppRoutes.courses,
      Icons.book_outlined,
      Icons.menu_book_rounded,
      'Courses'
    ),
    (
      AppRoutes.placementDrives,
      Icons.work_outline_rounded,
      Icons.work_rounded,
      'Placements'
    ),
    (
      AppRoutes.calendar,
      Icons.calendar_today_outlined,
      Icons.calendar_month_rounded,
      'Calendar'
    ),
    (
    AppRoutes.assignments,
    Icons.assessment_outlined,
    Icons.assessment_rounded,
    'Assignments'
    ),
    (
    AppRoutes.exams,
    Icons.book_online_outlined,
    Icons.book_online_rounded,
    'Exams'
    ),
    (
    AppRoutes.attendance,
    Icons.candlestick_chart_outlined,
    Icons.candlestick_chart_rounded,
    'Attendance'
    ),
    (AppRoutes.companyQuestions, Icons.local_post_office_outlined, Icons.local_activity_rounded, 'Company Q&A'),
    (AppRoutes.qa, Icons.question_answer_outlined, Icons.question_answer_rounded, 'Q & A'),
    ('/notes/0', Icons.note_add_outlined, Icons.note_add_rounded, 'Notes'),
    (AppRoutes.bookmarks, Icons.bookmark_add_outlined, Icons.bookmark_add_rounded, 'BookMarks'),
    (AppRoutes.certificates, Icons.card_membership_outlined, Icons.card_membership_rounded, 'Certificate'),
    (AppRoutes.leaderboard, Icons.leaderboard_outlined, Icons.leaderboard_rounded, 'LeaderBoard'),
    (AppRoutes.settings, Icons.settings_accessibility_outlined, Icons.settings_accessibility_rounded, 'Settings'),
    (AppRoutes.profile, Icons.person_outline, Icons.person_rounded, 'Profile'),
  ];

  int _getCurrentIndex() {
    final uri = GoRouterState.of(context).uri.toString();
    for (int i = 0; i < _tabs.length; i++) {
      final tabRoute = _tabs[i].$1;
      if (tabRoute == '/notes/0' && uri.startsWith('/notes')) return i;
      if (uri.startsWith(tabRoute)) return i;
    }
    return 0;
  }

  bool _isHomeScreen() {
    final uri = GoRouterState.of(context).uri.toString();
    return uri == AppRoutes.home || uri == '/' || uri.startsWith('/home?');
  }

  @override
  Widget build(BuildContext context) {
    final isHome = _isHomeScreen();
    final isNavBarHidden = ref.watch(shellNavBarHiddenProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          if (!isHome) {
            context.go(AppRoutes.home);
          } else {
            if (context.mounted) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Exit App'),
                  content: const Text('Do you want to exit the app?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('No'),
                    ),
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
      },
      child: Scaffold(
        key: mainScaffoldKey,
        backgroundColor: const Color(0xFF071D43),
        extendBody: true,
        drawer: const AppDrawer(),
        body: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (isNavBarHidden)
              Positioned(
                right: 16,
                bottom: 0,
                child: SafeArea(
                  bottom: true,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildShowNavBarButton(),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: isNavBarHidden
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 20, bottom: 4),
                      child: _buildHideNavBarTab(),
                    ),
                  ),
                  ModernBottomNavBar(
                    currentIndex: _getCurrentIndex(),
                    tabs: _tabs,
                    onTap: (index) => context.go(_tabs[index].$1),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildShowNavBarButton() {
    return GestureDetector(
      key: const ValueKey('show-nav-bar-btn'),
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(shellNavBarHiddenProvider.notifier).state = false;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0C2B64).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF27D9D3).withValues(alpha: 0.70),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF27D9D3).withValues(alpha: 0.30),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.keyboard_arrow_up_rounded,
              color: Color(0xFF27D9D3),
              size: 18,
            ),
            SizedBox(width: 6),
            Text(
              'Show Nav',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF27D9D3),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHideNavBarTab() {
    return GestureDetector(
      key: const ValueKey('hide-nav-bar-btn'),
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(shellNavBarHiddenProvider.notifier).state = true;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF092350).withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Hide',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: Color(0xFF27D9D3),
            ),
          ],
        ),
      ),
    );
  }
}
