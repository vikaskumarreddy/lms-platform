import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/routes.dart';
import '../providers/auth_provider.dart';

/// Global scaffold key used to open the drawer from any screen
final GlobalKey<ScaffoldState> mainScaffoldKey = GlobalKey<ScaffoldState>();

class CommonHeader extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;
  final List<Widget>? actions;

  const CommonHeader({
    super.key,
    required this.title,
    this.showBackButton = false,
    this.onNotificationTap,
    this.onProfileTap,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  static const Color _primary = Color(0xFF0F172A);
  static const Color _accent = Color(0xFFEAB308);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      // Matches the bottom nav bar's navy-with-gold-border treatment so the
      // whole app reads as one cohesive shell: a gold accent line "book-ends"
      // the screen content at both the top (header) and bottom (nav bar).
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_primary, Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border(bottom: BorderSide(color: _accent, width: 2.5)),
        ),
      ),
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  // Fall back to a route appropriate for the current auth state.
                  // Previously this always went to Home, which meant pressing
                  // back with an empty navigation stack (e.g. on the Login
                  // screen after a fresh app start) would silently drop an
                  // unauthenticated user straight into the authenticated Home
                  // screen instead of the Landing/Login flow.
                  final isLoggedIn = ref.read(mobileAuthProvider).isLoggedIn;
                  context.go(isLoggedIn ? AppRoutes.home : AppRoutes.login);
                }
              },
            )
          : IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () {
                mainScaffoldKey.currentState?.openDrawer();
              },
            ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
      centerTitle: true,
      actions: [
        if (actions != null)
          ...actions!
        else ...[
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              if (onNotificationTap != null) {
                onNotificationTap!();
              } else {
                context.go(AppRoutes.notifications);
              }
            },
            tooltip: 'Notifications',
          ),
          IconButton(
            icon: const Icon(Icons.person_outlined, color: Colors.white),
            onPressed: () {
              if (onProfileTap != null) {
                onProfileTap!();
              } else {
                context.go(AppRoutes.profile);
              }
            },
            tooltip: 'Profile',
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}
