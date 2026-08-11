import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';
import { formatDateTimeDisplay, toDateTimeLocalValue, toIsoDateTime } from '../../utils/date.util';

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

interface CalendarEvent {
  id: number;
  title: string;
  description?: string;
  eventType: string;
  startTime?: string;
  endTime?: string;
  meetLink?: string;
  venue?: string;
  attendanceRequired?: boolean;
  batchId?: number | null;
  planId?: number | null;
}

@Component({
  selector: 'app-calendar-events',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
      <h1 style="font-size:24px;font-weight:700;">📅 Calendar Events</h1>
      <button class="btn btn-primary" (click)="showForm = !showForm">{{ showForm ? 'Cancel' : '+ Add Event'}}</button>
    </div>

    <div class="card" *ngIf="showForm" style="margin-bottom:20px;">
      <h3 style="margin-bottom:16px;font-weight:700;">{{editingId ? 'Edit' : 'Add New'}} Calendar Event</h3>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;">
        <div>
          <label style="display:block;margin-bottom:4px;font-weight:600;font-size:14px;">Event Title</label>
          <input [(ngModel)]="formData.title" placeholder="e.g. Live Class - Java Basics" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        </div>
        <div>
          <label style="display:block;margin-bottom:4px;font-weight:600;font-size:14px;">Type</label>
          <select [(ngModel)]="formData.eventType" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
            <option value="Class">Class</option>
            <option value="Workshop">Workshop</option>
            <option value="Exam">Exam</option>
            <option value="Interview">Interview</option>
            <option value="Placement">Placement</option>
            <option value="Holiday">Holiday</option>
            <option value="Event">Event</option>
          </select>
        </div>
        <div>
          <label style="display:block;margin-bottom:4px;font-weight:600;font-size:14px;">Start Date & Time</label>
          <input [(ngModel)]="formData.startTime" type="datetime-local" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        </div>
        <div>
          <label style="display:block;margin-bottom:4px;font-weight:600;font-size:14px;">End Date & Time (optional)</label>
          <input [(ngModel)]="formData.endTime" type="datetime-local" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        </div>
        <div>
          <label style="display:block;margin-bottom:4px;font-weight:600;font-size:14px;">Meet Link (optional)</label>
          <input [(ngModel)]="formData.meetLink" placeholder="https://meet.google.com/..." style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        </div>
        <div>
          <label style="display:block;margin-bottom:4px;font-weight:600;font-size:14px;">Venue (optional)</label>
          <input [(ngModel)]="formData.venue" placeholder="e.g. Auditorium / Online" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        </div>
        <div>
          <label style="display:block;margin-bottom:4px;font-weight:600;font-size:14px;">Attendance Required?</label>
          <select [(ngModel)]="formData.attendanceRequired" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
            <option [ngValue]="true">Yes</option>
            <option [ngValue]="false">No</option>
          </select>
        </div>
        <div>
          <label style="display:block;margin-bottom:4px;font-weight:600;font-size:14px;">Subscription</label>
          <select [(ngModel)]="formData.planId" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;background:white;">
            <option [ngValue]="null">All Subscriptions</option>
            <option *ngFor="let p of plans" [ngValue]="p.id">{{p.name}}</option>
          </select>
        </div>
        <div>
          <label style="display:block;margin-bottom:4px;font-weight:600;font-size:14px;">Batch</label>
          <select [(ngModel)]="formData.batchId" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;background:white;">
            <option [ngValue]="null">All Batches</option>
            <option *ngFor="let b of batches" [ngValue]="b.id">{{b.name}}</option>
          </select>
        </div>
        <div style="grid-column:1 / -1;">
          <label style="display:block;margin-bottom:4px;font-weight:600;font-size:14px;">Description (optional)</label>
          <textarea [(ngModel)]="formData.description" rows="2" placeholder="Details about this event" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;"></textarea>
        </div>
      </div>
      <div style="margin-top:16px;display:flex;gap:12px;">
        <button class="btn btn-primary" (click)="save()">{{editingId ? 'Update' : 'Create'}} Event</button>
        <button class="btn" style="background:#E2E8F0;" (click)="resetForm()">Reset</button>
      </div>
    </div>

    <div class="card" *ngIf="!showForm">
      <table>
        <thead>
          <tr>
            <th>Title</th>
            <th>Start</th>
            <th>End</th>
            <th>Type</th>
            <th>Subscription</th>
            <th>Batch</th>
            <th>Attendance</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr *ngFor="let e of events">
            <td style="font-weight:600;">{{e.title}}</td>
            <td>{{formatDate(e.startTime)}}</td>
            <td>{{e.endTime ? formatDate(e.endTime) : '—'}}</td>
            <td><span class="badge badge-warning">{{e.eventType}}</span></td>
            <td><span *ngIf="e.planId" class="badge badge-warning">⭐ {{getPlanName(e.planId)}}</span><span *ngIf="!e.planId" style="color:#64748B;font-size:13px;">All</span></td>
            <td><span *ngIf="e.batchId" class="badge" style="background:#EEF2FF;color:#4338CA;">👥 {{getBatchName(e.batchId)}}</span><span *ngIf="!e.batchId" style="color:#64748B;font-size:13px;">All</span></td>
            <td><span class="badge" [class.badge-success]="e.attendanceRequired" [class.badge-warning]="!e.attendanceRequired">{{e.attendanceRequired ? 'Required' : 'Optional'}}</span></td>
            <td>
              <button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;margin-right:8px;" (click)="edit(e)">Edit</button>
              <button class="btn" style="background:#FEE2E2;color:#991B1B;padding:4px 12px;font-size:12px;" (click)="delete(e)">Delete</button>
            </td>
          </tr>
          <tr *ngIf="events.length === 0">
            <td colspan="8" style="text-align:center;padding:32px;color:#64748B;">No calendar events found. Click "+ Add Event" to create one.</td>
          </tr>
        </tbody>
      </table>
    </div>
  `
})
export class CalendarEventsComponent implements OnInit {
  private api = inject(ApiService);
  showForm = false;
  editingId: number | null = null;
  plans: SubscriptionPlan[] = [];
  batches: Batch[] = [];
  events: CalendarEvent[] = [];

  formData: any = {
    title: '',
    description: '',
    eventType: 'Class',
    startTime: '',
    endTime: '',
    meetLink: '',
    venue: '',
    attendanceRequired: true,
    planId: null,
    batchId: null
  };

  ngOnInit() {
    this.loadEvents();
    this.loadPlans();
    this.loadBatches();
  }

  loadEvents() {
    this.api.get<CalendarEvent[]>('/api/events').subscribe({
      next: (data) => { this.events = data; },
      error: (err) => { console.error('Failed to load events:', err); }
    });
  }

  loadPlans() {
    this.api.get<SubscriptionPlan[]>('/api/subscription-plans/admin/all').subscribe({
      next: (data) => { this.plans = data; },
      error: () => {}
    });
  }

  loadBatches() {
    this.api.get<Batch[]>('/api/batches').subscribe({
      next: (data) => { this.batches = data; },
      error: () => {}
    });
  }

  getPlanName(planId?: number | null): string {
    if (!planId) return '';
    const plan = this.plans.find(p => p.id === planId);
    return plan ? plan.name : '';
  }

  getBatchName(batchId?: number | null): string {
    if (!batchId) return '';
    const batch = this.batches.find(b => b.id === batchId);
    return batch ? batch.name : '';
  }

  formatDate(value?: string): string {
    return formatDateTimeDisplay(value);
  }

  save() {
    const payload: any = {
      title: this.formData.title,
      description: this.formData.description || null,
      eventType: this.formData.eventType,
      startTime: toIsoDateTime(this.formData.startTime),
      endTime: this.formData.endTime ? toIsoDateTime(this.formData.endTime) : null,
      meetLink: this.formData.meetLink || null,
      venue: this.formData.venue || null,
      attendanceRequired: this.formData.attendanceRequired,
      planId: this.formData.planId,
      batchId: this.formData.batchId
    };

    if (this.editingId) {
      this.api.put<CalendarEvent>(`/api/events/${this.editingId}`, payload).subscribe({
        next: (updated) => {
          const idx = this.events.findIndex(e => e.id === this.editingId);
          if (idx > -1) this.events[idx] = updated;
          this.resetForm();
        },
        error: (err) => { console.error('Failed to update event:', err); alert('Failed to update event'); }
      });
    } else {
      this.api.post<CalendarEvent>('/api/events', payload).subscribe({
        next: (created) => {
          this.events.push(created);
          this.resetForm();
        },
        error: (err) => { console.error('Failed to create event:', err); alert('Failed to create event'); }
      });
    }
  }

  edit(e: CalendarEvent) {
    this.editingId = e.id;
    this.formData = {
      title: e.title,
      description: e.description || '',
      eventType: e.eventType,
      startTime: toDateTimeLocalValue(e.startTime),
      endTime: e.endTime ? toDateTimeLocalValue(e.endTime) : '',
      meetLink: e.meetLink || '',
      venue: e.venue || '',
      attendanceRequired: e.attendanceRequired ?? true,
      planId: e.planId ?? null,
      batchId: e.batchId ?? null
    };
    this.showForm = true;
  }

  delete(e: CalendarEvent) {
    if (confirm('Delete this event?')) {
      this.api.delete(`/api/events/${e.id}`).subscribe({
        next: () => { this.events = this.events.filter(ev => ev.id !== e.id); },
        error: (err) => { console.error('Failed to delete event:', err); alert('Failed to delete event'); }
      });
    }
  }

  resetForm() {
    this.formData = { title: '', description: '', eventType: 'Class', startTime: '', endTime: '', meetLink: '', venue: '', attendanceRequired: true, planId: null, batchId: null };
    this.editingId = null;
    this.showForm = false;
  }
}
