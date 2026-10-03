import 'package:flutter/foundation.dart';
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

class _MainShellScreenState extends ConsumerState<MainShellScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _navAnimController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  double? _arrowTopOffset;

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
    (AppRoutes.interviewHistory, Icons.videocam_outlined, Icons.videocam_rounded, '1-1 Interview'),
    (AppRoutes.feedback, Icons.rate_review_outlined, Icons.rate_review_rounded, 'Feedback'),
    (AppRoutes.companyQuestions, Icons.local_post_office_outlined, Icons.local_activity_rounded, 'Company Q&A'),
    (AppRoutes.qa, Icons.question_answer_outlined, Icons.question_answer_rounded, 'Q & A'),
    ('/notes/0', Icons.note_add_outlined, Icons.note_add_rounded, 'Notes'),
    (AppRoutes.bookmarks, Icons.bookmark_add_outlined, Icons.bookmark_add_rounded, 'BookMarks'),
    (AppRoutes.certificates, Icons.card_membership_outlined, Icons.card_membership_rounded, 'Certificate'),
    (AppRoutes.leaderboard, Icons.leaderboard_outlined, Icons.leaderboard_rounded, 'LeaderBoard'),
    (AppRoutes.settings, Icons.settings_accessibility_outlined, Icons.settings_accessibility_rounded, 'Settings'),
    (AppRoutes.profile, Icons.person_outline, Icons.person_rounded, 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    final initialHidden = ref.read(shellNavBarHiddenProvider);
    _navAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: initialHidden ? 1.0 : 0.0,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(1.15, 0.0),
    ).animate(CurvedAnimation(
      parent: _navAnimController,
      curve: Curves.easeInOutCubic,
    ));
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _navAnimController,
      curve: Curves.easeInOutCubic,
    ));
    _navAnimController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _navAnimController.dispose();
    super.dispose();
  }

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

    ref.listen<bool>(shellNavBarHiddenProvider, (previous, current) {
      if (current) {
        _navAnimController.forward();
      } else {
        _navAnimController.reverse();
      }
    });

    final isVisible = !isNavBarHidden || _navAnimController.value < 1.0;

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
            if (isVisible)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ModernBottomNavBar(
                      currentIndex: _getCurrentIndex(),
                      tabs: _tabs,
                      onTap: (index) => context.go(_tabs[index].$1),
                    ),
                  ),
                ),
              ),
            _buildGestureEdgeArrow(context, isNavBarHidden),
          ],
        ),
        bottomNavigationBar: null,
      ),
    );
  }

  Widget _buildGestureEdgeArrow(BuildContext context, bool isNavBarHidden) {
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    if (keyboardHeight > 0) return const SizedBox.shrink();

    final topPos = _arrowTopOffset ?? (screenHeight * 0.72);

    return Positioned(
      top: topPos,
      right: 0,
      child: Tooltip(
        message: isNavBarHidden ? 'Show Navigation' : 'Hide Navigation',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            key: ValueKey(isNavBarHidden ? 'show-nav-bar-btn' : 'hide-nav-bar-btn'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.lightImpact();
              final isHidden = ref.read(shellNavBarHiddenProvider);
              ref.read(shellNavBarHiddenProvider.notifier).state = !isHidden;
            },
            onVerticalDragUpdate: kIsWeb
                ? null
                : (details) {
                    setState(() {
                      final currentTop = _arrowTopOffset ?? (screenHeight * 0.72);
                      final newTop = currentTop + details.delta.dy;
                      _arrowTopOffset = newTop.clamp(screenHeight * 0.25, screenHeight * 0.82);
                    });
                  },
            onHorizontalDragEnd: kIsWeb
                ? null
                : (details) {
                    final vx = details.primaryVelocity ?? 0;
                    if (vx < -120) {
                      HapticFeedback.lightImpact();
                      ref.read(shellNavBarHiddenProvider.notifier).state = false;
                    } else if (vx > 120) {
                      HapticFeedback.lightImpact();
                      ref.read(shellNavBarHiddenProvider.notifier).state = true;
                    }
                  },
          child: Container(
            width: 30,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFF0C2B64).withValues(alpha: 0.94),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(27),
                bottomLeft: Radius.circular(27),
              ),
              border: Border.all(
                color: const Color(0xFF27D9D3).withValues(alpha: 0.80),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF27D9D3).withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(-2, 2),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 8,
                  offset: const Offset(-1, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.only(left: 3),
            child: RotationTransition(
              turns: Tween<double>(begin: 0.5, end: 0.0).animate(
                CurvedAnimation(
                  parent: _navAnimController,
                  curve: Curves.easeInOutCubic,
                ),
              ),
              child: const Icon(
                Icons.chevron_left_rounded,
                color: Color(0xFF27D9D3),
                size: 26,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }
}
