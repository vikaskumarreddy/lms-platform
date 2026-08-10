import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/routes.dart';

/// Global scaffold key used to open the drawer from any screen
final GlobalKey<ScaffoldState> mainScaffoldKey = GlobalKey<ScaffoldState>();

class CommonHeader extends StatelessWidget implements PreferredSizeWidget {
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

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF0F172A),
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
                  context.go(AppRoutes.home);
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
