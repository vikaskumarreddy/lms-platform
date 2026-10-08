import { Component, inject, OnInit } from '@angular/core';
import { RouterOutlet, RouterLink, RouterLinkActive, Router, NavigationEnd } from '@angular/router';
import { filter } from 'rxjs/operators';
import { AuthService } from '../services/auth.service';
import { ApiService } from '../services/api.service';
import { CurrentOrgService } from '../services/current-org.service';
import { ThemeService } from '../services/theme.service';
import { ToastHostComponent } from '../components/toast-host.component';
import { ConfirmDialogComponent } from '../components/confirm-dialog.component';
import { AdminNotificationsComponent } from '../components/admin-notifications.component';
import { QuotaModalComponent } from '../components/quota-modal.component';
import { MenuItem, MenuSection, PLATFORM_SECTIONS, INSTRUCTOR_SECTIONS, TENANT_SECTIONS } from './admin-layout-menu';

/** Maps a menu item id to the single emoji shown when the sidebar is collapsed to icon-only. */
const COLLAPSED_ICONS: Record<string, string> = {
  dashboard: '📊', organizations: '🏢', 'org-subscriptions': '⭐', 'platform-addons': '🧩',
  'platform-billing': '🧾', payments: '💳', 'notifications-admin': '🔔', settings: '⚙️',
  students: '🎓', courses: '📚', placements: '💼', 'events-admin': '🎉', 'calendar-events': '📅',
  'assignments-admin': '📝', 'exams-admin': '📋', 'grading-admin': '✅', 'attendance-admin': '🗓️',
  'certificates-admin': '🎓', 'qa-admin': '💬', 'company-questions': '🏢', 'coding-challenges': '💻', 'media-hub': '🎬',
  'leaderboard-admin': '🏆', 'daily-attendance': '🗓️', batches: '👥', faculty: '👨‍🏫',
  'subscriptions-admin': '⭐', 'bookmarks-admin': '🔖', 'payment-settings': '⚙️', account: '🧾',
  'theme-settings': '🎨'
};

