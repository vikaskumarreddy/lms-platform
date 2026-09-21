import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The organization's brand colors, as returned by `GET /api/organizations/current`
/// (its `theme` map — the same JSON the admin-portal's Settings > Theme page writes
/// via `PUT /api/organizations/{id}/theme`, "Mobile App" section: `appPrimary`,
/// `appAccent`, `appBackground`, `appSurface`, `appText`, `appTextSecondary`).
///
/// There are no hardcoded brand colors anywhere in the app: every screen reads these
/// six values (or the derived glass/gradient helpers below, which are pure color math
/// on top of them) through [Theme.of(context)] / [OrgThemeColors.of(context)]. The
/// constants on [AppTheme] only exist as the *fallback values* an org gets before it
/// has ever customized a theme (or if only the web `primary`/`accent`/... keys were
/// set) — they are not referenced directly by any widget.
class OrgThemeColors {
  final Color primary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final Color success;
  final Color error;
  final Color info;

  const OrgThemeColors({
    required this.primary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.success,
    required this.error,
    required this.info,
  });

  factory OrgThemeColors.defaults() => const OrgThemeColors(
        primary: AppTheme.primaryColor,
        accent: AppTheme.accentColor,
        background: AppTheme.backgroundColor,
        surface: AppTheme.surfaceColor,
        textPrimary: AppTheme.textPrimary,
        textSecondary: AppTheme.textSecondary,
        divider: AppTheme.dividerColor,
        success: AppTheme.success,
        error: AppTheme.error,
        info: AppTheme.info,
      );

  /// Builds from the backend's theme map. Prefers the app-specific keys
  /// (`appPrimary`, `appAccent`, ...) an admin sets on the "Mobile App" section of
  /// the Theme settings page; falls back to the shared web keys (`primary`,
  /// `accent`, `bg`, ...) for an org that only customized the web portal, and
  /// finally to the built-in default for that field.
  factory OrgThemeColors.fromJson(Map<String, dynamic>? json) {
    final d = OrgThemeColors.defaults();
    if (json == null) return d;
    Color pick(String appKey, String webKey, Color fallback) {
      final appRaw = json[appKey];
      if (appRaw is String && appRaw.isNotEmpty) {
        final parsed = _parseHex(appRaw);
        if (parsed != null) return parsed;
      }
      final webRaw = json[webKey];
      if (webRaw is String && webRaw.isNotEmpty) {
        final parsed = _parseHex(webRaw);
        if (parsed != null) return parsed;
      }
      return fallback;
    }
    return OrgThemeColors(
      primary: pick('appPrimary', 'primary', d.primary),
      accent: pick('appAccent', 'accent', d.accent),
      background: pick('appBackground', 'bg', d.background),
      surface: pick('appSurface', 'surface', d.surface),
      textPrimary: pick('appText', 'text', d.textPrimary),
      textSecondary: pick('appTextSecondary', 'textSecondary', d.textSecondary),
      divider: pick('appTextSecondary', 'borderLight', d.divider),
      success: pick('success', 'success', d.success),
      error: pick('danger', 'danger', d.error),
      info: pick('info', 'info', d.info),
    );
  }

  static Color? _parseHex(String hex) {
    var value = hex.trim().replaceFirst('#', '');
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8) return null;
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  /// Whether [primary] reads as dark (so overlaid text/icons should default to white).
  bool get isPrimaryDark => primary.computeLuminance() < 0.4;

  /// A readable foreground color for content painted directly on [primary].
  Color get onPrimary => isPrimaryDark ? Colors.white : textPrimary;

  /// A soft frosted-glass fill for panels floating over [primary] (nav bars, headers):
  /// a translucent lift toward white on a dark primary, toward black on a light one —
  /// pure color math, so it always looks right regardless of which brand color is set.
  Color glassOn(Color base, {double opacity = 0.14}) {
    final overlay = isPrimaryDark ? Colors.white : Colors.black;
    return Color.alphaBlend(overlay.withOpacity(opacity), base);
  }

