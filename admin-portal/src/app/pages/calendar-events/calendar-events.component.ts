import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';

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
          <label style="display:block;margin-bottom:4px;font-weight:600;font-size:14px;">Date (e.g. 28 Jul)</label>
          <input [(ngModel)]="formData.date" placeholder="e.g. 28 Jul" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        </div>
        <div>
          <label style="display:block;margin-bottom:4px;font-weight:600;font-size:14px;">Day Label</label>
          <input [(ngModel)]="formData.day" placeholder="e.g. Today, Thursday" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        </div>
        <div>
          <label style="display:block;margin-bottom:4px;font-weight:600;font-size:14px;">Month Key (YYYY-MM)</label>
          <input [(ngModel)]="formData.monthKey" placeholder="e.g. 2026-07" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        </div>
        <div>
          <label style="display:block;margin-bottom:4px;font-weight:600;font-size:14px;">Time</label>
          <input [(ngModel)]="formData.time" placeholder="e.g. 10:00 AM" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        </div>
        <div>
          <label style="display:block;margin-bottom:4px;font-weight:600;font-size:14px;">Type</label>
          <select [(ngModel)]="formData.type" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
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
          <label style="display:block;margin-bottom:4px;font-weight:600;font-size:14px;">Status</label>
          <select [(ngModel)]="formData.status" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
            <option value="Upcoming">Upcoming</option>
            <option value="Attended">Attended</option>
            <option value="Absent">Absent</option>
            <option value="Holiday">Holiday</option>
          </select>
        </div>
        <div>
          <label style="display:block;margin-bottom:4px;font-weight:600;font-size:14px;">Meet Link (optional)</label>
          <input [(ngModel)]="formData.meetLink" placeholder="https://meet.google.com/..." style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        </div>
        <div>
          <label style="display:block;margin-bottom:4px;font-weight:600;font-size:14px;">Is Past Event?</label>
          <select [(ngModel)]="formData.isPast" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
            <option [ngValue]="false">No (Upcoming)</option>
            <option [ngValue]="true">Yes (Past)</option>
          </select>
        </div>
        <div>
          <label style="display:block;margin-bottom:4px;font-weight:600;font-size:14px;">Color</label>
          <select [(ngModel)]="formData.color" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
            <option value="blue">Blue</option>
            <option value="orange">Orange</option>
            <option value="red">Red</option>
            <option value="green">Green</option>
            <option value="purple">Purple</option>
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
            <th>Date</th>
            <th>Time</th>
            <th>Type</th>
            <th>Status</th>
            <th>Subscription</th>
            <th>Batch</th>
            <th>Month</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr *ngFor="let e of events">
            <td style="font-weight:600;">{{e.title}}</td>
            <td>{{e.date}}</td>
            <td>{{e.time}}</td>
            <td><span class="badge badge-warning">{{e.type}}</span></td>
            <td><span [class.badge-success]="e.status === 'Attended'" [class.badge-danger]="e.status === 'Absent'" [class.badge-warning]="e.status === 'Upcoming'" class="badge">{{e.status}}</span></td>
            <td><span *ngIf="e.planId" class="badge badge-warning">⭐ {{getPlanName(e.planId)}}</span><span *ngIf="!e.planId" style="color:#64748B;font-size:13px;">All</span></td>
            <td><span *ngIf="e.batchId" class="badge" style="background:#EEF2FF;color:#4338CA;">👥 {{getBatchName(e.batchId)}}</span><span *ngIf="!e.batchId" style="color:#64748B;font-size:13px;">All</span></td>
            <td>{{e.monthKey}}</td>
            <td>
              <button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;margin-right:8px;" (click)="edit(e)">Edit</button>
              <button class="btn" style="background:#FEE2E2;color:#991B1B;padding:4px 12px;font-size:12px;" (click)="delete(e)">Delete</button>
            </td>
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

  formData: any = {
    title: '',
    date: '',
    day: '',
    monthKey: '',
    time: '',
    type: 'Class',
    status: 'Upcoming',
    meetLink: '',
    isPast: false,
    color: 'blue',
    planId: null,
    batchId: null
  };

  events: any[] = [
    { id: 1, title: 'Live Class - Java Basics', date: '28 Jul', day: 'Today', monthKey: '2026-07', time: '10:00 AM', type: 'Class', status: 'Upcoming', meetLink: 'https://meet.google.com/abc', isPast: false, color: 'blue', planId: null, batchId: null },
    { id: 2, title: 'Mock Interview', date: '28 Jul', day: 'Today', monthKey: '2026-07', time: '2:00 PM', type: 'Interview', status: 'Upcoming', meetLink: 'https://meet.google.com/xyz', isPast: false, color: 'orange', planId: null, batchId: null },
    { id: 3, title: 'Placement Drive - Google', date: '31 Jul', day: 'Thursday', monthKey: '2026-07', time: '10:00 AM', type: 'Placement', status: 'Upcoming', meetLink: 'https://careers.google.com', isPast: false, color: 'green', planId: null, batchId: null },
    { id: 4, title: 'React Workshop', date: '20 Aug', day: 'Thursday', monthKey: '2026-08', time: '11:00 AM', type: 'Workshop', status: 'Upcoming', meetLink: 'https://meet.google.com/react', isPast: false, color: 'blue', planId: null, batchId: null },
    { id: 5, title: 'Tech Fest 2026', date: '10 Sep', day: 'Wednesday', monthKey: '2026-09', time: '09:00 AM', type: 'Event', status: 'Upcoming', meetLink: 'https://techfest.axisoraforge.com', isPast: false, color: 'green', planId: null, batchId: null },
  ];

  ngOnInit() {
    this.loadPlans();
    this.loadBatches();
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

  getPlanName(planId?: number): string {
    if (!planId) return '';
    const plan = this.plans.find(p => p.id === planId);
    return plan ? plan.name : '';
  }

  getBatchName(batchId?: number): string {
    if (!batchId) return '';
    const batch = this.batches.find(b => b.id === batchId);
    return batch ? batch.name : '';
  }

  save() {
    if (this.editingId) {
      const idx = this.events.findIndex(e => e.id === this.editingId);
      if (idx > -1) this.events[idx] = { ...this.formData, id: this.editingId };
    } else {
      this.events.push({ ...this.formData, id: Date.now() });
    }
    this.resetForm();
  }

  edit(e: any) {
    this.editingId = e.id;
    this.formData = { ...e };
    delete (this.formData as any).id;
    this.showForm = true;
  }

  delete(e: any) {
    if (confirm('Delete this event?')) {
      this.events = this.events.filter(ev => ev.id !== e.id);
    }
  }

  resetForm() {
    this.formData = { title: '', date: '', day: '', monthKey: '', time: '', type: 'Class', status: 'Upcoming', meetLink: '', isPast: false, color: 'blue', planId: null, batchId: null };
    this.editingId = null;
    this.showForm = false;
  }
}
