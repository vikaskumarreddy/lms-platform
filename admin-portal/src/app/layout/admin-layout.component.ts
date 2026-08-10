import { Component, inject } from '@angular/core';
import { RouterOutlet, RouterLink, RouterLinkActive } from '@angular/router';
import { AuthService } from '../services/auth.service';

@Component({
  selector: 'app-admin-layout',
  standalone: true,
  imports: [RouterOutlet, RouterLink, RouterLinkActive],
  template: `
    <div class="sidebar">
      <div class="logo">Axisora Admin</div>
      <a routerLink="/" routerLinkActive="active" [routerLinkActiveOptions]="{exact:true}" class="nav-item">📊 Dashboard</a>
      <a routerLink="/students" routerLinkActive="active" class="nav-item">🎓 Students</a>
      <a routerLink="/batches" routerLinkActive="active" class="nav-item">👥 Batches</a>
      <a routerLink="/courses" routerLinkActive="active" class="nav-item">📚 Courses</a>
      <a routerLink="/faculty" routerLinkActive="active" class="nav-item">👨‍🏫 Faculty</a>
      <a routerLink="/placements" routerLinkActive="active" class="nav-item">💼 Placements</a>
      <a routerLink="/subscriptions-admin" routerLinkActive="active" class="nav-item">⭐ Subscriptions</a>
      <a routerLink="/home-content" routerLinkActive="active" class="nav-item">🏠 Home Content</a>
      <a routerLink="/notifications-admin" routerLinkActive="active" class="nav-item">🔔 Notifications</a>
      <a routerLink="/events-admin" routerLinkActive="active" class="nav-item">🎉 Events</a>
      <a routerLink="/bookmarks-admin" routerLinkActive="active" class="nav-item">🔖 Bookmarks</a>
      <a routerLink="/calendar-events" routerLinkActive="active" class="nav-item">📅 Calendar Events</a>
      <a routerLink="/assignments-admin" routerLinkActive="active" class="nav-item">📝 Assignments</a>
      <a routerLink="/exams-admin" routerLinkActive="active" class="nav-item">📋 Exams</a>
      <a routerLink="/achievements-admin" routerLinkActive="active" class="nav-item">🏆 Achievements</a>
      <a routerLink="/qa-admin" routerLinkActive="active" class="nav-item">💬 Q&A</a>
      <a routerLink="/payments" routerLinkActive="active" class="nav-item">💳 Payments</a>
      <a routerLink="/settings" routerLinkActive="active" class="nav-item">⚙️ Settings</a>
      <a (click)="logout()" class="nav-item" style="margin-top:auto;color:#F87171;">🚪 Logout</a>
    </div>
    <div class="main-content"><router-outlet></router-outlet></div>
  `
})
export class AdminLayoutComponent {
  private auth = inject(AuthService);

  logout() {
    this.auth.logout();
  }
}
