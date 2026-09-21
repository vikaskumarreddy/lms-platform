import { Injectable } from '@angular/core';

/** One theme key per customizable CSS custom property (without the leading `--`). */
export interface ThemeColors {
  primary: string;
  primaryHover: string;
  secondary: string;
  accent: string;
  accentHover: string;
  bg: string;
  surface: string;
  surfaceAlt: string;
  text: string;
  textSecondary: string;
  textMuted: string;
  border: string;
  borderLight: string;
  success: string;
  warning: string;
  danger: string;
  info: string;
  sidebarGradientStart: string;
  sidebarGradientMid: string;
  sidebarGradientEnd: string;
  appPrimary: string;
  appAccent: string;
  appBackground: string;
  appSurface: string;
  appText: string;
  appTextSecondary: string;
  [key: string]: string;
}

/** The built-in teal palette, mirrored from :root in styles.css / backend ThemeDefaults. */
export const DEFAULT_THEME: ThemeColors = {
  primary: '#0D9488',
  primaryHover: '#0C8A7E',
  secondary: '#2DD4BF',
  accent: '#D97706',
  accentHover: '#B45309',
  bg: '#F0FDFA',
  surface: '#FFFFFF',
  surfaceAlt: '#F8FAFA',
  text: '#134E4A',
  textSecondary: '#475569',
  textMuted: '#64748B',
  border: '#5EEAD4',
  borderLight: '#E2E8F0',
  success: '#16A34A',
  warning: '#D97706',
  danger: '#DC2626',
  info: '#2563EB',
  sidebarGradientStart: '#0B7070',
  sidebarGradientMid: '#0D9488',
  sidebarGradientEnd: '#0A8F84',
  appPrimary: '#0F172A',
  appAccent: '#EAB308',
  appBackground: '#FDFBF7',
  appSurface: '#FFFFFF',
  appText: '#1E293B',
  appTextSecondary: '#64748B'
};

/** Ordered, human-labeled groups shown on the Theme settings tab's color pickers. */
export const THEME_FIELD_GROUPS: { title: string; fields: { key: keyof ThemeColors; label: string }[] }[] = [
  {
    title: 'Brand',
    fields: [
      { key: 'primary', label: 'Primary' },
      { key: 'primaryHover', label: 'Primary (hover)' },
      { key: 'secondary', label: 'Secondary' },
      { key: 'accent', label: 'Accent' },
      { key: 'accentHover', label: 'Accent (hover)' }
    ]
  },
  {
    title: 'Surfaces',
    fields: [
      { key: 'bg', label: 'Page background' },
      { key: 'surface', label: 'Card surface' },
      { key: 'surfaceAlt', label: 'Alternate surface' },
      { key: 'border', label: 'Border' },
      { key: 'borderLight', label: 'Border (light)' }
    ]
  },
  {
    title: 'Text',
    fields: [
      { key: 'text', label: 'Primary text' },
      { key: 'textSecondary', label: 'Secondary text' },
      { key: 'textMuted', label: 'Muted text' }
    ]
  },
  {
    title: 'Status colors',
    fields: [
      { key: 'success', label: 'Success' },
      { key: 'warning', label: 'Warning' },
      { key: 'danger', label: 'Danger' },
      { key: 'info', label: 'Info' }
    ]
  },
  {
    title: 'Sidebar gradient',
    fields: [
      { key: 'sidebarGradientStart', label: 'Gradient start' },
      { key: 'sidebarGradientMid', label: 'Gradient middle' },
      { key: 'sidebarGradientEnd', label: 'Gradient end' }
    ]
  },
  {
    title: 'Mobile App',
    fields: [
      { key: 'appPrimary', label: 'App primary (nav/header)' },
      { key: 'appAccent', label: 'App accent (highlights)' },
      { key: 'appBackground', label: 'App background' },
      { key: 'appSurface', label: 'App card surface' },
      { key: 'appText', label: 'App primary text' },
      { key: 'appTextSecondary', label: 'App secondary text' }
    ]
  }
];

/** Maps a ThemeColors key to the CSS custom property it drives, e.g. primaryHover -> --primary-hover. */
function cssVarName(key: string): string {
  return '--' + key.replace(/([A-Z])/g, '-$1').toLowerCase();
}

/** Converts a `#rrggbb` hex color to an `rgba(...)` string at the given alpha, for tinted badge backgrounds. */
function hexToRgba(hex: string, alpha: number): string {
  const clean = hex.replace('#', '');
  if (clean.length !== 6) return hex;
  const r = parseInt(clean.substring(0, 2), 16);
  const g = parseInt(clean.substring(2, 4), 16);
  const b = parseInt(clean.substring(4, 6), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

/**
 * Applies an organization's theme as CSS custom properties on `:root`, so every
 * component that already reads `var(--primary)` etc. (the whole admin-portal design
 * system) repaints without any per-component change.
 *
 * <p>Backward compatible by construction: the backend always returns a *complete*
 * theme map (defaults merged with any tenant overrides — see
 * `OrganizationController.resolveTheme`), so an org that never customized anything
 * re-applies the exact same teal values that were previously hard-coded in styles.css.
 */
@Injectable({ providedIn: 'root' })
export class ThemeService {

  /** Writes every key in `theme` onto `document.documentElement` as a CSS custom property. */
  apply(theme: Partial<ThemeColors> | null | undefined) {
    if (!theme) return;
    const root = document.documentElement.style;
    Object.keys(DEFAULT_THEME).forEach(key => {
      const value = theme[key];
      if (value) {
        root.setProperty(cssVarName(key), value);
      }
    });

    // Badges (--success-bg/--success-text etc.) are not part of the customizable palette —
    // they are derived here so `.badge-success` etc. always contrast correctly against
    // whatever shade the tenant picked for --success/--warning/--danger/--info.
    (['success', 'warning', 'danger', 'info'] as const).forEach(key => {
      const base = theme[key];
      if (!base) return;
      root.setProperty(`--${key}-bg`, hexToRgba(base, 0.16));
      root.setProperty(`--${key}-text`, base);
    });
  }

  /** Resets `:root` back to the built-in teal defaults (used by the Theme tab's Reset button). */
  applyDefaults() {
    this.apply(DEFAULT_THEME);
  }
}
