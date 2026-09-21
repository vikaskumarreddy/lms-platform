import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/routes.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../providers/org_theme_provider.dart';
import '../utils/avatar_utils.dart';
import 'app_drawer.dart';

/// Global scaffold key used to open the drawer from any screen
final GlobalKey<ScaffoldState> mainScaffoldKey = GlobalKey<ScaffoldState>();

/// Solid navy app bar with a gold notification action and drawer/back access.
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

    @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(orgThemeProvider);
    return AppBar(
      backgroundColor: org.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      leading: _GlassIconButton(
        icon: showBackButton
            ? Icons.arrow_back_ios_new_rounded
            : Icons.menu_rounded,
        color: Colors.white,
        onPressed: () {
          if (showBackButton) {
            if (context.canPop()) {
              context.pop();
            } else {
              final isLoggedIn = ref.read(mobileAuthProvider).isLoggedIn;
              context.go(isLoggedIn ? AppRoutes.home : AppRoutes.login);
            }
          } else {
            mainScaffoldKey.currentState?.openDrawer();
          }
        },
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
      centerTitle: false,
      actions: [
        if (actions != null)
          ...actions!
        else ...[
          _GlassIconButton(
            icon: Icons.notifications_outlined,
            color: Colors.white,
            onPressed:
                onNotificationTap ?? () => context.go(AppRoutes.notifications),
            tooltip: 'Notifications',
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}

/// Circular header action; notifications use the reference gold background.
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final String? tooltip;

  const _GlassIconButton(
      {required this.icon,
      required this.color,
      required this.onPressed,
      this.tooltip});

  @override
  Widget build(BuildContext context) {
    final button = Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
                color: tooltip == 'Notifications'
            ? const Color(0xFFEAB308)
            : Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon,
                color: tooltip == 'Notifications'
                    ? const Color(0xFF0F172A)
                    : color,
                size: 20),
          ),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: button) : button;
  }
}

/// Fixed height of the [GlassHeader] bar itself (excluding the status bar).
const double kGlassHeaderHeight = 64;

/// The shared, fixed screen header: sidebar drawer button on the left, the
/// organization (company) name styled in the middle, and a notification icon +
/// profile avatar on the right. Semi-transparent + blurred so screen content
/// visibly scrolls behind it.
class GlassHeader extends ConsumerWidget {
  /// Optional screen label rendered under the company name (e.g. "Lessons").
  final String? subtitle;
  final bool showBackButton;
  final VoidCallback? onBack;
  const GlassHeader(
      {super.key,
      this.subtitle,
      this.showBackButton = false,
      this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(orgThemeProvider);
    final orgName = ref.watch(orgNameProvider).valueOrNull ?? 'Axisora';
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final name = (profile?['name'] as String?)?.trim();

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.primary.withValues(alpha: .96),
                theme.primary.withValues(alpha: .88),
              ],
            ),
            border: Border(
                bottom:
                    BorderSide(color: Colors.white.withValues(alpha: .12))),
          ),
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          child: SizedBox(
            height: kGlassHeaderHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(children: [
                _HeaderCircleButton(
                  theme: theme,
                  tooltip: showBackButton ? 'Back' : 'Open sidebar',
                  icon: showBackButton
                      ? Icons.arrow_back_ios_new_rounded
                      : Icons.menu_rounded,
                  onPressed: () {
                    if (showBackButton) {
                      if (onBack != null) {
                        onBack!();
                      } else if (context.canPop()) {
                        context.pop();
                      } else {
                        final isLoggedIn =
                            ref.read(mobileAuthProvider).isLoggedIn;
                        context.go(
                            isLoggedIn ? AppRoutes.home : AppRoutes.login);
                      }
                    } else {
                      // Standalone routes own their Scaffold (with the shared
                      // AppDrawer); shell screens fall back to the shell key.
                      final local = Scaffold.maybeOf(context);
                      if (local != null && local.hasDrawer) {
                        local.openDrawer();
                      } else {
                        mainScaffoldKey.currentState?.openDrawer();
                      }
                    }
                  },
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.accent,
                                boxShadow: [
                                  BoxShadow(
                                      color: theme.accent.withValues(alpha: .6),
                                      blurRadius: 6),
                                ]),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              orgName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (subtitle != null && subtitle!.trim().isNotEmpty)
                        Text(subtitle!.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: .65),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2)),
                    ],
                  ),
                ),
                _HeaderCircleButton(
                  theme: theme,
                  tooltip: 'Notifications',
                  icon: Icons.notifications_outlined,
                  filled: true,
                  onPressed: () => context.go(AppRoutes.notifications),
                ),
                const SizedBox(width: 8),
                _ProfileAvatar(name: (name == null || name.isEmpty) ? 'Student' : name),
                const SizedBox(width: 6),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
/// A frosted circular header action; the notification bell keeps the
/// reference gold-style accent fill.
class _HeaderCircleButton extends StatelessWidget {
  final dynamic theme;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool filled;
  const _HeaderCircleButton(
      {required this.theme,
      required this.icon,
      required this.tooltip,
      required this.onPressed,
      this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: filled ? theme.accent : Colors.white.withValues(alpha: .16),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon,
                  size: 20, color: filled ? theme.primary : Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// The right-side profile circle: initials avatar that opens the profile page.
class _ProfileAvatar extends StatelessWidget {
  final String name;
  const _ProfileAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Profile',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => context.go(AppRoutes.profile),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white.withValues(alpha: .16),
          child: Text(
            AvatarUtils.initialsFor(name),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}


/// A Scaffold whose body scrolls BEHIND a fixed [GlassHeader]: the header is
/// overlaid on top while the body's safe-area top inset is inflated by the
/// header height, so the first content lands just below the bar yet keeps
/// scrolling underneath its translucent glass.
class CommonHeaderScaffold extends ConsumerWidget {
  final Widget body;
  final String? subtitle;
  final bool showBackButton;
  final VoidCallback? onBack;
  final Color? backgroundColor;
  final Widget? floatingActionButton;
  const CommonHeaderScaffold(
      {super.key,
      required this.body,
      this.subtitle,
      this.showBackButton = false,
      this.onBack,
      this.backgroundColor,
      this.floatingActionButton});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNavBarHidden = ref.watch(shellNavBarHiddenProvider);
    return Scaffold(
      backgroundColor: backgroundColor ?? const Color(0xFF071D43),
      extendBody: true,
      floatingActionButton: floatingActionButton != null
          ? Padding(
              padding: EdgeInsets.only(bottom: isNavBarHidden ? 68.0 : 88.0),
              child: floatingActionButton,
            )
          : null,
      body: Column(
        children: [
          GlassHeader(
            subtitle: subtitle,
            showBackButton: showBackButton,
            onBack: onBack,
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              removeBottom: true,
              removeLeft: true,
              removeRight: true,
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}
