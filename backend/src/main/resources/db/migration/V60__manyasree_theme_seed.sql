-- Seeds the manyasree.placements.com tenant with the warm brown/orange "Asset
-- dashboard" theme it was onboarded with, while every other organization keeps
-- rendering with the original teal defaults baked into admin-portal/styles.css
-- (OrganizationController.resolveTheme() falls back to ThemeDefaults.defaults()
-- for any org whose settings JSON has no "theme" key at all).
--
-- Matched by slug OR domain so this seeds the tenant regardless of which
-- column the organization was actually registered under.
UPDATE organizations
SET settings = jsonb_set(
    COALESCE(NULLIF(settings, '')::jsonb, '{}'::jsonb),
    '{theme}',
    '{
        "primary": "#E8792D",
        "primaryHover": "#D46A22",
        "secondary": "#F2A65A",
        "accent": "#E8792D",
        "accentHover": "#D46A22",
        "bg": "#241A14",
        "surface": "#2E2119",
        "surfaceAlt": "#3A281E",
        "text": "#F5E9DD",
        "textSecondary": "#D8BFA8",
        "textMuted": "#B49A85",
        "border": "#4A3527",
        "borderLight": "#3A281E",
        "success": "#3FB27F",
        "warning": "#E8B84B",
        "danger": "#E05555",
        "info": "#4C8DD9",
        "sidebarGradientStart": "#1C130E",
        "sidebarGradientMid": "#241A14",
        "sidebarGradientEnd": "#2E2119",
        "appPrimary": "#241A14",
        "appAccent": "#E8792D",
        "appBackground": "#2E2119",
        "appSurface": "#3A281E",
        "appText": "#F5E9DD",
        "appTextSecondary": "#D8BFA8"
    }'::jsonb,
    true
)
WHERE lower(slug) = 'manyasree' OR lower(domain) LIKE 'manyasree.%';