@Component({
  selector: 'app-admin-layout',
  standalone: true,
  imports: [RouterOutlet, RouterLink, RouterLinkActive, ToastHostComponent, ConfirmDialogComponent, AdminNotificationsComponent, QuotaModalComponent],
  template: `
    @if (mobileOpen) {
      <div class="sidebar-backdrop" (click)="closeMobileMenu()"></div>
    }

    <div class="sidebar" [class.collapsed]="collapsed" [class.mobile-open]="mobileOpen">
      <div class="logo">
        <div class="logo-brand">
          @if (orgLogoUrl && !isPlatform) {
            <img [src]="resolveLogoUrl(orgLogoUrl)" class="sidebar-logo-img" alt="Logo" />
          } @else {
            <span class="logo-icon">{{ isPlatform ? '🛡️' : '🎓' }}</span>
          }
          @if (!collapsed) {
            <span class="logo-title" [title]="isPlatform ? 'Axisora Platform' : (orgName || 'Axisora')">
              {{ isPlatform ? 'Axisora Platform' : (orgName || 'Axisora') }}
            </span>
          }
        </div>
        <button type="button" class="collapse-toggle" (click)="toggleCollapsed()"
              [attr.aria-label]="collapsed ? 'Expand sidebar' : 'Collapse sidebar'" [title]="collapsed ? 'Expand' : 'Collapse'">
          {{ collapsed ? '»' : '«' }}
        </button>
        <button type="button" class="mobile-close-btn" (click)="closeMobileMenu()" aria-label="Close sidebar">
          ✕
        </button>
      </div>

      <div class="sidebar-scroll-area">
        @for (section of menuSections; track $index) {
          @if (section.groupLabel && !collapsed) {
            <div class="nav-group">{{ section.groupLabel }}</div>
          }
          @for (item of visibleItems(section.items); track item.id) {
            <a [routerLink]="item.route" routerLinkActive="active" [routerLinkActiveOptions]="{exact: !!item.exact}"
               class="nav-item" [class.icon-only]="collapsed" [title]="collapsed ? item.label : ''"
               (click)="closeMobileMenu()">
              <span class="nav-icon">{{ iconFor(item) }}</span>
              @if (!collapsed) { <span class="nav-label">{{ labelFor(item) }}</span> }
              @if (item.badge === 'pendingApprovals' && pendingApprovals > 0) {
                <span class="nav-badge">{{ pendingApprovals }}</span>
              }
              @if (item.badge === 'account' && accountNeedsAttention) {
                <span class="nav-badge nav-badge-alert">!</span>
              }
            </a>
          }
        }
      </div>

      <a (click)="logout(); closeMobileMenu()" class="nav-item logout-nav-item" [class.icon-only]="collapsed" [title]="collapsed ? 'Logout' : ''">
        <span class="nav-icon">🚪</span>
        @if (!collapsed) { <span class="nav-label">Logout</span> }
      </a>
    </div>

    <div class="main-content" [class.sidebar-collapsed]="collapsed">
      <!-- Top header bar with Hamburger, Organization title, user role, and notification bell -->
      <div class="admin-top-bar">
        <div class="admin-top-left">
          <button type="button" class="mobile-hamburger-btn" (click)="toggleMobileMenu()" aria-label="Toggle navigation menu" title="Open navigation">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <line x1="3" y1="12" x2="21" y2="12"></line>
              <line x1="3" y1="6" x2="21" y2="6"></line>
              <line x1="3" y1="18" x2="21" y2="18"></line>
            </svg>
          </button>
          <div class="admin-top-titles">
            <span class="admin-top-org" [title]="isPlatform ? 'Axisora Platform' : (orgName || 'Axisora LMS')">
              {{ isPlatform ? 'Axisora Platform' : (orgName || 'Axisora LMS') }}
            </span>
            <span class="role-pill">
              {{ auth.isInstructor ? '👨‍🏫 Faculty Portal' : (isPlatform ? '🛡️ Platform Admin' : '🏛️ Academy Admin') }}
            </span>
          </div>
        </div>
        <div class="admin-top-right">
          @if (!isPlatform) {
            <a routerLink="/register" target="_blank" class="register-header-btn" title="Open Public Student Registration Page">
              <span class="btn-icon">📝</span>
              <span class="reg-btn-text">Registration</span>
              <span class="btn-arrow">↗</span>
            </a>
          }
          <app-admin-notifications></app-admin-notifications>
        </div>
      </div>

      <!-- Read-only / expired banner, shown above every page so a lapsed tenant is not
           left guessing why their changes are refused. -->
      @if (subscriptionNotice) {
        <div class="sub-banner" [class.sub-banner-critical]="subscriptionNotice.severity === 'CRITICAL'">
          <div>
            <strong>{{ subscriptionNotice.title }}</strong>
            <div class="sub-banner-message">{{ subscriptionNotice.message }}</div>
          </div>
          <a routerLink="/account" class="btn btn-primary">{{ subscriptionNotice.actionLabel }}</a>
        </div>
      }
      <router-outlet></router-outlet>
    </div>
    <app-toast-host></app-toast-host>
    <app-confirm-dialog></app-confirm-dialog>
    <app-quota-modal></app-quota-modal>
  `,
  styles: [`
    .sidebar-backdrop {
      position: fixed;
      inset: 0;
      background: rgba(15, 23, 42, 0.65);
      backdrop-filter: blur(2px);
      z-index: 1100;
      animation: fadeInBackdrop 0.2s ease;
    }
    @keyframes fadeInBackdrop {
      from { opacity: 0; }
      to { opacity: 1; }
    }
    .logo {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .logo-brand {
      display: flex;
      align-items: center;
      gap: 8px;
      min-width: 0;
      flex: 1;
    }
    .logo-title {
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      font-weight: 800;
      font-size: 16px;
    }
    .sidebar-scroll-area {
      flex: 1;
      overflow-y: auto;
      overflow-x: hidden;
    }
    .logout-nav-item {
      margin-top: auto;
      color: #F87171 !important;
      cursor: pointer;
    }
    .mobile-hamburger-btn {
      display: none;
      align-items: center;
      justify-content: center;
      width: 38px;
      height: 38px;
      padding: 0;
      border-radius: 8px;
      background: var(--surface-alt, #F1F5F9);
      border: 1px solid var(--border-light, #CBD5E1);
      color: var(--text, #0F172A);
      cursor: pointer;
      flex-shrink: 0;
      transition: background 0.15s ease;
    }
    .mobile-hamburger-btn:hover {
      background: #E2E8F0;
    }
    .mobile-close-btn {
      display: none;
      align-items: center;
      justify-content: center;
      width: 32px;
      height: 32px;
      background: rgba(255, 255, 255, 0.15);
      border: none;
      border-radius: 8px;
      color: #FFFFFF;
      font-size: 16px;
      font-weight: 700;
      cursor: pointer;
      margin-left: auto;
      transition: background 0.2s;
    }
    .mobile-close-btn:hover {
      background: rgba(255, 255, 255, 0.28);
    }
    .admin-top-bar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 10px 0 16px;
      margin-bottom: 8px;
      border-bottom: 1px solid var(--border-light, #E2E8F0);
      gap: 12px;
    }
    .admin-top-left {
      display: flex;
      align-items: center;
      gap: 12px;
      min-width: 0;
      flex: 1;
    }
    .admin-top-titles {
      display: flex;
      align-items: center;
      gap: 10px;
      min-width: 0;
      flex-wrap: wrap;
    }
    .admin-top-org {
      font-size: 17px;
      font-weight: 700;
      color: var(--text, #0F172A);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      max-width: 280px;
    }
    .role-pill {
      font-size: 11px;
      font-weight: 700;
      padding: 3px 10px;
      border-radius: 999px;
      background: var(--surface-alt, #F1F5F9);
      color: var(--primary, #4F46E5);
      border: 1px solid var(--border-light, #CBD5E1);
      white-space: nowrap;
    }
    .admin-top-right {
      display: flex;
      align-items: center;
      gap: 10px;
      flex-shrink: 0;
    }
    .register-header-btn {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 6px 14px;
      border-radius: 8px;
      font-size: 12px;
      font-weight: 600;
      color: var(--primary, #4F46E5);
      background: color-mix(in srgb, var(--primary, #4F46E5) 8%, #ffffff);
      border: 1px solid color-mix(in srgb, var(--primary, #4F46E5) 25%, transparent);
      text-decoration: none;
      transition: all 0.15s ease-in-out;
      white-space: nowrap;
    }
    .register-header-btn:hover {
      background: var(--primary, #4F46E5);
      color: #ffffff;
      box-shadow: 0 4px 12px rgba(79, 70, 229, 0.2);
    }
    .register-header-btn .btn-arrow {
      font-size: 11px;
      opacity: 0.8;
    }
    .nav-group {
      padding: 16px 20px 6px;
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.06em;
      color: rgba(255, 255, 255, 0.4);
    }
    .nav-badge {
      margin-left: auto;
      background: var(--secondary);
      color: #000;
      font-size: 11px;
      font-weight: 700;
      padding: 1px 7px;
      border-radius: 999px;
    }
    .nav-badge-alert { background: #DC2626; color: #fff; }

    /* Collapse toggle: a small pill button pinned under the logo. */
    .collapse-toggle {
      display: flex; align-items: center; justify-content: center;
      width: 28px; height: 28px; margin: 0 0 0 auto;
      background: rgba(255,255,255,.12); color: #fff; border: none; border-radius: 8px;
      cursor: pointer; font-size: 15px; font-weight: 700; transition: background .2s ease;
      flex-shrink: 0;
    }
    .collapse-toggle:hover { background: rgba(255,255,255,.22); }

    /* Icon-only nav items when the sidebar is collapsed: centered icon, tooltip via title attr. */
    .sidebar.collapsed { width: 72px; }
    .sidebar.collapsed .logo { justify-content: center; padding: 0 0 16px; }
    .sidebar-logo-img { width: 28px; height: 28px; object-fit: contain; border-radius: 6px; flex-shrink: 0; }
    .nav-item.icon-only { justify-content: center; padding: 12px; margin: 2px auto; width: 44px; }
    .nav-item.icon-only .nav-icon { font-size: 20px; }
    .nav-icon { display: inline-flex; align-items: center; justify-content: center; width: 20px; flex-shrink: 0; }
    .main-content.sidebar-collapsed { margin-left: 72px; }
    .sub-banner {
      display: flex;
      align-items: center;
      gap: 16px;
      background: #FEF3C7;
      border-left: 4px solid #EAB308;
      color: #78350F;
      padding: 14px 18px;
      border-radius: 10px;
      margin-bottom: 20px;
    }
    .sub-banner-critical { background: #FEE2E2; border-left-color: #DC2626; color: #7F1D1D; }
    .sub-banner-message { font-size: 13px; margin-top: 2px; }
    .sub-banner .btn { margin-left: auto; text-decoration: none; white-space: nowrap; }

    /* Responsive Drawer Styles for < 992px */
    @media (max-width: 991px) {
      .mobile-hamburger-btn { display: inline-flex; }
      .mobile-close-btn { display: inline-flex; }
      .collapse-toggle { display: none !important; }

      .sidebar {
        position: fixed !important;
        left: 0 !important;
        top: 0 !important;
        bottom: 0 !important;
        width: 280px !important;
        max-width: 85vw !important;
        height: 100vh !important;
        transform: translateX(-100%);
        transition: transform 0.28s cubic-bezier(0.4, 0, 0.2, 1) !important;
        z-index: 1200 !important;
        box-shadow: none;
        display: flex !important;
        flex-direction: column !important;
      }
      .sidebar.mobile-open {
        transform: translateX(0) !important;
        box-shadow: 4px 0 35px rgba(0, 0, 0, 0.45) !important;
      }
      .main-content,
      .main-content.sidebar-collapsed {
        margin-left: 0 !important;
        width: 100% !important;
        min-width: 0 !important;
        padding: 16px 14px !important;
      }
      .admin-top-org {
        max-width: 180px;
        font-size: 16px;
      }
    }

    @media (max-width: 580px) {
      .main-content {
        padding: 12px 10px !important;
      }
      .admin-top-bar {
        padding: 6px 0 12px;
      }
      .admin-top-org {
        max-width: 130px;
        font-size: 15px;
      }
      .role-pill {
        font-size: 10px;
        padding: 2px 7px;
      }
      .reg-btn-text {
        display: none;
      }
      .register-header-btn {
        padding: 6px 10px;
      }
      .sub-banner {
        flex-direction: column;
        align-items: flex-start;
      }
      .sub-banner .btn {
        margin-left: 0;
        width: 100%;
        text-align: center;
      }
    }
  `]
})
export class AdminLayoutComponent implements OnInit {
  auth = inject(AuthService);
  private api = inject(ApiService);
  private currentOrg = inject(CurrentOrgService);
  private theme = inject(ThemeService);
  private router = inject(Router);

