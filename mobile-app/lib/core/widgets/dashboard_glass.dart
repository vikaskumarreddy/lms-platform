import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DashboardGlassCard extends StatelessWidget {
  final OrgThemeColors theme;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const DashboardGlassCard({super.key, required this.theme, required this.child, this.padding = const EdgeInsets.all(14), this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: theme.surface.withOpacity(.82),
            border: Border.all(color: theme.divider.withOpacity(.8)),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: theme.primary.withOpacity(.12), blurRadius: 16, offset: const Offset(0, 7))],
          ),
          child: child,
        ),
      ),
    );
    return onTap == null ? card : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: card);
  }
}

class DashboardSectionTitle extends StatelessWidget {
  final OrgThemeColors theme;
  final String title;
  final IconData icon;
  final Widget? action;
  const DashboardSectionTitle({super.key, required this.theme, required this.title, required this.icon, this.action});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: theme.accent, size: 19),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800))),
        if (action != null) action!,
      ]);
}

class DashboardStatBadge extends StatelessWidget {
  final OrgThemeColors theme;
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const DashboardStatBadge({super.key, required this.theme, required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 5), decoration: BoxDecoration(color: color.withOpacity(.12), border: Border.all(color: color.withOpacity(.28)), borderRadius: BorderRadius.circular(13)), child: Column(children: [Icon(icon, color: color, size: 19), const SizedBox(height: 5), Text(value, style: TextStyle(color: theme.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)), Text(label, textAlign: TextAlign.center, style: TextStyle(color: theme.textSecondary, fontSize: 9))])));
}
