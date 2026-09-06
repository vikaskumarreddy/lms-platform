import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';
import { ApiErrorService } from '../../services/api-error.service';
import { formatDateTimeDisplay, toDateTimeLocalValue, toIsoDateTime } from '../../utils/date.util';
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
      <button class="btn btn-primary" (click)="openAddModal()">+ Add Event</button>
    </div>

    <!-- Event Modal: Fieldset + Legend with Tabbed content to avoid vertical scroll -->
    <div class="modal-overlay" *ngIf="showForm" (click)="closeModal($event)">
      <div class="modal-content" style="width:90%;max-width:680px;" (click)="$event.stopPropagation()">
        <div style="display:none;justify-content:flex-end;margin-bottom:0;">
          <button class="btn btn-secondary btn-sm" (click)="closeModal()">✕</button>
        </div>

        <!-- Step indicator -->
        <div class="popup-steps">
          <div class="popup-step" [class.active]="eventTab === 'basic'" [class.completed]="eventTab === 'details'">1</div>
          <div class="popup-step-line" [class.completed]="eventTab === 'details'"></div>
          <div class="popup-step" [class.active]="eventTab === 'details'">2</div>
        </div>

        <!-- Tabs -->
        <div class="popup-tabs">
          <button type="button" [class.active]="eventTab === 'basic'" (click)="eventTab = 'basic'">🔑 Basic Details</button>
          <button type="button" [class.active]="eventTab === 'details'" (click)="eventTab = 'details'">📍 Location & Access</button>
        </div>

        <form (ngSubmit)="save()">
          <!-- Basic tab -->
          <fieldset *ngIf="eventTab === 'basic'">
            <legend>{{editingId ? 'Edit Calendar Event' : 'Add New Calendar Event'}}</legend>
            <div class="popup-form-grid">
              <div>
                <label>Event Title *</label>
                <input type="text" [(ngModel)]="formData.title" name="title" required placeholder="e.g. Live Class - Java Basics">
              </div>
              <div>
                <label>Type</label>
                <select [(ngModel)]="formData.eventType" name="eventType">
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
                <label>Start Date & Time</label>
                <input type="datetime-local" [(ngModel)]="formData.startTime" name="startTime">
              </div>
              <div>
                <label>End Date & Time</label>
                <input type="datetime-local" [(ngModel)]="formData.endTime" name="endTime">
              </div>
              <div class="full-width">
                <label>Attendance Required?</label>
                <select [(ngModel)]="formData.attendanceRequired" name="attendanceRequired">
                  <option [ngValue]="true">Yes</option>
                  <option [ngValue]="false">No</option>
                </select>
              </div>
            </div>
          </fieldset>

          <!-- Location & Access tab -->
          <fieldset *ngIf="eventTab === 'details'">
            <legend>Location & Access</legend>
            <div class="popup-form-grid">
              <div>
                <label>Venue</label>
                <input type="text" [(ngModel)]="formData.venue" name="venue" placeholder="e.g. Auditorium / Online">
              </div>
              <div>
                <label>Meet Link</label>
                <input type="text" [(ngModel)]="formData.meetLink" name="meetLink" placeholder="https://meet.google.com/...">
              </div>
              <div>
                <label>Subscription Plan</label>
                <select [(ngModel)]="formData.planId" name="planId">
                  <option [ngValue]="null">All Subscriptions</option>
                  <option *ngFor="let p of plans" [ngValue]="p.id">{{p.name}}</option>
                </select>
              </div>
              <div>
                <label>Batch</label>
                <select [(ngModel)]="formData.batchId" name="batchId">
                  <option [ngValue]="null">All Batches</option>
                  <option *ngFor="let b of batches" [ngValue]="b.id">{{b.name}}</option>
                </select>
              </div>
              <div class="full-width">
                <label>Description</label>
                <textarea [(ngModel)]="formData.description" name="description" rows="3" placeholder="Details about this event"></textarea>
              </div>
            </div>
          </fieldset>

          <!-- Navigation -->
          <div class="popup-nav">
            <button type="button" class="btn btn-secondary" *ngIf="eventTab === 'details'" (click)="eventTab = 'basic'">← Back</button>
            <button type="button" class="btn btn-primary" *ngIf="eventTab === 'basic'" (click)="eventTab = 'details'">Next →</button>
            <button type="submit" class="btn btn-accent" *ngIf="eventTab === 'details'" [disabled]="saving">{{saving ? 'Saving...' : (editingId ? 'Update Event' : 'Create Event')}}</button>
            <span style="flex:1"></span>
            <button type="button" class="btn btn-danger" (click)="closeModal()">Cancel</button>
          </div>
        </form>

        <div *ngIf="errorMessage" style="margin-top:16px;padding:12px;background:#FEE2E2;color:#991B1B;border-radius:8px;font-size:14px;">
          {{errorMessage}}
        </div>
      </div>
    </div>

    <div class="card">
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
  private confirm = inject(ConfirmService);
  private errors = inject(ApiErrorService);
  showForm = false;
  editingId: number | null = null;
  eventTab: 'basic' | 'details' = 'basic';
  saving = false;
  errorMessage = '';
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
      error: err => this.errors.show(err, 'Could not load subscription plans')
    });
  }

  loadBatches() {
    this.api.get<Batch[]>('/api/batches').subscribe({
      next: (data) => { this.batches = data; },
      error: err => this.errors.show(err, 'Could not load batches')
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

  openAddModal() {
    this.resetFormData();
    this.editingId = null;
    this.eventTab = 'basic';
    this.errorMessage = '';
    this.showForm = true;
  }

  closeModal(event?: Event) {
    if (event && event.target !== event.currentTarget) return;
    this.resetForm();
  }

  save() {
    this.saving = true;
    this.errorMessage = '';
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
          this.saving = false;
          this.resetForm();
        },
        error: (err) => { console.error('Failed to update event:', err); this.saving = false; this.errorMessage = 'Failed to update event'; }
      });
    } else {
      this.api.post<CalendarEvent>('/api/events', payload).subscribe({
        next: (created) => {
          this.events.push(created);
          this.saving = false;
          this.resetForm();
        },
        error: (err) => { console.error('Failed to create event:', err); this.saving = false; this.errorMessage = 'Failed to create event'; }
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
    this.eventTab = 'basic';
    this.errorMessage = '';
    this.showForm = true;
  }

  async delete(e: CalendarEvent) {
    if (await this.confirm.confirm('Delete this event?')) {
      this.api.delete(`/api/events/${e.id}`).subscribe({
        next: () => { this.events = this.events.filter(ev => ev.id !== e.id); },
        error: (err) => { this.errors.show(err, 'Failed to delete event'); }
      });
    }
  }

  private resetFormData() {
    this.formData = { title: '', description: '', eventType: 'Class', startTime: '', endTime: '', meetLink: '', venue: '', attendanceRequired: true, planId: null, batchId: null };
  }

  resetForm() {
    this.resetFormData();
    this.editingId = null;
    this.eventTab = 'basic';
    this.saving = false;
    this.errorMessage = '';
    this.showForm = false;
  }
}