  /** Current organization name (tenant context). Falls back to "Axisora" on the platform. */
  orgName = '';

  /** Icon-only sidebar, remembered per-browser so a collapse choice survives navigation/reload. */
  collapsed = localStorage.getItem('sidebar_collapsed') === '1';

  /** Mobile drawer open/closed state. */
  mobileOpen = false;

  toggleMobileMenu() {
    this.mobileOpen = !this.mobileOpen;
  }

  closeMobileMenu() {
    this.mobileOpen = false;
  }

  toggleCollapsed() {
    this.collapsed = !this.collapsed;
    localStorage.setItem('sidebar_collapsed', this.collapsed ? '1' : '0');
  }

  /** Single emoji shown for a menu item when the sidebar is collapsed to icon-only. */
  iconFor(item: MenuItem): string {
    return COLLAPSED_ICONS[item.id] || item.label.trim().charAt(0);
  }

  /** The item's label with its leading emoji stripped, since the icon is rendered separately. */
  labelFor(item: MenuItem): string {
    return item.label.replace(/^\S+\s*/, '');
  }

  /** Banner shown above every page when the subscription needs attention. */
  subscriptionNotice: {
    severity: string; title: string; message: string; actionLabel: string; code: string;
  } | null = null;

  /** Puts an alert dot on the Account menu item. */
  accountNeedsAttention = false;

