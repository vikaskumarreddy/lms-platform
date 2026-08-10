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
      <button class="btn btn-primary" (click)="showForm = !showForm">{{ showForm ? 'Cancel' : '+ Add Event'}}</button>
    </div>
    <div class="card" *ngIf="showForm" style="margin-bottom:20px;">
      <h3 style="margin-bottom:16px;">{{editingId ? 'Edit' : 'Add New'}} Event</h3>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;">
        <input [(ngModel)]="formData.title" placeholder="Event Title" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <input [(ngModel)]="formData.date" placeholder="Date (e.g. 25 Jan 2026)" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <input [(ngModel)]="formData.time" placeholder="Time (e.g. 09:00 AM)" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <input [(ngModel)]="formData.location" placeholder="Location" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <select [(ngModel)]="formData.category" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
          <option value="Technical">Technical</option><option value="Workshop">Workshop</option><option value="Networking">Networking</option>
        </select>
        <textarea [(ngModel)]="formData.description" placeholder="Description" rows="2" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;"></textarea>
        <select [(ngModel)]="formData.planId" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;background:white;">
          <option [ngValue]="null">All Subscriptions</option>
          <option *ngFor="let p of plans" [ngValue]="p.id">{{p.name}}</option>
        </select>
        <select [(ngModel)]="formData.batchId" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;background:white;">
          <option [ngValue]="null">All Batches</option>
          <option *ngFor="let b of batches" [ngValue]="b.id">{{b.name}}</option>
        </select>
      </div>
      <div style="margin-top:16px;display:flex;gap:12px;">
        <button class="btn btn-primary" (click)="save()">{{editingId ? 'Update' : 'Create'}}</button>
        <button class="btn" style="background:#E2E8F0;" (click)="resetForm()">Reset</button>
      </div>
    </div>
    <div class="card" *ngIf="!showForm">
      <table><thead><tr><th>Title</th><th>Date</th><th>Time</th><th>Location</th><th>Category</th><th>Subscription</th><th>Batch</th><th>Actions</th></tr></thead>
      <tbody><tr *ngFor="let e of events">
        <td style="font-weight:600;">{{e.title}}</td><td>{{e.date}}</td><td>{{e.time}}</td><td>{{e.location}}</td>
        <td><span class="badge badge-warning">{{e.category}}</span></td>
        <td><span *ngIf="e.planId" class="badge badge-warning">⭐ {{getPlanName(e.planId)}}</span><span *ngIf="!e.planId" style="color:#64748B;font-size:13px;">All</span></td>
        <td><span *ngIf="e.batchId" class="badge" style="background:#EEF2FF;color:#4338CA;">👥 {{getBatchName(e.batchId)}}</span><span *ngIf="!e.batchId" style="color:#64748B;font-size:13px;">All</span></td>
        <td><button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;margin-right:8px;" (click)="edit(e)">Edit</button>
        <button class="btn" style="background:#FEE2E2;color:#991B1B;padding:4px 12px;font-size:12px;" (click)="delete(e)">Delete</button></td>
      </tr></tbody></table>
    </div>
  `
})
export class EventsAdminComponent implements OnInit {
  private api = inject(ApiService);
  showForm = false; editingId: number | null = null;
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

  save() { if (this.editingId) { const i = this.events.findIndex(e => e.id === this.editingId); if (i > -1) this.events[i] = { ...this.formData, id: this.editingId }; } else { this.events.push({ ...this.formData, id: Date.now() }); } this.resetForm(); }
  edit(e: any) { this.editingId = e.id; this.formData = { ...e }; delete (this.formData as any).id; this.showForm = true; }
  delete(e: any) { if (confirm('Delete?')) this.events = this.events.filter(x => x.id !== e.id); }
  resetForm() { this.formData = { title: '', date: '', time: '', location: '', category: 'Technical', description: '', planId: null, batchId: null }; this.editingId = null; this.showForm = false; }
}
