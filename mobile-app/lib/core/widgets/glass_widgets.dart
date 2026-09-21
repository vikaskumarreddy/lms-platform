import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shared "premium glass" building blocks used across the auth screens (Login,
/// Register, Forgot Password) and anywhere else that wants the frosted-glass /
/// glowing-orb aesthetic. Every color comes from the [OrgThemeColors] passed in —
/// nothing here is a hardcoded brand color.

/// A soft, blurred glowing circle used as ambient background decoration.
class GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  const GlowOrb({super.key, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withOpacity(0.55), color.withOpacity(0.0)],
          ),
        ),
      ),
    );
  }
}

/// A frosted glass card: blurred, translucent, rounded, with a subtle white-hairline
/// border and soft shadow — the container every auth form sits inside.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const GlassPanel({super.key, required this.child, this.padding = const EdgeInsets.all(24)});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.2),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 30, offset: const Offset(0, 14)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A glass-styled text field: soft rounded fill, no harsh outline, themed icon.
class GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final OrgThemeColors theme;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  const GlassField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.theme,
    this.obscureText = false,
    this.keyboardType,
    this.onSubmitted,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      style: TextStyle(color: theme.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.textSecondary),
        prefixIcon: Icon(icon, color: theme.accent, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.55),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.accent, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

/// A glossy gradient primary button: accent-to-darker-accent fill with a soft glow,
/// used for every primary CTA on the auth screens.
class GradientButton extends StatelessWidget {
  final OrgThemeColors theme;
  final bool loading;
  final String label;
  final VoidCallback? onPressed;

  const GradientButton({super.key, required this.theme, required this.loading, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final onAccent = theme.accent.computeLuminance() < 0.5 ? Colors.white : theme.primary;
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [theme.accent, Color.alphaBlend(Colors.black.withOpacity(0.18), theme.accent)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: theme.accentGlow, blurRadius: 18, offset: const Offset(0, 8)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: Center(
              child: loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: onAccent)),
            ),
          ),
        ),
      ),
    );
  }
}

/// The glossy circular logo badge used above the auth-screen glass card — bigger,
/// with a stronger glow than the inline [AppLogo] used in headers/drawers.
class LogoBadge extends StatelessWidget {
  final OrgThemeColors theme;
  final double size;
  const LogoBadge({super.key, required this.theme, this.size = 88});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [...theme.primaryGradient, theme.accent],
          stops: const [0.0, 0.55, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.7), width: 3),
        boxShadow: [
          BoxShadow(color: theme.accentGlow, blurRadius: 30, offset: const Offset(0, 10)),
        ],
      ),
      child: Icon(Icons.school_rounded, color: Colors.white, size: size * 0.48),
    );
  }
}
