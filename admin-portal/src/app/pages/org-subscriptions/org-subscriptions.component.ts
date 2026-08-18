import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';

interface OrgSub {
  id: number;
  name: string;
  description?: string;
  price: number;
  period: string;
  features?: string;
  isActive: boolean;
  isPopular: boolean;
}

@Component({
  selector: 'app-org-subscriptions',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
      <h1 style="font-size:24px;font-weight:700;">⭐ Org Subscriptions</h1>
      <button class="btn btn-primary" (click)="openAdd()">+ New Plan</button>
    </div>

    <div style="background:white;border-radius:8px;box-shadow:0 2px 8px rgba(0,0,0,0.1);overflow:hidden;">
      <table style="width:100%;border-collapse:collapse;">
        <thead style="background:#f5f5f5;border-bottom:2px solid #e0e0e0;">
          <tr>
            <th style="padding:12px 16px;text-align:left;font-weight:600;color:#333;">Name</th>
            <th style="padding:12px 16px;text-align:left;font-weight:600;color:#333;">Price</th>
            <th style="padding:12px 16px;text-align:left;font-weight:600;color:#333;">Period</th>
            <th style="padding:12px 16px;text-align:left;font-weight:600;color:#333;">Status</th>
            <th style="padding:12px 16px;text-align:left;font-weight:600;color:#333;">Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr *ngFor="let s of plans" style="border-bottom:1px solid #e0e0e0;">
            <td style="padding:12px 16px;">
              <div style="font-weight:600;">{{ s.name }}</div>
              <div style="color:#999;font-size:13px;">{{ s.description }}</div>
              <span *ngIf="s.isPopular" style="background:#FEF3C7;color:#B45309;font-size:11px;padding:2px 8px;border-radius:12px;">Popular</span>
            </td>
            <td style="padding:12px 16px;font-weight:600;">₹{{ s.price | number:'1.0-0' }}</td>
            <td style="padding:12px 16px;">{{ s.period }}</td>
            <td style="padding:12px 16px;">
              <span [style.color]="s.isActive ? '#4caf50' : '#f44336'">{{ s.isActive ? 'Active' : 'Inactive' }}</span>
            </td>
            <td style="padding:12px 16px;">
              <button class="btn btn-sm btn-secondary" (click)="openEdit(s)" style="margin-right:8px;">Edit</button>
              <button class="btn btn-sm btn-danger" (click)="deletePlan(s)">Delete</button>
            </td>
          </tr>
          <tr *ngIf="plans.length === 0">
            <td colspan="5" style="text-align:center;color:#999;padding:32px;">No org subscription plans yet. Create one to get started.</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Plan modal -->
    <div *ngIf="showModal" style="position:fixed;inset:0;background:rgba(0,0,0,0.5);display:flex;align-items:center;justify-content:center;z-index:1000;">
      <div style="background:white;border-radius:8px;box-shadow:0 8px 32px rgba(0,0,0,0.2);width:90%;max-width:520px;max-height:90vh;overflow-y:auto;">
        <div style="padding:24px;border-bottom:1px solid #e0e0e0;">
          <h2 style="margin:0;font-size:20px;font-weight:700;">{{ editingId ? 'Edit' : 'Create' }} Org Subscription Plan</h2>
        </div>
        <form (submit)="savePlan()" style="padding:24px;display:flex;flex-direction:column;gap:16px;">
          <div>
            <label style="display:block;margin-bottom:8px;font-weight:600;color:#333;">Name *</label>
            <input [(ngModel)]="form.name" name="name" required placeholder="e.g. Platform + Training Support" style="width:100%;padding:8px 12px;border:1px solid #e0e0e0;border-radius:4px;font-size:14px;">
          </div>
          <div>
            <label style="display:block;margin-bottom:8px;font-weight:600;color:#333;">Description</label>
            <textarea [(ngModel)]="form.description" name="description" rows="2" placeholder="What does this plan include?" style="width:100%;padding:8px 12px;border:1px solid #e0e0e0;border-radius:4px;font-size:14px;"></textarea>
          </div>
          <div style="display:flex;gap:16px;">
            <div style="flex:1;">
              <label style="display:block;margin-bottom:8px;font-weight:600;color:#333;">Price (₹) *</label>
              <input [(ngModel)]="form.price" name="price" type="number" required min="0" style="width:100%;padding:8px 12px;border:1px solid #e0e0e0;border-radius:4px;font-size:14px;">
            </div>
            <div style="flex:1;">
              <label style="display:block;margin-bottom:8px;font-weight:600;color:#333;">Period</label>
              <select [(ngModel)]="form.period" name="period" style="width:100%;padding:8px 12px;border:1px solid #e0e0e0;border-radius:4px;font-size:14px;">
                <option value="monthly">Monthly</option>
                <option value="yearly">Yearly</option>
                <option value="custom">Custom</option>
              </select>
            </div>
          </div>
          <div>
            <label style="display:block;margin-bottom:8px;font-weight:600;color:#333;">Features (one per line)</label>
            <textarea [(ngModel)]="featuresText" name="featuresText" rows="4" placeholder="Core LMS platform&#10;Unlimited students&#10;Priority support" style="width:100%;padding:8px 12px;border:1px solid #e0e0e0;border-radius:4px;font-size:14px;"></textarea>
          </div>
          <div style="display:flex;gap:24px;">
            <label style="font-weight:600;color:#333;"><input type="checkbox" [(ngModel)]="form.isActive" name="isActive"> Active</label>
            <label style="font-weight:600;color:#333;"><input type="checkbox" [(ngModel)]="form.isPopular" name="isPopular"> Popular</label>
          </div>
          <div style="display:flex;gap:8px;border-top:1px solid #e0e0e0;padding-top:16px;">
            <button type="submit" class="btn btn-primary" style="flex:1;">Save</button>
            <button type="button" class="btn btn-secondary" (click)="closeModal()" style="flex:1;">Cancel</button>
          </div>
        </form>
      </div>
    </div>
  `,
})
export class OrgSubscriptionsComponent implements OnInit {
  private api = inject(ApiService);

  plans: OrgSub[] = [];
  showModal = false;
  editingId: number | null = null;
  featuresText = '';
  form: any = { name: '', description: '', price: 0, period: 'monthly', isActive: true, isPopular: false };

  ngOnInit() { this.loadPlans(); }

  loadPlans() {
    this.api.get<OrgSub[]>('/api/org-subscriptions').subscribe({
      next: (data) => (this.plans = data),
      error: (err) => console.error('Failed to load org subscriptions', err)
    });
  }

  openAdd() {
    this.editingId = null;
    this.form = { name: '', description: '', price: 0, period: 'monthly', isActive: true, isPopular: false };
    this.featuresText = '';
    this.showModal = true;
  }

  openEdit(p: OrgSub) {
    this.editingId = p.id;
    this.form = { name: p.name, description: p.description || '', price: p.price, period: p.period, isActive: p.isActive, isPopular: p.isPopular };
    this.featuresText = this.featuresToText(p.features);
    this.showModal = true;
  }

  closeModal() { this.showModal = false; }

  private featuresToText(raw?: string): string {
    if (!raw) return '';
    try {
      const arr = JSON.parse(raw);
      return Array.isArray(arr) ? arr.join('\n') : '';
    } catch { return ''; }
  }

  savePlan() {
    if (!this.form.name.trim()) { alert('Name is required'); return; }
    const featuresArr = this.featuresText.split('\n').map((f: string) => f.trim()).filter((f: string) => f.length > 0);
    const payload = {
      name: this.form.name,
      description: this.form.description,
      price: String(this.form.price ?? 0),
      period: this.form.period,
      features: JSON.stringify(featuresArr),
      isActive: this.form.isActive,
      isPopular: this.form.isPopular
    };

    if (this.editingId) {
      this.api.put(`/api/org-subscriptions/${this.editingId}`, payload).subscribe({
        next: () => { this.closeModal(); this.loadPlans(); },
        error: (err) => alert('Failed to update plan: ' + (err.error?.error || 'Unknown error'))
      });
    } else {
      this.api.post('/api/org-subscriptions', payload).subscribe({
        next: () => { this.closeModal(); this.loadPlans(); },
        error: (err) => alert('Failed to create plan: ' + (err.error?.error || 'Unknown error'))
      });
    }
  }

  deletePlan(p: OrgSub) {
    if (!confirm(`Delete plan "${p.name}"?`)) return;
    this.api.delete(`/api/org-subscriptions/${p.id}`).subscribe({
      next: () => this.loadPlans(),
      error: (err) => alert('Failed to delete: ' + (err.error?.error || 'Unknown error'))
    });
  }
}
