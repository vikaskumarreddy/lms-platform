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
  selector: 'app-events-admin',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
      <h1 style="font-size:24px;font-weight:700;">🎉 Events</h1>
      <button class="btn btn-primary" (click)="openAddModal()">
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" style="vertical-align:-2px;margin-right:6px;">
          <line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
        </svg>
        Add Event
      </button>
    </div>

    <!-- Event Modal (Fieldset + Legend with Tabbed content) -->
    <div class="modal-overlay" *ngIf="showModal" (click)="closeModal($event)">
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
          <button [class.active]="eventTab === 'basic'" (click)="eventTab = 'basic'">🔑 Basic Details</button>
          <button [class.active]="eventTab === 'details'" (click)="eventTab = 'details'">🎯 Access & Description</button>
        </div>

        <form (ngSubmit)="save()">
          <!-- Basic tab -->
          <fieldset *ngIf="eventTab === 'basic'">
            <legend>{{editingId ? 'Edit Event' : 'Add New Event'}}</legend>
            <div class="popup-form-grid">
              <div class="full-width">
                <label>Event Title *</label>
                <input type="text" [(ngModel)]="formData.title" name="title" required placeholder="e.g. Annual Tech Fest">
              </div>
              <div>
                <label>Date</label>
                <input type="date" [(ngModel)]="formData.date" name="date">
              </div>
              <div>
                <label>Time</label>
                <input type="time" [(ngModel)]="formData.time" name="time">
              </div>
              <div>
                <label>Location</label>
                <input type="text" [(ngModel)]="formData.location" name="location" placeholder="Conference Hall / Google Meet link">
              </div>
              <div>
                <label>Category</label>
                <select [(ngModel)]="formData.category" name="category">
                  <option value="Technical">Technical</option>
                  <option value="Workshop">Workshop</option>
                  <option value="Networking">Networking</option>
                </select>
              </div>
            </div>
          </fieldset>

          <!-- Access & Description tab -->
          <fieldset *ngIf="eventTab === 'details'">
            <legend>Access & Description</legend>
            <div class="popup-form-grid">
              <div class="full-width">
                <label>Description</label>
                <textarea [(ngModel)]="formData.description" name="description" rows="3" placeholder="Describe the event..."></textarea>
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
            </div>
          </fieldset>

          <!-- Navigation -->
          <div class="popup-nav">
            <button type="button" class="btn btn-secondary" *ngIf="eventTab === 'details'" (click)="eventTab = 'basic'">← Back</button>
            <button type="button" class="btn btn-primary" *ngIf="eventTab === 'basic'" (click)="eventTab = 'details'">Next →</button>
            <button type="submit" class="btn btn-accent" *ngIf="eventTab === 'details'" [disabled]="saving">{{saving ? 'Saving...' : (editingId ? 'Update Event' : 'Create Event')}}</button>
            <span style="flex:1"></span>
            <button type="button" class="btn btn-danger" (click)="resetForm()">Cancel</button>
          </div>
        </form>

        <div *ngIf="errorMessage" style="margin-top:16px;padding:12px;background:#FEE2E2;color:#991B1B;border-radius:8px;font-size:14px;">
          {{errorMessage}}
        </div>
      </div>
    </div>

    <div class="card">
      <table><thead><tr><th>Title</th><th>Date</th><th>Time</th><th>Location</th><th>Category</th><th>Subscription</th><th>Batch</th><th>Actions</th></tr></thead>
      <tbody><tr *ngFor="let e of events">
        <td style="font-weight:600;">{{e.title}}</td><td>{{e.date}}</td><td>{{e.time}}</td><td>{{e.location}}</td>
        <td><span class="badge badge-warning">{{e.category}}</span></td>
        <td><span *ngIf="e.planId" class="badge badge-warning">⭐ {{getPlanName(e.planId)}}</span><span *ngIf="!e.planId" style="color:#64748B;font-size:13px;">All</span></td>
        <td><span *ngIf="e.batchId" class="badge" style="background:#EEF2FF;color:#4338CA;">👥 {{getBatchName(e.batchId)}}</span><span *ngIf="!e.batchId" style="color:#64748B;font-size:13px;">All</span></td>
        <td><button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;margin-right:8px;" (click)="edit(e)">Edit</button>
        <button class="btn" style="background:#FEE2E2;color:#991B1B;padding:4px 12px;font-size:12px;" (click)="delete(e)">Delete</button></td>
      </tr></tbody></table>
      <tr *ngIf="events.length === 0">
        <td colspan="8" style="text-align:center;color:#64748B;padding:32px;">No events found. Click "+ Add Event" to create one.</td>
      </tr>
    </div>
  `
})
export class EventsAdminComponent implements OnInit {
  private api = inject(ApiService);
  showModal = false;
  editingId: number | null = null;
  eventTab: 'basic' | 'details' = 'basic';
  saving = false;
  errorMessage = '';
  plans: SubscriptionPlan[] = [];
  batches: Batch[] = [];
  formData: any = { title: '', date: '', time: '', location: '', category: 'Technical', description: '', planId: null, batchId: null };
  events: any[] = [];

  ngOnInit() {
    this.loadPlans();
    this.loadBatches();
    this.loadEvents();
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

  loadEvents() {
    this.api.get<any[]>('/api/events').subscribe({
      next: (data) => {
        this.events = data;
      },
      error: (err) => {
        console.error('Failed to load events', err);
        this.events = [];
      }
    });
  }

  openAddModal() {
    this.editingId = null;
    this.errorMessage = '';
    this.eventTab = 'basic';
    this.formData = { title: '', date: '', time: '', location: '', category: 'Technical', description: '', planId: null, batchId: null };
    this.showModal = true;
  }

  closeModal(event?: any) {
    this.showModal = false;
    this.editingId = null;
    this.errorMessage = '';
  }

  save() {
    if (!this.formData.title) { this.errorMessage = 'Event title is required'; return; }
    this.saving = true;
    this.errorMessage = '';
    if (this.editingId) {
      const i = this.events.findIndex(e => e.id === this.editingId);
      if (i > -1) this.events[i] = { ...this.formData, id: this.editingId };
    } else {
      this.events.push({ ...this.formData, id: Date.now() });
    }
    this.saving = false;
    this.closeModal();
  }

  edit(e: any) {
    this.editingId = e.id;
    this.eventTab = 'basic';
    this.formData = { ...e }; delete (this.formData as any).id;
    this.showModal = true;
  }

  delete(e: any) {
    if (confirm(`Delete "${e.title}"?`)) this.events = this.events.filter(x => x.id !== e.id);
  }

  resetForm() {
    this.formData = { title: '', date: '', time: '', location: '', category: 'Technical', description: '', planId: null, batchId: null };
    this.editingId = null;
    this.eventTab = 'basic';
    this.showModal = false;
  }
}