  /// The two-stop gradient used behind headers/nav bars/splash: primary fading into a
  /// slightly deeper shade of itself, for a subtle glossy depth instead of a flat fill.
  List<Color> get primaryGradient => [
        primary,
        Color.alphaBlend(Colors.black.withOpacity(0.22), primary),
      ];

  /// Soft glow color behind the floating accent bubble in the bottom nav / FAB.
  Color get accentGlow => accent.withOpacity(0.45);
}

class AppTheme {
  static const Color primaryColor = Color(0xFF0F172A);
  static const Color accentColor = Color(0xFFEAB308);
  static const Color backgroundColor = Color(0xFFFDFBF7);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color dividerColor = Color(0xFFE2E8F0);
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  /// Unthemed defaults, kept for any call site that has not moved to
  /// [lightThemeFor] yet (equivalent to `lightThemeFor(OrgThemeColors.defaults())`).
  static ThemeData get lightTheme => lightThemeFor(OrgThemeColors.defaults());

  /// Unthemed defaults, kept for any call site that has not moved to
  /// [darkThemeFor] yet (equivalent to `darkThemeFor(OrgThemeColors.defaults())`).
  static ThemeData get darkTheme => darkThemeFor(OrgThemeColors.defaults());

  static ThemeData lightThemeFor(OrgThemeColors c) {
    final primaryColor = c.primary;
    final accentColor = c.accent;
    final backgroundColor = c.background;
    final surfaceColor = c.surface;
    final textPrimary = c.textPrimary;
    final textSecondary = c.textSecondary;
    final dividerColor = c.divider;
    final error = c.error;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: accentColor,
        surface: surfaceColor,
        background: backgroundColor,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: textPrimary,
        onBackground: textPrimary,
        error: error,
        outline: dividerColor,
        primaryContainer: primaryColor.withOpacity(0.1),
        secondaryContainer: accentColor.withOpacity(0.2),
      ),
      scaffoldBackgroundColor: backgroundColor,
      fontFamily: GoogleFonts.inter().fontFamily,
      // Every AppBar in the app is rendered via CommonHeader, which paints its
      // own navy-gold-bordered flexibleSpace; this theme entry is the sane
      // fallback for any stray default AppBar.
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      // The real bottom nav is ModernBottomNavBar (navy bar + gold top
      // border + floating gold bubble for the active tab); this theme is
      // kept as a matching fallback for any stray default BottomNavigationBar.
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: primaryColor,
        selectedItemColor: accentColor,
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: dividerColor, width: 1),
        ),
        margin: const EdgeInsets.only(bottom: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: accentColor.withOpacity(0.12),
        selectedColor: accentColor,
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: primaryColor),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceColor,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primaryColor,
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accentColor,
        linearTrackColor: const Color(0xFFE2E8F0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.inter(color: textSecondary),
        hintStyle: GoogleFonts.inter(color: textSecondary.withOpacity(0.5)),
      ),
      dividerTheme: DividerThemeData(color: dividerColor, thickness: 1),
    );
  }

  static ThemeData darkThemeFor(OrgThemeColors c) {
    final accentColor = c.accent;
    final primaryColor = c.primary;
    final error = c.error;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: Colors.white,
        secondary: accentColor,
        surface: const Color(0xFF1E293B),
        onPrimary: primaryColor,
        onSecondary: Colors.black,
        onSurface: Colors.white,
        error: error,
        outline: const Color(0xFF334155),
        primaryContainer: Colors.white.withOpacity(0.1),
        secondaryContainer: accentColor.withOpacity(0.2),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      fontFamily: GoogleFonts.inter().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: accentColor,
        unselectedItemColor: Colors.white60,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(bottom: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF334155),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.inter(color: Colors.white60),
        hintStyle: GoogleFonts.inter(color: Colors.white38),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: accentColor.withOpacity(0.2),
        selectedColor: accentColor,
        labelStyle: GoogleFonts.inter(fontSize: 12, color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF334155), thickness: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accentColor,
        linearTrackColor: const Color(0xFF334155),
      ),
    );
  }
}