  /** Count of tenant requests waiting on the platform team. */
  pendingApprovals = 0;

  orgLogoUrl = '';

  resolveLogoUrl(url: string | null | undefined): string {
    if (!url) return '';
    if (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('data:')) return url;
    return `${window.location.origin}${url.startsWith('/') ? '' : '/'}${url}`;
  }

  ngOnInit() {
    this.router.events.pipe(
      filter(event => event instanceof NavigationEnd)
    ).subscribe(() => {
      this.closeMobileMenu();
    });

    if (!this.isPlatform) {
      this.currentOrg.load();
      this.api.get<any>('/api/organizations/current').subscribe({
        next: (org) => {
          if (org && org.name) this.orgName = org.name;
          if (org && org.logoUrl) this.orgLogoUrl = org.logoUrl;
          if (org && org.theme) this.theme.apply(org.theme);
        },
        error: () => {}
      });
      this.loadSubscriptionNotice();
    } else {
      this.orgName = 'Axisora Platform';
      if (this.auth.isAdmin) {
        this.loadPendingApprovals();
      }
    }
  }

  /** Menu sections for the current audience (platform / instructor / tenant). */
  get menuSections(): MenuSection[] {
    if (this.isPlatform && this.auth.isAdmin) return PLATFORM_SECTIONS;
    if (this.auth.isInstructor) return INSTRUCTOR_SECTIONS;
    return TENANT_SECTIONS;
  }

  /** Filters a section's items down to those valid for the current org's category. */
  visibleItems(items: MenuItem[]): MenuItem[] {
    const category = this.currentOrg.category();
    return items.filter((item) => !item.categories || item.categories.includes(category));
  }

  /**
   * Loads the tenant's subscription notice.
   *
   * <p>This is why an expired organization no longer presents as a mysteriously empty
   * portal: the notice states plainly that the subscription lapsed, that nothing has
   * been deleted, and what to do next. Failures are swallowed — the banner is helpful
   * context, and an admin who cannot load it should still get their dashboard.
   */
  private loadSubscriptionNotice() {
    this.api.get<any>('/api/account/overview').subscribe({
      next: (data) => {
        if (data?.notice) {
          this.subscriptionNotice = data.notice;
          this.accountNeedsAttention = data.notice.severity !== 'INFO';
        }
      },
      error: () => {}
    });
  }

  private loadPendingApprovals() {
    this.api.get<any[]>('/api/platform/subscriptions/change-requests').subscribe({
      next: (requests) => (this.pendingApprovals = requests?.length ?? 0),
      error: () => {}
    });
  }

  /** True on the platform root domain (placements.com), false on tenant subdomains. */
  get isPlatform(): boolean {
    return this.auth.isPlatformDomain;
  }

  logout() {
    this.auth.logout();
  }
}
