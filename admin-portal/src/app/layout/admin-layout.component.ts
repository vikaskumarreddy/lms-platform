import { Component, inject, OnInit } from '@angular/core';
import { RouterOutlet, RouterLink, RouterLinkActive } from '@angular/router';
import { AuthService } from '../services/auth.service';
import { ApiService } from '../services/api.service';
import { CurrentOrgService } from '../services/current-org.service';
import { ThemeService } from '../services/theme.service';
import { ToastHostComponent } from '../components/toast-host.component';
import { ConfirmDialogComponent } from '../components/confirm-dialog.component';
import { AdminNotificationsComponent } from '../components/admin-notifications.component';
import { MenuItem, MenuSection, PLATFORM_SECTIONS, INSTRUCTOR_SECTIONS, TENANT_SECTIONS } from './admin-layout-menu';

/** Maps a menu item id to the single emoji shown when the sidebar is collapsed to icon-only. */
const COLLAPSED_ICONS: Record<string, string> = {
  dashboard: '📊', organizations: '🏢', 'org-subscriptions': '⭐', 'platform-addons': '🧩',
  'platform-billing': '🧾', payments: '💳', 'notifications-admin': '🔔', settings: '⚙️',
  students: '🎓', courses: '📚', placements: '💼', 'events-admin': '🎉', 'calendar-events': '📅',
  'assignments-admin': '📝', 'exams-admin': '📋', 'grading-admin': '✅', 'attendance-admin': '🗓️',
  'certificates-admin': '🎓', 'qa-admin': '💬', 'company-questions': '🏢', 'media-hub': '🎬',
  'leaderboard-admin': '🏆', 'daily-attendance': '🗓️', batches: '👥', faculty: '👨‍🏫',
  'subscriptions-admin': '⭐', 'bookmarks-admin': '🔖', 'payment-settings': '⚙️', account: '🧾',
  'theme-settings': '🎨'
};

@Component({
  selector: 'app-admin-layout',
  standalone: true,
  imports: [RouterOutlet, RouterLink, RouterLinkActive, ToastHostComponent, ConfirmDialogComponent, AdminNotificationsComponent],
  template: `
    <div class="sidebar" [class.collapsed]="collapsed">
      <div class="logo">
        <span class="logo-icon">🎓</span>
        @if (!collapsed) { <span>{{ orgName || 'Axisora' }}</span> }
        <button type="button" class="collapse-toggle" (click)="toggleCollapsed()"
              [attr.aria-label]="collapsed ? 'Expand sidebar' : 'Collapse sidebar'" [title]="collapsed ? 'Expand' : 'Collapse'">
        {{ collapsed ? '»' : '«' }}
      </button>
      </div>


      @for (section of menuSections; track $index) {
        @if (section.groupLabel && !collapsed) {
          <div class="nav-group">{{ section.groupLabel }}</div>
        }
        @for (item of visibleItems(section.items); track item.id) {
          <a [routerLink]="item.route" routerLinkActive="active" [routerLinkActiveOptions]="{exact: !!item.exact}"
             class="nav-item" [class.icon-only]="collapsed" [title]="collapsed ? item.label : ''">
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

      <a (click)="logout()" class="nav-item" [class.icon-only]="collapsed" [title]="collapsed ? 'Logout' : ''" style="margin-top:auto;color:#F87171;">
        <span class="nav-icon">🚪</span>
        @if (!collapsed) { <span class="nav-label">Logout</span> }
      </a>
    </div>
    <div class="main-content" [class.sidebar-collapsed]="collapsed">
      <!-- Top header bar with Organization title, user role, and notification bell -->
      <div class="admin-top-bar">
        <div class="admin-top-left">
          <span class="admin-top-org">{{ orgName || 'Axisora LMS' }}</span>
          <span class="role-pill">
            {{ auth.isInstructor ? '👨‍🏫 Faculty Portal' : (isPlatform ? '🛡️ Platform Admin' : '🏛️ Academy Admin') }}
          </span>
        </div>
        <div class="admin-top-right">
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
  `,
  styles: [`
    .admin-top-bar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 10px 0 16px;
      margin-bottom: 8px;
      border-bottom: 1px solid var(--border-light, #E2E8F0);
    }
    .admin-top-left {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .admin-top-org {
      font-size: 17px;
      font-weight: 700;
      color: var(--text, #0F172A);
    }
    .role-pill {
      font-size: 11px;
      font-weight: 700;
      padding: 3px 10px;
      border-radius: 999px;
      background: var(--surface-alt, #F1F5F9);
      color: var(--primary, #4F46E5);
      border: 1px solid var(--border-light, #CBD5E1);
    }
    .admin-top-right {
      display: flex;
      align-items: center;
      gap: 12px;
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
      width: 28px; height: 28px; margin: 4px auto 8px;
      background: rgba(255,255,255,.12); color: #fff; border: none; border-radius: 8px;
      cursor: pointer; font-size: 15px; font-weight: 700; transition: background .2s ease;
    }
    .collapse-toggle:hover { background: rgba(255,255,255,.22); }

    /* Icon-only nav items when the sidebar is collapsed: centered icon, tooltip via title attr. */
    .sidebar.collapsed { width: 72px; }
    .sidebar.collapsed .logo { justify-content: center; padding: 0 0 16px; }
    .nav-item.icon-only { justify-content: center; padding: 12px; margin: 2px auto; width: 44px; }
    .nav-item.icon-only .nav-icon { font-size: 20px; }
    .nav-icon { display: inline-flex; align-items: center; justify-content: center; width: 20px; }
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
  `]
})
export class AdminLayoutComponent implements OnInit {
  auth = inject(AuthService);
  private api = inject(ApiService);
  private currentOrg = inject(CurrentOrgService);
  private theme = inject(ThemeService);

  /** Current organization name (tenant context). Falls back to "Axisora" on the platform. */
  orgName = '';

  /** Icon-only sidebar, remembered per-browser so a collapse choice survives navigation/reload. */
  collapsed = localStorage.getItem('sidebar_collapsed') === '1';

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

  ngOnInit() {
    // Resolve the current tenant's org (name + category) so the sidebar reads
    // "<orgName> Admin" and category-specific menu items (e.g. Daily Attendance
    // for schools) can be filtered in. On the platform root (placements.com)
    // there is no tenant, so this stays empty/OTHER and nothing extra shows.
    this.currentOrg.load();
    this.api.get<any>('/api/organizations/current').subscribe({
      next: (org) => {
        if (org && org.name) this.orgName = org.name;
        // Applies the tenant's saved theme (or the teal defaults for an org that never
        // customized one) so every page — including this layout's own sidebar/banner —
        // repaints in the org's brand colors immediately after login.
        if (org && org.theme) this.theme.apply(org.theme);
      },
      error: () => {}
    });

    if (this.isPlatform && this.auth.isAdmin) {
      this.loadPendingApprovals();
    } else {
      this.loadSubscriptionNotice();
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
