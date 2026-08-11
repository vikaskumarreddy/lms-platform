import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';
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

    <div class="card" style="margin-bottom:20px;display:flex;gap:16px;align-items:center;flex-wrap:wrap;">
      <label style="font-weight:600;font-size:14px;">Select Event / Class:</label>
      <select [(ngModel)]="selectedEventId" (ngModelChange)="onEventChange()" style="padding:8px;border:1px solid #E2E8F0;border-radius:8px;min-width:320px;">
        <option [ngValue]="null">-- Select an event --</option>
        <option *ngFor="let e of events" [ngValue]="e.id">{{ e.title }} ({{ formatDate(e.startTime) }}) {{ getBatchName(e.batchId) ? '- ' + getBatchName(e.batchId) : '' }}</option>
      </select>
      <button class="btn btn-primary" [disabled]="!selectedEventId || saving" (click)="saveAttendance()">{{ saving ? 'Saving...' : 'Save Attendance' }}</button>
    </div>

    <div class="card" *ngIf="selectedEventId && rows.length > 0">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px;">
        <div style="font-weight:600;">{{ eventTitle }}</div>
        <div style="display:flex;gap:8px;">
          <button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;" (click)="markAll(true)">Mark All Present</button>
          <button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;" (click)="markAll(false)">Mark All Absent</button>
        </div>
      </div>
      <table>
        <thead><tr><th>Student</th><th>Present</th><th>Remarks</th></tr></thead>
        <tbody>
          <tr *ngFor="let r of rows">
            <td style="font-weight:600;">{{ r.userName }}</td>
            <td>
              <input type="checkbox" [(ngModel)]="r.present" style="width:18px;height:18px;">
            </td>
            <td>
              <input type="text" [(ngModel)]="r.remarks" placeholder="Optional remarks" style="width:100%;padding:6px;border:1px solid #E2E8F0;border-radius:6px;font-size:12px;">
            </td>
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

  events: EventItem[] = [];
  batches: Batch[] = [];
  selectedEventId: number | null = null;
  eventTitle = '';
  rows: AttendanceRow[] = [];
  loadingRows = false;
  saving = false;

  ngOnInit() {
    this.loadEvents();
    this.loadBatches();
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
    this.api.get<{ eventTitle: string; students: AttendanceRow[] }>(`/api/attendance/event/${this.selectedEventId}`).subscribe({
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
        alert('Attendance saved successfully.');
      },
      error: (err) => {
        this.saving = false;
        console.error('Failed to save attendance', err);
        alert('Failed to save attendance.');
      }
    });
  }
}
