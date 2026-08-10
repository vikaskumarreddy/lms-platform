import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';

interface Plan {
  id: number;
  name: string;
  description: string;
  price: number;
  durationDays: number;
  isActive: boolean;
  features: string;
  color: string;
  period: string;
  isPopular: boolean;
}

interface Subscription {
  id: number;
  user: { id: number; fullName: string; email: string };
  plan: { id: number; name: string };
  status: string;
  startDate: string;
  endDate: string;
}

interface PlanFormData {
  name: string;
  description: string;
  price: number;
  durationDays: number;
  isActive: boolean;
  features: string;
  color: string;
  period: string;
  isPopular: boolean;
}

@Component({
  selector: 'app-subscriptions-admin',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
      <h1 style="font-size:24px;font-weight:700;">⭐ Subscription Plans</h1>
      <button class="btn btn-primary" (click)="showForm = !showForm">{{ showForm ? 'Cancel' : '+ Add Plan' }}</button>
    </div>

    <!-- Plan Form -->
    <div class="card" *ngIf="showForm" style="margin-bottom:20px;">
      <h3 style="margin-bottom:16px;">{{ editingId ? 'Edit' : 'Add New' }} Plan</h3>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;">
        <input [(ngModel)]="formData.name" placeholder="Plan Name" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <input type="number" [(ngModel)]="formData.price" placeholder="Price (e.g. 1999)" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <input type="number" [(ngModel)]="formData.durationDays" placeholder="Duration (days, e.g. 365)" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <input [(ngModel)]="formData.period" placeholder="Period (e.g. /month)" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <input [(ngModel)]="formData.color" placeholder="Color (e.g. #EAB308)" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <select [(ngModel)]="formData.isPopular" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
          <option [ngValue]="false">Not Popular</option>
          <option [ngValue]="true">Popular</option>
        </select>
        <select [(ngModel)]="formData.isActive" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
          <option [ngValue]="true">Active</option>
          <option [ngValue]="false">Inactive</option>
        </select>
        <textarea [(ngModel)]="formData.features" placeholder="Features (comma separated)" rows="3" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;"></textarea>
        <textarea [(ngModel)]="formData.description" placeholder="Description" rows="2" style="grid-column: 1 / -1;width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;"></textarea>
      </div>
      <div style="margin-top:16px;display:flex;gap:12px;">
        <button class="btn btn-primary" (click)="save()">{{ editingId ? 'Update' : 'Create' }}</button>
        <button class="btn" style="background:#E2E8F0;" (click)="resetForm()">Reset</button>
      </div>
      <div *ngIf="errorMsg" style="margin-top:8px;color:#EF4444;font-size:14px;">{{ errorMsg }}</div>
    </div>

    <!-- Plans Grid -->
    <div class="grid-2" *ngIf="!showForm && plans.length">
      <div class="card" *ngFor="let p of plans">
        <div style="display:flex;justify-content:space-between;align-items:center;">
          <h3 style="font-weight:700;color:{{p.color}};">{{ p.name }}</h3>
          <span *ngIf="p.isPopular" class="badge badge-warning">POPULAR</span>
          <span *ngIf="!p.isActive" class="badge badge-danger">INACTIVE</span>
        </div>
        <div style="margin:12px 0;"><span style="font-size:28px;font-weight:700;">₹{{ p.price }}</span><span style="color:#64748B;">{{ p.period }}</span></div>
        <div style="margin:8px 0;font-size:13px;color:#64748B;">{{ p.durationDays }} days · {{ p.description }}</div>
        <div style="margin-top:12px;">
          <div *ngFor="let f of p.features.split(',')" style="display:flex;align-items:center;gap:8px;margin-bottom:6px;">
            <span style="color:#16A34A;">✓</span><span style="font-size:14px;">{{ f.trim() }}</span>
          </div>
        </div>
        <div style="margin-top:12px;">
          <button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;margin-right:8px;" (click)="edit(p)">Edit</button>
          <button class="btn" style="background:#FEE2E2;color:#991B1B;padding:4px 12px;font-size:12px;" (click)="delete(p)">Delete</button>
        </div>
      </div>
    </div>
    <div *ngIf="!showForm && !plans.length && !loading" style="color:#64748B;padding:20px;">No plans found.</div>

    <!-- User Subscriptions -->
    <h2 style="font-size:20px;font-weight:700;margin:24px 0 16px;">User Subscriptions ({{ subscriptions.length }})</h2>
    <div class="card">
      <table *ngIf="subscriptions.length">
        <thead>
          <tr><th>User</th><th>Plan</th><th>Status</th><th>Start</th><th>End</th></tr>
        </thead>
        <tbody>
          <tr *ngFor="let s of subscriptions">
            <td>{{ s.user?.fullName || s.user?.email || '—' }}</td>
            <td>{{ s.plan?.name || '—' }}</td>
            <td><span class="badge" [ngClass]="s.status === 'ACTIVE' ? 'badge-success' : 'badge-warning'">{{ s.status }}</span></td>
            <td style="font-size:13px;">{{ s.startDate || '—' }}</td>
            <td style="font-size:13px;">{{ s.endDate || '—' }}</td>
          </tr>
        </tbody>
      </table>
      <div *ngIf="!subscriptions.length" style="color:#64748B;padding:16px;text-align:center;">No subscriptions yet.</div>
    </div>
  `
})
export class SubscriptionsAdminComponent implements OnInit {
  private api = inject(ApiService);
  plans: Plan[] = [];
  subscriptions: Subscription[] = [];
  showForm = false;
  editingId: number | null = null;
  loading = false;
  errorMsg = '';

  formData: PlanFormData = {
    name: '', description: '', price: 0, durationDays: 30, isActive: true,
    features: '', color: '#0F172A', period: '/month', isPopular: false
  };

  ngOnInit() {
    this.loadPlans();
    this.loadSubscriptions();
  }

  loadPlans() {
    this.loading = true;
    this.api.get<Plan[]>('/api/subscription-plans/admin/all').subscribe({
      next: (data) => { this.plans = data; this.loading = false; },
      error: () => { this.loading = false; }
    });
  }

  loadSubscriptions() {
    this.api.get<Subscription[]>('/api/subscriptions').subscribe({
      next: (data) => { this.subscriptions = data; },
      error: () => {}
    });
  }

  save() {
    this.errorMsg = '';
    if (!this.formData.name) { this.errorMsg = 'Plan name is required'; return; }

    if (this.editingId) {
      this.api.put<Plan>(`/api/subscription-plans/${this.editingId}`, this.formData).subscribe({
        next: () => { this.loadPlans(); this.resetForm(); },
        error: (err) => { this.errorMsg = err.error?.message || 'Failed to update plan'; }
      });
    } else {
      this.api.post<Plan>('/api/subscription-plans', this.formData).subscribe({
        next: () => { this.loadPlans(); this.resetForm(); },
        error: (err) => { this.errorMsg = err.error?.message || 'Failed to create plan'; }
      });
    }
  }

  edit(p: Plan) {
    this.editingId = p.id;
    this.formData = { ...p };
    this.showForm = true;
  }

  delete(p: Plan) {
    if (confirm(`Delete plan "${p.name}"?`)) {
      this.api.delete<void>(`/api/subscription-plans/${p.id}`).subscribe({
        next: () => this.loadPlans(),
        error: (err) => { this.errorMsg = err.error?.message || 'Failed to delete plan'; }
      });
    }
  }

  resetForm() {
    this.formData = {
      name: '', description: '', price: 0, durationDays: 30, isActive: true,
      features: '', color: '#0F172A', period: '/month', isPopular: false
    };
    this.editingId = null;
    this.showForm = false;
    this.errorMsg = '';
  }
}