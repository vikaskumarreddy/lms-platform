import 'package:flutter/material.dart';

/// The Axisora Forge Academy app logo mark.
///
/// This currently renders a polished, code-drawn wordmark + icon (no image
/// asset exists in the project yet). To swap in a real logo image once one
/// is available, drop the file at `assets/images/logo.png`, add it under
/// `flutter: assets:` in pubspec.yaml, and replace the `Container` below
/// with `Image.asset('assets/images/logo.png', width: size, height: size)`
/// -- everywhere this widget is used (Landing, Splash, Drawer) will then
/// automatically pick up the real logo with no other changes needed.
class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const AppLogo({super.key, this.size = 40, this.showText = true});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFFEAB308)],
              stops: [0.0, 0.55, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEAB308).withOpacity(0.45),
                blurRadius: size * 0.35,
                offset: Offset(0, size * 0.08),
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
            'Axisora',
            style: TextStyle(
              fontSize: size * 0.5,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: 0.2,
              height: 1,
            ),
          ),
          Text(
            'Forge',
            style: TextStyle(
              fontSize: size * 0.5,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFEAB308),
              letterSpacing: 0.2,
              height: 1,
            ),
          ),
        ],
      ],
    );
  }
}
