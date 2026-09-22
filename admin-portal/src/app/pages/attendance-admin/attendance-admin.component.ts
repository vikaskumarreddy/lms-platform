import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';
import { ApiErrorService } from '../../services/api-error.service';
import { formatDateTimeDisplay } from '../../utils/date.util';

interface EventItem {
  id: number;
  title: string;
  eventType?: string;
  startTime?: string;
  batchId?: number;
}

interface Batch {
  id: number;
  name: string;
}

interface AttendanceRow {
  attendanceId: number | null;
  userId: number;
  userName: string;
  present: boolean;
  remarks?: string | null;
}

@Component({
  selector: 'app-attendance-admin',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
      <h1 style="font-size:24px;font-weight:700;">✅ Attendance</h1>
    </div>

    <div style="display:flex;gap:8px;margin-bottom:16px;">
      <button class="btn" [class.btn-primary]="mode === 'event'" [class.btn-secondary]="mode !== 'event'" (click)="setMode('event')">By Event</button>
      <button class="btn" [class.btn-primary]="mode === 'daily'" [class.btn-secondary]="mode !== 'daily'" (click)="setMode('daily')">Daily Attendance</button>
    </div>

    <div class="card" style="margin-bottom:20px;display:flex;gap:16px;align-items:center;flex-wrap:wrap;" *ngIf="mode === 'event'">
      <label style="font-weight:600;font-size:14px;">Select Event / Class:</label>
      <select [(ngModel)]="selectedEventId" (ngModelChange)="onEventChange()" style="padding:8px;border:1px solid #E2E8F0;border-radius:8px;min-width:320px;">
        <option [ngValue]="null">-- Select an event --</option>
        <option *ngFor="let e of events" [ngValue]="e.id">{{ e.title }} ({{ formatDate(e.startTime) }}) {{ getBatchName(e.batchId) ? '- ' + getBatchName(e.batchId) : '' }}</option>
      </select>
      <button class="btn btn-primary" [disabled]="!selectedEventId || saving" (click)="saveAttendance()">{{ saving ? 'Saving...' : 'Save Attendance' }}</button>
    </div>

    <div class="card" style="margin-bottom:20px;display:flex;gap:16px;align-items:center;flex-wrap:wrap;" *ngIf="mode === 'daily'">
      <label style="font-weight:600;font-size:14px;">Batch:</label>
      <select [(ngModel)]="selectedBatchId" (ngModelChange)="loadDailyAttendance()" style="padding:8px;border:1px solid #E2E8F0;border-radius:8px;min-width:220px;">
        <option [ngValue]="null">-- Select a batch --</option>
        <option *ngFor="let b of batches" [ngValue]="b.id">{{ b.name }}</option>
      </select>
      <label style="font-weight:600;font-size:14px;">Date:</label>
      <input type="date" [(ngModel)]="selectedDate" (ngModelChange)="loadDailyAttendance()" style="padding:8px;border:1px solid #E2E8F0;border-radius:8px;">
      <label style="font-weight:600;font-size:14px;">Subject (optional):</label>
      <input type="text" [(ngModel)]="subject" (ngModelChange)="loadDailyAttendance()" placeholder="e.g. Maths" style="padding:8px;border:1px solid #E2E8F0;border-radius:8px;width:160px;">
      <button class="btn btn-primary" [disabled]="!selectedEventId || saving" (click)="saveAttendance()">{{ saving ? 'Saving...' : 'Save Attendance' }}</button>
    </div>

    <div class="card" *ngIf="selectedEventId && rows.length > 0">
      <!-- Attendance Statistics Badges -->
      <div style="display:flex;gap:16px;flex-wrap:wrap;align-items:center;margin-bottom:16px;padding:12px;background:#F8FAFC;border-radius:8px;border:1px solid #E2E8F0;">
        <div style="font-size:13px;color:#475569;">
          Total: <strong style="color:#0F172A;font-size:15px;">{{ rows.length }}</strong>
        </div>
        <div style="font-size:13px;color:#166534;">
          Present: <strong style="font-size:15px;">{{ presentCount }}</strong>
        </div>
        <div style="font-size:13px;color:#991B1B;">
          Absent: <strong style="font-size:15px;">{{ absentCount }}</strong>
        </div>
        <div>
          <span class="badge" [style.background]="attendancePercentage >= 75 ? '#DCFCE7' : (attendancePercentage >= 50 ? '#FEF3C7' : '#FEE2E2')"
                [style.color]="attendancePercentage >= 75 ? '#166534' : (attendancePercentage >= 50 ? '#92400E' : '#991B1B')"
                style="font-size:13px;font-weight:700;padding:4px 10px;">
            📊 {{ attendancePercentage }}% Attendance
          </span>
        </div>
      </div>

      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px;flex-wrap:wrap;gap:12px;">
        <div style="font-weight:600;font-size:15px;">{{ eventTitle }}</div>
        <div style="display:flex;gap:8px;align-items:center;flex-wrap:wrap;">
          <input type="text" [(ngModel)]="studentSearchQuery" placeholder="🔍 Filter student name..." style="padding:4px 10px;border:1px solid #CBD5E1;border-radius:6px;font-size:13px;min-width:180px;">
          <button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;" (click)="markAll(true)">Mark All Present</button>
          <button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;" (click)="markAll(false)">Mark All Absent</button>
          <button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;background:#F1F5F9;" (click)="invertSelection()">🔄 Invert Selection</button>
        </div>
      </div>
      <table>
        <thead><tr><th>Student</th><th style="width:120px;">Present</th><th>Remarks</th></tr></thead>
        <tbody>
          <tr *ngFor="let r of visibleRows">
            <td style="font-weight:600;">{{ r.userName }}</td>
            <td>
              <input type="checkbox" [(ngModel)]="r.present" style="width:18px;height:18px;cursor:pointer;">
            </td>
            <td>
              <input type="text" [(ngModel)]="r.remarks" placeholder="Optional remarks" style="width:100%;padding:6px;border:1px solid #E2E8F0;border-radius:6px;font-size:12px;">
            </td>
          </tr>
          <tr *ngIf="visibleRows.length === 0">
            <td colspan="3" style="text-align:center;color:#64748B;padding:16px;">No students match "{{ studentSearchQuery }}"</td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="card" *ngIf="selectedEventId && rows.length === 0 && !loadingRows">
      <p style="text-align:center;color:#64748B;padding:24px;">No students found for this event's batch.</p>
    </div>
  `
})
export class AttendanceAdminComponent implements OnInit {
  private api = inject(ApiService);
  private errors = inject(ApiErrorService);

  events: EventItem[] = [];
  batches: Batch[] = [];
  selectedEventId: number | null = null;
  eventTitle = '';
  rows: AttendanceRow[] = [];
  loadingRows = false;
  saving = false;
  studentSearchQuery = '';

  get presentCount(): number {
    return this.rows.filter(r => r.present).length;
  }

  get absentCount(): number {
    return this.rows.filter(r => !r.present).length;
  }

  get attendancePercentage(): number {
    return this.rows.length > 0 ? Math.round((this.presentCount / this.rows.length) * 100) : 0;
  }

  get visibleRows(): AttendanceRow[] {
    if (!this.studentSearchQuery.trim()) return this.rows;
    const q = this.studentSearchQuery.toLowerCase().trim();
    return this.rows.filter(r => r.userName?.toLowerCase().includes(q));
  }

  invertSelection() {
    this.rows = this.rows.map(r => ({ ...r, present: !r.present }));
  }

  mode: 'event' | 'daily' = 'event';
  selectedBatchId: number | null = null;
  selectedDate: string = new Date().toISOString().slice(0, 10);
  subject = '';

  ngOnInit() {
    this.loadEvents();
    this.loadBatches();
  }

  setMode(mode: 'event' | 'daily') {
    this.mode = mode;
    this.selectedEventId = null;
    this.rows = [];
    this.eventTitle = '';
    if (mode === 'daily') {
      this.loadDailyAttendance();
    }
  }

  loadDailyAttendance() {
    if (!this.selectedBatchId || !this.selectedDate) {
      this.selectedEventId = null;
      this.rows = [];
      return;
    }
    this.loadingRows = true;
    const subjectParam = this.subject.trim() ? `?subject=${encodeURIComponent(this.subject.trim())}` : '';
    this.api.post<{ eventId: number; eventTitle: string }>(`/api/attendance/daily/${this.selectedBatchId}/${this.selectedDate}${subjectParam}`, {}).subscribe({
      next: (data) => {
        this.selectedEventId = data.eventId;
        this.loadRowsForEvent(data.eventId);
      },
      error: (err) => {
        this.loadingRows = false;
        this.errors.show(err, 'Failed to load daily attendance');
      }
    });
  }

  loadEvents() {
    this.api.get<EventItem[]>('/api/events').subscribe({
      next: (data) => { this.events = data; },
      error: () => { this.events = []; }
    });
  }

  loadBatches() {
    this.api.get<Batch[]>('/api/batches').subscribe({
      next: (data) => { this.batches = data; },
      error: () => { this.batches = []; }
    });
  }

  getBatchName(batchId?: number): string {
    if (!batchId) return '';
    const b = this.batches.find(x => x.id === batchId);
    return b ? b.name : '';
  }

  formatDate(value?: string): string {
    return formatDateTimeDisplay(value);
  }

  onEventChange() {
    if (!this.selectedEventId) {
      this.rows = [];
      return;
    }
    this.loadingRows = true;
    this.loadRowsForEvent(this.selectedEventId);
  }

  private loadRowsForEvent(eventId: number) {
    this.api.get<{ eventTitle: string; students: AttendanceRow[] }>(`/api/attendance/event/${eventId}`).subscribe({
      next: (data) => {
        this.eventTitle = data.eventTitle;
        this.rows = data.students || [];
        this.loadingRows = false;
      },
      error: () => {
        this.rows = [];
        this.loadingRows = false;
      }
    });
  }

  markAll(present: boolean) {
    this.rows = this.rows.map(r => ({ ...r, present }));
  }

  saveAttendance() {
    if (!this.selectedEventId) return;
    this.saving = true;
    const records = this.rows.map(r => ({ userId: r.userId, present: r.present, remarks: r.remarks || null }));
    this.api.post(`/api/attendance/event/${this.selectedEventId}/mark`, { records }).subscribe({
      next: () => {
        this.saving = false;
        this.errors.success('Attendance saved successfully.');
      },
      error: (err) => {
        this.saving = false;
        this.errors.show(err, 'Failed to save attendance');
      }
    });
  }
}
