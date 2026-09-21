import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/org_theme_provider.dart';

/// The organization's app logo mark.
///
/// Rendered as a polished, code-drawn glossy badge (no image asset exists in the
/// project yet) using only the organization's theme colors — no hardcoded brand
/// hex values. To swap in a real logo image once one is available, drop the file
/// at `assets/images/logo.png`, add it under `flutter: assets:` in pubspec.yaml,
/// and replace the `Container` below with `Image.asset(...)` — everywhere this
/// widget is used (Landing, Splash, Login, Drawer) then picks up the real logo.
class AppLogo extends ConsumerWidget {
  final double size;
  final bool showText;
  final String? orgName;

  const AppLogo({super.key, this.size = 40, this.showText = true, this.orgName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(orgThemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = orgName?.trim();
    final label = (name == null || name.isEmpty) ? 'Academy' : name;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [...theme.primaryGradient, theme.accent],
              stops: const [0.0, 0.55, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: [
              BoxShadow(
                color: theme.accentGlow,
                blurRadius: size * 0.35,
                offset: Offset(0, size * 0.08),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.35),
                blurRadius: size * 0.12,
                spreadRadius: -size * 0.08,
                offset: Offset(0, -size * 0.1),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: size * 0.78,
                height: size * 0.78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.25), width: size * 0.03),
                ),
              ),
              Icon(
                Icons.school_rounded,
                color: Colors.white,
                size: size * 0.5,
              ),
            ],
          ),
        ),
        if (showText) ...[
          SizedBox(width: size * 0.3),
          Text(
            label,
            style: TextStyle(
              fontSize: size * 0.42,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : theme.primary,
              letterSpacing: 0.2,
              height: 1,
            ),
          ),
        ],
      ],
    );
  }
}
