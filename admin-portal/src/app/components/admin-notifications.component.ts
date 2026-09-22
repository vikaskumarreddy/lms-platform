import { Component, inject, OnInit, OnDestroy, HostListener, ElementRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { ApiService } from '../services/api.service';

export interface AdminNotification {
  id: number;
  title: string;
  message: string;
  type: string;
  isRead: boolean;
  actionUrl?: string;
  createdAt?: string;
  targetType?: string;
  targetId?: number;
}

@Component({
  selector: 'app-admin-notifications',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="notifications-wrapper">
      <!-- Bell Button -->
      <button type="button"
              class="bell-btn"
              (click)="toggleDropdown($event)"
              [attr.aria-expanded]="isOpen"
              title="Notifications">
        <span class="bell-icon">🔔</span>
        <span *ngIf="unreadCount > 0" class="unread-badge">
          {{ unreadCount > 99 ? '99+' : unreadCount }}
        </span>
      </button>

      <!-- Dropdown Panel -->
      <div *ngIf="isOpen" class="dropdown-panel" (click)="$event.stopPropagation()">
        <!-- Header -->
        <div class="panel-header">
          <div class="panel-title-area">
            <span class="panel-title">Notifications</span>
            <span *ngIf="unreadCount > 0" class="new-pill">{{ unreadCount }} new</span>
          </div>
          <div class="panel-actions">
            <button *ngIf="unreadCount > 0"
                    type="button"
                    class="mark-all-btn"
                    (click)="markAllAsRead()">
              Mark all read
            </button>
            <button type="button" class="close-btn" (click)="closeDropdown()">✕</button>
          </div>
        </div>

        <!-- Notification List -->
        <div class="notifications-list">
          <div *ngIf="loading && notifications.length === 0" class="empty-state">
            Loading notifications...
          </div>

          <div *ngIf="!loading && notifications.length === 0" class="empty-state">
            <span class="empty-icon">🔕</span>
            <p class="empty-text">No notifications yet</p>
            <span class="empty-sub">You're all caught up!</span>
          </div>

          <div *ngFor="let notif of notifications"
               class="notif-item"
               [class.unread]="!notif.isRead"
               (click)="onNotificationClick(notif)">
            <div class="notif-icon-col">
              <span class="type-icon">{{ getIcon(notif.type) }}</span>
            </div>
            <div class="notif-content-col">
              <div class="notif-top">
                <span class="notif-title">{{ notif.title }}</span>
                <span *ngIf="!notif.isRead" class="unread-dot"></span>
              </div>
              <p class="notif-message">{{ notif.message }}</p>
              <div class="notif-meta">
                <span class="type-badge" [ngClass]="notif.type">{{ notif.type.toUpperCase() }}</span>
                <span *ngIf="notif.createdAt" class="notif-time">{{ formatTimeAgo(notif.createdAt) }}</span>
              </div>
            </div>
          </div>
        </div>

        <!-- Footer -->
        <div class="panel-footer" *ngIf="notifications.length > 0">
          <span class="footer-tip">🔔 Instant updates enabled</span>
        </div>
      </div>
    </div>
  `,
  styles: [`
    .notifications-wrapper {
      position: relative;
      display: inline-flex;
      align-items: center;
    }

    .bell-btn {
      position: relative;
      background: rgba(255, 255, 255, 0.08);
      border: 1px solid rgba(255, 255, 255, 0.15);
      border-radius: 10px;
      width: 38px;
      height: 38px;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      transition: all 0.2s ease;
      color: inherit;
    }
    .bell-btn:hover {
      background: rgba(255, 255, 255, 0.16);
      transform: translateY(-1px);
    }
    .bell-icon {
      font-size: 18px;
    }

    .unread-badge {
      position: absolute;
      top: -4px;
      right: -4px;
      background: #EF4444;
      color: #FFFFFF;
      font-size: 10px;
      font-weight: 700;
      padding: 1px 5px;
      min-width: 16px;
      height: 16px;
      border-radius: 999px;
      display: flex;
      align-items: center;
      justify-content: center;
      border: 2px solid var(--surface, #0F172A);
      box-shadow: 0 2px 4px rgba(239, 68, 68, 0.4);
      animation: pulse-badge 2s infinite;
    }

    @keyframes pulse-badge {
      0%, 100% { transform: scale(1); }
      50% { transform: scale(1.1); }
    }

    .dropdown-panel {
      position: absolute;
      top: 48px;
      right: 0;
      width: 360px;
      max-width: 90vw;
      background: var(--surface, #1E293B);
      color: var(--text, #F8FAFC);
      border-radius: 14px;
      border: 1px solid var(--border-light, #334155);
      box-shadow: 0 16px 36px -4px rgba(0, 0, 0, 0.35);
      z-index: 1050;
      overflow: hidden;
      display: flex;
      flex-direction: column;
      animation: dropdown-in 0.18s ease-out;
    }

    @keyframes dropdown-in {
      from { opacity: 0; transform: translateY(-8px) scale(0.97); }
      to { opacity: 1; transform: translateY(0) scale(1); }
    }

    .panel-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 14px 16px;
      border-bottom: 1px solid var(--border-light, #334155);
      background: rgba(0, 0, 0, 0.08);
    }

    .panel-title-area {
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .panel-title {
      font-size: 14.5px;
      font-weight: 700;
    }

    .new-pill {
      background: #4F46E5;
      color: #FFFFFF;
      font-size: 10px;
      font-weight: 700;
      padding: 2px 7px;
      border-radius: 10px;
    }

    .panel-actions {
      display: flex;
      align-items: center;
      gap: 10px;
    }

    .mark-all-btn {
      background: none;
      border: none;
      color: #38BDF8;
      font-size: 11.5px;
      font-weight: 600;
      cursor: pointer;
      padding: 2px 4px;
      border-radius: 4px;
    }
    .mark-all-btn:hover {
      text-decoration: underline;
    }

    .close-btn {
      background: none;
      border: none;
      color: var(--text-secondary, #94A3B8);
      font-size: 13px;
      cursor: pointer;
      line-height: 1;
      padding: 4px;
    }
    .close-btn:hover {
      color: var(--text, #F8FAFC);
    }

    .notifications-list {
      max-height: 400px;
      overflow-y: auto;
    }

    .empty-state {
      padding: 36px 16px;
      text-align: center;
      color: var(--text-secondary, #94A3B8);
    }
    .empty-icon {
      font-size: 32px;
      display: block;
      margin-bottom: 8px;
      opacity: 0.6;
    }
    .empty-text {
      font-size: 13.5px;
      font-weight: 600;
      margin: 0 0 2px 0;
    }
    .empty-sub {
      font-size: 11.5px;
      opacity: 0.75;
    }

    .notif-item {
      display: flex;
      gap: 12px;
      padding: 12px 16px;
      border-bottom: 1px solid var(--border-light, #334155);
      cursor: pointer;
      transition: background 0.15s ease;
    }
    .notif-item:hover {
      background: rgba(255, 255, 255, 0.05);
    }
    .notif-item.unread {
      background: rgba(79, 70, 229, 0.08);
    }
    .notif-item.unread:hover {
      background: rgba(79, 70, 229, 0.14);
    }

    .notif-icon-col {
      flex-shrink: 0;
      width: 32px;
      height: 32px;
      border-radius: 8px;
      background: rgba(255, 255, 255, 0.06);
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .type-icon {
      font-size: 16px;
    }

    .notif-content-col {
      flex: 1;
      min-width: 0;
    }

    .notif-top {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 6px;
      margin-bottom: 3px;
    }

    .notif-title {
      font-size: 12.5px;
      font-weight: 700;
      line-height: 1.3;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .unread-dot {
      width: 7px;
      height: 7px;
      border-radius: 50%;
      background: #38BDF8;
      flex-shrink: 0;
    }

    .notif-message {
      font-size: 12px;
      color: var(--text-secondary, #94A3B8);
      line-height: 1.4;
      margin: 0 0 6px 0;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
      overflow: hidden;
    }

    .notif-meta {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 6px;
    }

    .type-badge {
      font-size: 9.5px;
      font-weight: 700;
      padding: 1px 5px;
      border-radius: 4px;
      background: rgba(255, 255, 255, 0.08);
      color: var(--text-secondary, #94A3B8);
    }
    .type-badge.chat { background: #E0E7FF; color: #4338CA; }
    .type-badge.qa { background: #FEF3C7; color: #92400E; }
    .type-badge.exam { background: #FCE7F3; color: #9D174D; }
    .type-badge.assignment { background: #DCFCE7; color: #166534; }
    .type-badge.placement { background: #CFFAFE; color: #155E75; }

    .notif-time {
      font-size: 10.5px;
      color: var(--text-secondary, #64748B);
    }

    .panel-footer {
      padding: 8px 16px;
      background: rgba(0, 0, 0, 0.06);
      text-align: center;
      font-size: 11px;
      color: var(--text-secondary, #64748B);
    }
  `]
})
export class AdminNotificationsComponent implements OnInit, OnDestroy {
  private api = inject(ApiService);
  private router = inject(Router);
  private elementRef = inject(ElementRef);

  isOpen = false;
  loading = false;
  unreadCount = 0;
  notifications: AdminNotification[] = [];
  private pollTimer: any = null;
  private knownNotificationIds = new Set<number>();
  private initialLoadDone = false;

  ngOnInit() {
    this.requestBrowserNotificationPermission();
    this.loadUnreadCount();
    this.loadNotifications(true);

    // Auto-poll notifications every 15 seconds
    this.pollTimer = setInterval(() => {
      this.loadUnreadCount();
      if (this.isOpen) {
        this.loadNotifications(false);
      }
    }, 15000);
  }

  ngOnDestroy() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer);
    }
  }

  @HostListener('document:click', ['$event'])
  onDocumentClick(event: MouseEvent) {
    if (!this.elementRef.nativeElement.contains(event.target)) {
      this.closeDropdown();
    }
  }

  @HostListener('document:keydown.escape')
  onEscape() {
    this.closeDropdown();
  }

  toggleDropdown(event: Event) {
    event.stopPropagation();
    this.isOpen = !this.isOpen;
    if (this.isOpen) {
      this.loadNotifications(true);
    }
  }

  closeDropdown() {
    this.isOpen = false;
  }

  loadUnreadCount() {
    this.api.get<{ count: number }>('/api/notifications/unread-count').subscribe({
      next: (res) => {
        const previousCount = this.unreadCount;
        this.unreadCount = res?.count ?? 0;
        // If unread count increased, fetch latest for desktop notification
        if (this.unreadCount > previousCount && this.initialLoadDone) {
          this.checkNewNotificationsForDesktop();
        }
      },
      error: () => {}
    });
  }

  loadNotifications(showLoading = false) {
    if (showLoading) this.loading = true;
    this.api.get<AdminNotification[]>('/api/notifications').subscribe({
      next: (data) => {
        const sorted = (data || []).sort((a, b) => {
          const tA = a.createdAt ? new Date(a.createdAt).getTime() : 0;
          const tB = b.createdAt ? new Date(b.createdAt).getTime() : 0;
          return tB - tA;
        });

        // Track seen IDs
        if (!this.initialLoadDone) {
          sorted.forEach(n => this.knownNotificationIds.add(n.id));
          this.initialLoadDone = true;
        }

        this.notifications = sorted.slice(0, 30);
        this.unreadCount = sorted.filter(n => !n.isRead).length;
        this.loading = false;
      },
      error: () => {
        this.loading = false;
      }
    });
  }

  private checkNewNotificationsForDesktop() {
    this.api.get<AdminNotification[]>('/api/notifications').subscribe({
      next: (data) => {
        for (const notif of data || []) {
          if (!this.knownNotificationIds.has(notif.id) && !notif.isRead) {
            this.knownNotificationIds.add(notif.id);
            this.sendDesktopNotification(notif);
          }
        }
      },
      error: () => {}
    });
  }

  markAllAsRead() {
    this.api.put('/api/notifications/read-all', {}).subscribe({
      next: () => {
        this.notifications.forEach(n => (n.isRead = true));
        this.unreadCount = 0;
      },
      error: () => {
        // Fallback: mark in local state
        this.notifications.forEach(n => (n.isRead = true));
        this.unreadCount = 0;
      }
    });
  }

  onNotificationClick(notif: AdminNotification) {
    if (!notif.isRead) {
      notif.isRead = true;
      if (this.unreadCount > 0) this.unreadCount--;
      this.api.put(`/api/notifications/${notif.id}/read`, {}).subscribe({ error: () => {} });
    }
    this.closeDropdown();
    if (notif.actionUrl) {
      this.router.navigateByUrl(notif.actionUrl);
    }
  }

  getIcon(type: string): string {
    const t = (type || '').toLowerCase();
    if (t.includes('chat')) return '💬';
    if (t.includes('qa')) return '❓';
    if (t.includes('exam')) return '📋';
    if (t.includes('assignment')) return '📝';
    if (t.includes('placement')) return '💼';
    if (t.includes('support')) return '🎫';
    if (t.includes('announcement')) return '📢';
    return '🔔';
  }

  formatTimeAgo(dateStr: string): string {
    try {
      const dt = new Date(dateStr).getTime();
      const diffSec = Math.floor((Date.now() - dt) / 1000);
      if (diffSec < 60) return 'just now';
      const diffMin = Math.floor(diffSec / 60);
      if (diffMin < 60) return `${diffMin}m ago`;
      const diffHours = Math.floor(diffMin / 60);
      if (diffHours < 24) return `${diffHours}h ago`;
      const diffDays = Math.floor(diffHours / 24);
      return `${diffDays}d ago`;
    } catch {
      return '';
    }
  }

  private requestBrowserNotificationPermission() {
    if (typeof window !== 'undefined' && 'Notification' in window) {
      if (Notification.permission === 'default') {
        Notification.requestPermission().catch(() => {});
      }
    }
  }

  private sendDesktopNotification(notif: AdminNotification) {
    if (typeof window !== 'undefined' && 'Notification' in window && Notification.permission === 'granted') {
      try {
        const n = new Notification(notif.title, {
          body: notif.message,
          icon: '/favicon.ico'
        });
        n.onclick = () => {
          window.focus();
          if (notif.actionUrl) {
            this.router.navigateByUrl(notif.actionUrl);
          }
        };
      } catch {}
    }
  }
}
