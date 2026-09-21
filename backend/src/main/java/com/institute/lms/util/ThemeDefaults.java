package com.institute.lms.util;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Default admin-portal theme (CSS custom property values), matching the teal
 * palette baked into {@code admin-portal/src/styles.css}.
 *
 * <p>Existing tenants (e.g. Axisora) have no {@code theme} key in their
 * {@code organizations.settings} JSON, so {@link com.institute.lms.controller.OrganizationController}
 * merges these defaults underneath whatever the tenant has customized — this is what makes
 * theming backward compatible: an org that has never touched its theme renders pixel-identical
 * to before this feature existed.
 */
public final class ThemeDefaults {

    private ThemeDefaults() {
    }

    /** Returns a fresh mutable copy of the built-in teal theme, keyed by CSS variable name (no leading `--`). */
    public static Map<String, String> defaults() {
        Map<String, String> theme = new LinkedHashMap<>();
        theme.put("primary", "#0D9488");
        theme.put("primaryHover", "#0C8A7E");
        theme.put("secondary", "#2DD4BF");
        theme.put("accent", "#D97706");
        theme.put("accentHover", "#B45309");
        theme.put("bg", "#F0FDFA");
        theme.put("surface", "#FFFFFF");
        theme.put("surfaceAlt", "#F8FAFA");
        theme.put("text", "#134E4A");
        theme.put("textSecondary", "#475569");
        theme.put("textMuted", "#64748B");
        theme.put("border", "#5EEAD4");
        theme.put("borderLight", "#E2E8F0");
        theme.put("success", "#16A34A");
        theme.put("warning", "#D97706");
        theme.put("danger", "#DC2626");
        theme.put("info", "#2563EB");
        // Sidebar gradient — kept separate from --primary so a tenant can pick a lighter
        // brand color without their sidebar washing out.
        theme.put("sidebarGradientStart", "#0B7070");
        theme.put("sidebarGradientMid", "#0D9488");
        theme.put("sidebarGradientEnd", "#0A8F84");

        // Mobile app (Flutter student app) brand colors — kept separate from the
        // admin-portal's web palette above because the app has always shipped with a
        // distinct navy/gold identity. Defaults here match the app's previous
        // hardcoded Color(0xFF0F172A)/Color(0xFFEAB308) constants exactly, so an org
        // that never opens the "Mobile App" theme section renders pixel-identical to
        // before this feature existed. AppThemeResolver in the mobile app additionally
        // falls back to the web keys above (primary/accent/bg/...) before these
        // defaults, so a tenant who only customizes the web theme still gets a
        // reasonably matching app without extra steps.
        theme.put("appPrimary", "#0F172A");
        theme.put("appAccent", "#EAB308");
        theme.put("appBackground", "#FDFBF7");
        theme.put("appSurface", "#FFFFFF");
        theme.put("appText", "#1E293B");
        theme.put("appTextSecondary", "#64748B");
        return theme;
    }

    /**
     * The seed theme for manyasree.placements.com — a warm dark/brown-and-orange palette
     * matching the reference "Asset dashboard" design the tenant asked to be onboarded with.
     * Applied once by a migration; the tenant can still further customize it afterwards from
     * Settings, same as any other org.
     */
    public static Map<String, String> manyasreeSeed() {
        Map<String, String> theme = new LinkedHashMap<>();
        theme.put("primary", "#E8792D");
        theme.put("primaryHover", "#D46A22");
        theme.put("secondary", "#F2A65A");
        theme.put("accent", "#E8792D");
        theme.put("accentHover", "#D46A22");
        theme.put("bg", "#241A14");
        theme.put("surface", "#2E2119");
        theme.put("surfaceAlt", "#3A281E");
        theme.put("text", "#F5E9DD");
        theme.put("textSecondary", "#D8BFA8");
        theme.put("textMuted", "#B49A85");
        theme.put("border", "#4A3527");
        theme.put("borderLight", "#3A281E");
        theme.put("success", "#3FB27F");
        theme.put("warning", "#E8B84B");
        theme.put("danger", "#E05555");
        theme.put("info", "#4C8DD9");
        theme.put("sidebarGradientStart", "#1C130E");
        theme.put("sidebarGradientMid", "#241A14");
        theme.put("sidebarGradientEnd", "#2E2119");

        // Mobile app colors reuse the same warm brown/orange identity as the web
        // portal, so a manyasree student sees one consistent brand across both.
        theme.put("appPrimary", "#241A14");
        theme.put("appAccent", "#E8792D");
        theme.put("appBackground", "#2E2119");
        theme.put("appSurface", "#3A281E");
        theme.put("appText", "#F5E9DD");
        theme.put("appTextSecondary", "#D8BFA8");
        return theme;
    }
}
