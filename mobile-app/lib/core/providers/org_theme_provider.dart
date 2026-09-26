import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// The current organization's brand colors, applied as [MaterialApp.theme] /
/// [MaterialApp.darkTheme] so the mobile app matches whatever the tenant picked in
/// the admin-portal's Settings > Theme screen (same `theme` JSON on the Organization).
///
/// Cached to disk so the app already looks right on the very next cold start (before
/// the network call resolves) instead of flashing the default Axisora colors first.
final orgThemeProvider = StateNotifierProvider<OrgThemeNotifier, OrgThemeColors>((ref) {
  return OrgThemeNotifier();
});

class OrgThemeNotifier extends StateNotifier<OrgThemeColors> {
  static const _cacheKey = 'org_theme_json';
  final ApiService _api = ApiService();

  OrgThemeNotifier() : super(OrgThemeColors.defaults()) {
    _loadCached();
  }

  Future<void> _loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        state = OrgThemeColors.fromJson(json.decode(cached) as Map<String, dynamic>);
      }
    } catch (_) {
      // Corrupt cache: keep the built-in defaults, refresh() below will fix it.
    }
  }

  /// Fetches the organization's theme from the backend and applies + caches it.
  /// Call after login (and on app resume) so a theme change made by an admin in
  /// the admin-portal reaches students the next time they open/refresh the app.
  Future<void> refresh() async {
    final theme = await _api.getOrganizationTheme();
    if (theme == null) return;
    state = OrgThemeColors.fromJson(theme);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, json.encode(theme));
    } catch (_) {
      // Non-fatal: the in-memory state is already applied for this session.
    }
  }

  /// Back to the built-in Axisora colors, used on logout so a stale tenant's
  /// theme does not bleed into the next login on a shared device.
  Future<void> reset() async {
    state = OrgThemeColors.defaults();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (_) {}
  }
}

/// The current organization's display name, shown in the shared header.
/// Kept alive (not autoDispose) so the name doesn't flash between screens.
final orgNameProvider = FutureProvider<String>((ref) async {
  final name = await ApiService().getCurrentOrganizationName();
  return (name == null || name.isEmpty) ? 'Axisora' : name;
});

/// The current organization's tenant slug (e.g. "manyasree" or "axisora"),
/// used to resolve tenant URLs across web views and integrations.
final tenantSlugProvider = FutureProvider<String>((ref) async {
  final slug = await ApiService().getCurrentOrganizationSlug();
  return (slug == null || slug.isEmpty) ? 'axisora' : slug;
});
