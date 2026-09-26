import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';
import { ApiErrorService } from '../../services/api-error.service';
import { ConfirmService } from '../../services/confirm.service';

interface SubscriptionPlan {
  id: number;
  name: string;
  price: number;
  period: string;
}

interface Batch {
  id: number;
  name: string;
  isActive: boolean;
}

interface Student {
  id: number;
  name: string;
  email: string;
}

interface NotificationRecord {
  id: number;
  title: string;
  message: string;
  type: string;
  targetType: string;
  targetId?: number;
  actionUrl?: string;
  broadcast: boolean;
  createdAt: string;
}

@Component({
  selector: 'app-notifications-admin',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
      <h1 style="font-size:24px;font-weight:700;">🔔 Notifications</h1>
      <button class="btn btn-primary" (click)="showForm = !showForm">{{ showForm ? 'Cancel' : '+ Send Notification' }}</button>
    </div>

    <!-- Send Form -->
    <div class="card" *ngIf="showForm" style="margin-bottom:20px;">
      <h3 style="margin-bottom:16px;">Send New Notification</h3>
      <div style="display:grid;gap:16px;">
        <input [(ngModel)]="formData.title" placeholder="Title" style="width:100%;padding:10px;border:1px solid var(--border-light);border-radius:8px;background:var(--surface);color:var(--text);">
        <textarea [(ngModel)]="formData.message" placeholder="Message" rows="3" style="width:100%;padding:10px;border:1px solid var(--border-light);border-radius:8px;background:var(--surface);color:var(--text);"></textarea>
        <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:16px;">
          <div>
            <label style="display:block;font-size:12px;font-weight:600;margin-bottom:4px;">Type</label>
            <select [(ngModel)]="formData.type" style="width:100%;padding:10px;border:1px solid var(--border-light);border-radius:8px;background:var(--surface);color:var(--text);">
              <option value="info">Info</option>
              <option value="success">Success</option>
              <option value="warning">Warning</option>
              <option value="error">Error</option>
            </select>
          </div>
          <div>
            <label style="display:block;font-size:12px;font-weight:600;margin-bottom:4px;">Target Audience</label>
            <select [(ngModel)]="formData.targetType" (change)="onTargetTypeChange()" style="width:100%;padding:10px;border:1px solid var(--border-light);border-radius:8px;background:var(--surface);color:var(--text);">
              <option value="ALL">All Students</option>
              <option value="SUBSCRIPTION">Specific Subscription</option>
              <option value="BATCH">Specific Batch</option>
              <option value="USER">Specific Student</option>
            </select>
          </div>
          <div>
            <label style="display:block;font-size:12px;font-weight:600;margin-bottom:4px;">Channel / Delivery</label>
            <select [(ngModel)]="formData.channel" style="width:100%;padding:10px;border:1px solid var(--border-light);border-radius:8px;background:var(--surface);color:var(--text);">
              <option value="PUSH">🔔 In-App & Push</option>
              <option value="WHATSAPP">💬 WhatsApp Only</option>
              <option value="SMS">📱 SMS Only</option>
              <option value="ALL">🚀 All Channels (App + WhatsApp + SMS)</option>
            </select>
          </div>
        </div>
        <div *ngIf="formData.targetType === 'SUBSCRIPTION'" style="display:grid;gap:8px;">
          <label style="font-weight:600;font-size:14px;">Select Subscription Plan</label>
          <select [(ngModel)]="formData.targetId" style="width:100%;padding:10px;border:1px solid var(--border-light);border-radius:8px;background:var(--surface);color:var(--text);">
            <option [ngValue]="null">Select a plan...</option>
            <option *ngFor="let p of plans" [ngValue]="p.id">{{p.name}} - ₹{{p.price}}{{p.period}}</option>
          </select>
        </div>
        <div *ngIf="formData.targetType === 'BATCH'" style="display:grid;gap:8px;">
          <label style="font-weight:600;font-size:14px;">Select Batch</label>
          <select [(ngModel)]="formData.targetId" style="width:100%;padding:10px;border:1px solid var(--border-light);border-radius:8px;background:var(--surface);color:var(--text);">
            <option [ngValue]="null">Select a batch...</option>
            <option *ngFor="let b of batches" [ngValue]="b.id">{{b.name}}{{b.isActive ? '' : ' (Inactive)'}}</option>
          </select>
        </div>
        <div *ngIf="formData.targetType === 'USER'" style="display:grid;gap:8px;">
          <label style="font-weight:600;font-size:14px;">Select Student</label>
          <select [(ngModel)]="selectedStudentId" style="width:100%;padding:10px;border:1px solid var(--border-light);border-radius:8px;background:var(--surface);color:var(--text);">
            <option [ngValue]="null">Select a student...</option>
            <option *ngFor="let s of students" [ngValue]="s.id">{{s.name}} ({{s.email}})</option>
          </select>
        </div>
        <input [(ngModel)]="formData.actionUrl" placeholder="Action URL (route for mobile app, e.g. /courses)" style="width:100%;padding:10px;border:1px solid var(--border-light);border-radius:8px;background:var(--surface);color:var(--text);">
      </div>
      <div style="margin-top:16px;display:flex;gap:12px;">
        <button class="btn btn-primary" (click)="send()" [disabled]="sending">Send Notifications</button>
        <button class="btn" style="background:#E2E8F0;" (click)="resetForm()">Reset</button>
      </div>
      <div *ngIf="sendError" style="margin-top:8px;color:#EF4444;font-size:14px;">{{ sendError }}</div>
    </div>

    <!-- Notifications Table -->
    <div class="card" *ngIf="!showForm">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;">
        <h3 style="font-weight:700;">Sent Notifications ({{ notifications.length }})</h3>
        <button class="btn" style="background:#EEF2FF;color:#4338CA;padding:6px 14px;font-size:12px;" (click)="loadNotifications()">Refresh</button>
      </div>
      <table *ngIf="notifications.length">
        <thead>
          <tr><th>Title</th><th>Message</th><th>Type</th><th>Target</th><th>Date</th><th>Actions</th></tr>
        </thead>
        <tbody>
          <tr *ngFor="let n of notifications">
            <td style="font-weight:600;">{{ n.title }}</td>
            <td style="max-width:300px;">{{ n.message }}</td>
            <td>
              <span [class.badge-success]="n.type === 'success'" [class.badge-warning]="n.type === 'warning'" [class.badge-danger]="n.type === 'error'" class="badge">{{ n.type }}</span>
            </td>
            <td>{{ getTargetLabel(n) }}</td>
            <td style="font-size:13px;color:#64748B;">{{ n.createdAt | date:'short' }}</td>
            <td>
              <button class="btn" style="background:#FEE2E2;color:#991B1B;padding:4px 12px;font-size:12px;" (click)="delete(n)">Delete</button>
            </td>
          </tr>
        </tbody>
      </table>
      <div *ngIf="!loading && notifications.length === 0" style="color:#64748B;padding:20px;text-align:center;">No notifications found.</div>
      <div *ngIf="loading" style="color:#64748B;padding:20px;text-align:center;">Loading...</div>
    </div>
  `
})
export class NotificationsAdminComponent implements OnInit {
  private api = inject(ApiService);
  private confirm = inject(ConfirmService);
  private errors = inject(ApiErrorService);

  showForm = false;
  loading = false;
  sending = false;
  sendError = '';
  notifications: NotificationRecord[] = [];

  plans: SubscriptionPlan[] = [];
  batches: Batch[] = [];
  students: Student[] = [];
  selectedStudentId: number | null = null;

  formData = {
    title: '',
    message: '',
    type: 'info',
    targetType: 'ALL',
    targetId: null as number | null,
    userIds: '',
    actionUrl: '',
    channel: 'PUSH'
  };

  ngOnInit() {
    this.loadNotifications();
    this.loadPlans();
    this.loadBatches();
    this.loadStudents();
  }

  loadPlans() {
    this.api.get<SubscriptionPlan[]>('/api/subscription-plans/admin/all').subscribe({
      next: (data) => { this.plans = data; },
      error: err => this.errors.show(err, 'Could not load subscription plans')
    });
  }

  loadBatches() {
    this.api.get<Batch[]>('/api/batches').subscribe({
      next: (data) => { this.batches = data; },
      error: err => this.errors.show(err, 'Could not load batches')
    });
  }

  loadStudents() {
    this.api.get<Student[]>('/api/students').subscribe({
      next: (data) => { this.students = data; },
      error: err => this.errors.show(err, 'Could not load students')
    });
  }

  onTargetTypeChange() {
    this.formData.targetId = null;
    this.formData.userIds = '';
    this.selectedStudentId = null;
  }

  getTargetLabel(n: NotificationRecord): string {
    switch (n.targetType) {
      case 'ALL': return 'All Students';
      case 'SUBSCRIPTION': {
        const plan = this.plans.find(p => p.id === n.targetId);
        return '⭐ ' + (plan ? plan.name : `Plan #${n.targetId}`);
      }
      case 'BATCH': {
        const batch = this.batches.find(b => b.id === n.targetId);
        return '👥 ' + (batch ? batch.name : `Batch #${n.targetId}`);
      }
      case 'USER': {
        const student = this.students.find(s => s.id === n.targetId);
        return '👤 ' + (student ? student.name : `Student #${n.targetId}`);
      }
      default: return n.targetType;
    }
  }

  loadNotifications() {
    this.loading = true;
    this.api.get<any[]>('/api/notifications/broadcasts').subscribe({
      next: (data: any[]) => {
        // The backend returns Notification entities. Filter broadcasts (sent by admin).
        this.notifications = data
          .filter(n => n.broadcast === true || n.broadcast === 1)
          .map(n => ({
            id: n.id,
            title: n.title,
            message: n.message,
            type: n.type,
            targetType: n.targetType,
            targetId: n.targetId,
            actionUrl: n.actionUrl,
            broadcast: n.broadcast,
            createdAt: n.createdAt
          }));
        this.loading = false;
      },
      error: () => { this.loading = false; }
    });
  }

  send() {
    if (!this.formData.title) return;
    this.sending = true;
    this.sendError = '';

    const userIdsArray = this.formData.targetType === 'USER' && this.selectedStudentId
      ? [this.selectedStudentId]
      : null;

    const payload = {
      title: this.formData.title,
      message: this.formData.message,
      type: this.formData.type,
      targetType: this.formData.targetType,
      targetId: this.formData.targetType === 'USER' ? this.selectedStudentId : this.formData.targetId,
      userIds: userIdsArray,
      actionUrl: this.formData.actionUrl,
      channel: this.formData.channel,
      broadcast: true
    };

    this.api.post<any[]>('/api/notifications', payload).subscribe({
      next: () => {
        this.sending = false;
        this.showForm = false;
        this.loadNotifications();
      },
      error: (err) => {
        this.sending = false;
        this.sendError = err.error?.message || 'Failed to send notification';
      }
    });
  }

  async delete(n: NotificationRecord) {
    if (await this.confirm.confirm('Delete this notification?')) {
      this.api.delete<void>(`/api/notifications/${n.id}`).subscribe({
        next: () => this.loadNotifications(),
        error: err => this.errors.show(err, 'Could not delete that notification')
      });
    }
  }

  resetForm() {
    this.formData = {
      title: '', message: '', type: 'info', targetType: 'ALL',
      targetId: null, userIds: '', actionUrl: '', channel: 'PUSH'
    };
    this.selectedStudentId = null;
    this.showForm = false;
    this.sendError = '';
  }
}
