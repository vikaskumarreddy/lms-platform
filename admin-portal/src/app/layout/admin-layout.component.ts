import { Component, inject, OnInit } from '@angular/core';
import { RouterOutlet, RouterLink, RouterLinkActive } from '@angular/router';
import { AuthService } from '../services/auth.service';
import { ApiService } from '../services/api.service';
import { ToastHostComponent } from '../components/toast-host.component';

@Component({
  selector: 'app-admin-layout',
  standalone: true,
  imports: [RouterOutlet, RouterLink, RouterLinkActive, ToastHostComponent],
  template: `
    <div class="sidebar">
      <div class="logo">
        <span class="logo-icon">🎓</span>
        <span>{{ orgName || 'Axisora' }}</span>
      </div>

      <!-- PLATFORM MENU (placements.com) — dedicated super-admin workspace.
           Rendered only for ADMIN users on the platform root domain. -->
      @if (isPlatform && auth.isAdmin) {
        <a routerLink="/" routerLinkActive="active" [routerLinkActiveOptions]="{exact:true}" class="nav-item">📊 Dashboard</a>
        <a routerLink="/organizations" routerLinkActive="active" class="nav-item">🏢 Organizations</a>

        <div class="nav-group">Billing &amp; Plans</div>
        <a routerLink="/org-subscriptions" routerLinkActive="active" class="nav-item">⭐ Platform Plans</a>
        <a routerLink="/platform-addons" routerLinkActive="active" class="nav-item">🧩 Add-ons</a>
        <a routerLink="/platform-billing" routerLinkActive="active" class="nav-item">
          🧾 Subscriptions
          @if (pendingApprovals > 0) {
            <span class="nav-badge">{{ pendingApprovals }}</span>
          }
        </a>

        <div class="nav-group">Platform</div>
        <a routerLink="/payments" routerLinkActive="active" class="nav-item">💳 Payments</a>
        <a routerLink="/notifications-admin" routerLinkActive="active" class="nav-item">🔔 Notifications</a>
        <a routerLink="/settings" routerLinkActive="active" class="nav-item">⚙️ Settings</a>
      } @else if (auth.isInstructor) {
        <!-- INSTRUCTOR MENU — batch-scoped teaching workflows only.
             Instructors cannot manage organizations, org subscriptions,
             batches, faculty, or subscriptions. -->
        <a routerLink="/" routerLinkActive="active" [routerLinkActiveOptions]="{exact:true}" class="nav-item">📊 Dashboard</a>
        <a routerLink="/students" routerLinkActive="active" class="nav-item">🎓 Students</a>
        <a routerLink="/courses" routerLinkActive="active" class="nav-item">📚 Courses</a>
        <a routerLink="/placements" routerLinkActive="active" class="nav-item">💼 Placements</a>
        <a routerLink="/notifications-admin" routerLinkActive="active" class="nav-item">🔔 Notifications</a>
        <a routerLink="/events-admin" routerLinkActive="active" class="nav-item">🎉 Events</a>
        <a routerLink="/calendar-events" routerLinkActive="active" class="nav-item">📅 Calendar Events</a>
        <a routerLink="/assignments-admin" routerLinkActive="active" class="nav-item">📝 Assignments</a>
        <a routerLink="/exams-admin" routerLinkActive="active" class="nav-item">📋 Exams</a>
        <a routerLink="/grading-admin" routerLinkActive="active" class="nav-item">✅ Grading</a>
        <a routerLink="/attendance-admin" routerLinkActive="active" class="nav-item">🗓️ Attendance</a>
        <a routerLink="/certificates-admin" routerLinkActive="active" class="nav-item">🎓 Certificates</a>
        <a routerLink="/qa-admin" routerLinkActive="active" class="nav-item">💬 Q&A</a>
        <a routerLink="/settings" routerLinkActive="active" class="nav-item">⚙️ Settings</a>
      } @else {
        <!-- TENANT MENU (axisora.placements.com, manyasree.placements.com, ...) -->
        <a routerLink="/" routerLinkActive="active" [routerLinkActiveOptions]="{exact:true}" class="nav-item">📊 Dashboard</a>
        <a routerLink="/students" routerLinkActive="active" class="nav-item">🎓 Students</a>
        <a routerLink="/batches" routerLinkActive="active" class="nav-item">👥 Batches</a>
        <a routerLink="/courses" routerLinkActive="active" class="nav-item">📚 Courses</a>
        <a routerLink="/faculty" routerLinkActive="active" class="nav-item">👨🏫 Faculty</a>
        <a routerLink="/placements" routerLinkActive="active" class="nav-item">💼 Placements</a>
        <a routerLink="/subscriptions-admin" routerLinkActive="active" class="nav-item">⭐ Subscriptions</a>
        <a routerLink="/notifications-admin" routerLinkActive="active" class="nav-item">🔔 Notifications</a>
        <a routerLink="/events-admin" routerLinkActive="active" class="nav-item">🎉 Events</a>
        <a routerLink="/bookmarks-admin" routerLinkActive="active" class="nav-item">🔖 Bookmarks</a>
        <a routerLink="/calendar-events" routerLinkActive="active" class="nav-item">📅 Calendar Events</a>
        <a routerLink="/assignments-admin" routerLinkActive="active" class="nav-item">📝 Assignments</a>
        <a routerLink="/exams-admin" routerLinkActive="active" class="nav-item">📋 Exams</a>
        <a routerLink="/grading-admin" routerLinkActive="active" class="nav-item">✅ Grading</a>
        <a routerLink="/attendance-admin" routerLinkActive="active" class="nav-item">🗓️ Attendance</a>
        <a routerLink="/certificates-admin" routerLinkActive="active" class="nav-item">🎓 Certificates</a>
        <a routerLink="/qa-admin" routerLinkActive="active" class="nav-item">💬 Q&A</a>
        <a routerLink="/payments" routerLinkActive="active" class="nav-item">💳 Payments</a>

        <!-- The tenant's own subscription surface: plan, usage, add-ons, billing.
             Shown to organization admins regardless of hostname, since in dev every
             host resolves to the platform domain. -->
        <a routerLink="/account" routerLinkActive="active" class="nav-item">
          🧾 Account
          @if (accountNeedsAttention) {
            <span class="nav-badge nav-badge-alert">!</span>
          }
        </a>
        <a routerLink="/settings" routerLinkActive="active" class="nav-item">⚙️ Settings</a>
      }

      <a (click)="logout()" class="nav-item" style="margin-top:auto;color:#F87171;">🚪 Logout</a>
    </div>
    <div class="main-content">
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
  `,
  styles: [`
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

  /** Current organization name (tenant context). Falls back to "Axisora" on the platform. */
  orgName = '';

  /** Banner shown above every page when the subscription needs attention. */
  subscriptionNotice: {
    severity: string; title: string; message: string; actionLabel: string; code: string;
  } | null = null;

  /** Puts an alert dot on the Account menu item. */
  accountNeedsAttention = false;

  /** Count of tenant requests waiting on the platform team. */
  pendingApprovals = 0;

  ngOnInit() {
    // Resolve the current tenant's org name so the sidebar reads "<orgName> Admin".
    // On the platform root (placements.com) there is no tenant, so this stays empty
    // and the logo falls back to "Axisora Admin".
    this.api.get<any>('/api/organizations/current').subscribe({
      next: (org) => {
        if (org && org.name) this.orgName = org.name;
      },
      error: () => {}
    });

    if (this.isPlatform && this.auth.isAdmin) {
      this.loadPendingApprovals();
    } else {
      this.loadSubscriptionNotice();
    }
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
