import { Component, inject, OnInit } from '@angular/core';
import { RouterOutlet, RouterLink, RouterLinkActive } from '@angular/router';
import { AuthService } from '../services/auth.service';
import { ApiService } from '../services/api.service';

@Component({
  selector: 'app-admin-layout',
  standalone: true,
  imports: [RouterOutlet, RouterLink, RouterLinkActive],
  template: `
    <div class="sidebar">
      <div class="logo">{{ orgName || 'Axisora' }} Admin</div>

      <!-- PLATFORM MENU (placements.com) — dedicated super-admin workspace.
           Rendered only for ADMIN users on the platform root domain. -->
      @if (isPlatform && auth.isAdmin) {
        <a routerLink="/" routerLinkActive="active" [routerLinkActiveOptions]="{exact:true}" class="nav-item">📊 Dashboard</a>
        <a routerLink="/organizations" routerLinkActive="active" class="nav-item">🏢 Organizations</a>
        <a routerLink="/org-subscriptions" routerLinkActive="active" class="nav-item">⭐ Org Subscriptions</a>
        <a routerLink="/payments" routerLinkActive="active" class="nav-item">💳 Payments</a>
        <a routerLink="/notifications-admin" routerLinkActive="active" class="nav-item">🔔 Notifications</a>
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
        <a routerLink="/settings" routerLinkActive="active" class="nav-item">⚙️ Settings</a>
      }

      <a (click)="logout()" class="nav-item" style="margin-top:auto;color:#F87171;">🚪 Logout</a>
    </div>
    <div class="main-content"><router-outlet></router-outlet></div>
  `
})
export class AdminLayoutComponent implements OnInit {
  auth = inject(AuthService);
  private api = inject(ApiService);

  /** Current organization name (tenant context). Falls back to "Axisora" on the platform. */
  orgName = '';

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
  }

  /** True on the platform root domain (placements.com), false on tenant subdomains. */
  get isPlatform(): boolean {
    return this.auth.isPlatformDomain;
  }

  logout() {
    this.auth.logout();
  }
}
