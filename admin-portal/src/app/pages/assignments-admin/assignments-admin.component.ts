import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';
import { formatDateTimeDisplay, toDateTimeLocalValue, toIsoDateTime } from '../../utils/date.util';

interface SubscriptionPlan { id: number; name: string; price: number; period: string; }
interface Batch { id: number; name: string; isActive: boolean; }

@Component({
  selector: 'app-assignments-admin',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
      <h1 style="font-size:24px;font-weight:700;">📝 Assignments</h1>
      <button class="btn btn-primary" (click)="showForm = !showForm">{{ showForm ? 'Cancel' : '+ Add Assignment'}}</button>
    </div>
    <div class="card" *ngIf="showForm" style="margin-bottom:20px;">
      <h3 style="margin-bottom:16px;">{{editingId ? 'Edit' : 'Add New'}} Assignment</h3>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;">
        <input [(ngModel)]="formData.title" placeholder="Title" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <input [(ngModel)]="formData.courseId" type="number" placeholder="Course ID" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <div>
          <label style="display:block;margin-bottom:4px;font-weight:600;font-size:14px;">Due Date & Time</label>
          <input [(ngModel)]="formData.dueDate" type="datetime-local" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        </div>
        <input [(ngModel)]="formData.link" placeholder="Link URL (e.g., https://example.com)" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <select [(ngModel)]="formData.status" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;background:white;">
          <option value="Pending">Pending</option><option value="Graded">Graded</option><option value="Overdue">Overdue</option>
        </select>
        <input [(ngModel)]="formData.marks" type="number" placeholder="Total Marks" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <textarea [(ngModel)]="formData.description" placeholder="Description" rows="2" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;"></textarea>
        <select [(ngModel)]="formData.planId" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;background:white;">
          <option [ngValue]="null">All Subscriptions</option>
          <option *ngFor="let p of plans" [ngValue]="p.id">{{p.name}}</option>
        </select>
        <select [(ngModel)]="selectedBatchIds" multiple style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;background:white;min-height:100px;">
          <option *ngFor="let b of batches" [value]="b.id">{{b.name}}</option>
        </select>
      </div>
      <div style="margin-top:16px;display:flex;gap:12px;">
        <button class="btn btn-primary" (click)="save()">{{editingId ? 'Update' : 'Create'}}</button>
        <button class="btn" style="background:#E2E8F0;" (click)="resetForm()">Reset</button>
      </div>
    </div>
    <div class="card" *ngIf="!showForm">
      <table><thead><tr><th>Title</th><th>Course</th><th>Due Date</th><th>Subscription</th><th>Batch</th><th>Status</th><th>Marks</th><th>Link</th><th>Actions</th></tr></thead>
        <tbody>
          <tr *ngFor="let a of assignments">
            <td style="font-weight:600;">{{a.title}}</td>
            <td>{{a.courseId}}</td>
            <td>{{formatDate(a.dueDate)}}</td>
            <td><span *ngIf="a.planId" class="badge badge-warning">⭐ {{getPlanName(a.planId)}}</span><span *ngIf="!a.planId" style="color:#64748B;font-size:13px;">All</span></td>
            <td><span *ngIf="a.batchIds?.length" class="badge" style="background:#EEF2FF;color:#4338CA;">👥 {{getBatchNames(a.batchIds)}}</span><span *ngIf="!a.batchIds?.length" style="color:#64748B;font-size:13px;">All</span></td>
            <td><span class="badge" [class.badge-warning]="a.status === 'Pending'" [class.badge-success]="a.status === 'Graded'" [class.badge-danger]="a.status === 'Overdue'">{{a.status || 'Pending'}}</span></td>
            <td>{{a.totalMarks || a.marks}}</td>
            <td><a *ngIf="a.link" href="{{a.link}}" target="_blank" style="color:#0F172A;text-decoration:underline;">🔗 Link</a><span *ngIf="!a.link" style="color:#94A3B8;">-</span></td>
            <td>
              <button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;margin-right:8px;" (click)="edit(a)">Edit</button>
              <button class="btn" style="background:#FEE2E2;color:#991B1B;padding:4px 12px;font-size:12px;" (click)="delete(a)">Delete</button>
            </td>
          </tr>
          <tr *ngIf="assignments.length === 0">
            <td colspan="9" style="text-align:center;padding:32px;color:#64748B;">No assignments found. Click "+ Add Assignment" to create one.</td>
          </tr>
        </tbody>
      </table>
    </div>
  `
})
export class AssignmentsAdminComponent implements OnInit {
  private api = inject(ApiService);
  showForm = false; editingId: number | null = null;
  plans: SubscriptionPlan[] = [];
  batches: Batch[] = [];
  selectedBatchIds: number[] = [];
  formData: any = { title: '', courseId: null, dueDate: '', status: 'Pending', marks: 100, description: '', planId: null, batchIds: [] };
      assignments: any[] = [];

  ngOnInit() {
    this.loadPlans();
    this.loadBatches();
    this.loadAssignments();
  }

  loadAssignments() {
    this.api.get<any[]>('/api/assignments').subscribe({
      next: (data) => { this.assignments = data; },
      error: () => {}
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

  getPlanName(planId?: number): string {
    if (!planId) return '';
    const plan = this.plans.find(p => p.id === planId);
    return plan ? plan.name : '';
  }

  getBatchNames(batchIds: number[]): string {
    if (!batchIds || batchIds.length === 0) return '';
    return batchIds.map(id => {
      const batch = this.batches.find(b => b.id === id);
      return batch ? batch.name : '';
    }).filter(name => name).join(', ');
  }

  save() {
    const payload: any = {
      title: this.formData.title,
      description: this.formData.description,
      dueDate: toIsoDateTime(this.formData.dueDate),
      totalMarks: this.formData.marks,
      batchIds: this.selectedBatchIds.length > 0 ? this.selectedBatchIds : [],
      courseId: Number(this.formData.courseId) || null,
      isActive: true,
      link: this.formData.link || null
    };

    if (this.editingId) {
      this.api.put<any>(`/api/assignments/${this.editingId}`, payload).subscribe({
        next: () => {
          const i = this.assignments.findIndex(a => a.id === this.editingId);
          if (i > -1) this.assignments[i] = { ...payload, id: this.editingId, status: this.formData.status, planId: this.formData.planId, batchIds: this.selectedBatchIds };
          this.resetForm();
        },
        error: (err) => { console.error('Failed to update:', err); alert('Failed to update assignment'); }
      });
    } else {
      this.api.post<any>('/api/assignments', payload).subscribe({
        next: (saved: any) => {
          this.assignments.push({ ...payload, id: saved?.id || Date.now(), status: this.formData.status, planId: this.formData.planId, batchIds: this.selectedBatchIds });
          this.resetForm();
        },
        error: (err) => { console.error('Failed to create:', err); alert('Failed to create assignment'); }
      });
    }
  }

  edit(a: any) {
    this.editingId = a.id;
    this.formData = {
      title: a.title,
      courseId: a.courseId,
      dueDate: toDateTimeLocalValue(a.dueDate),
      status: a.status || 'Pending',
      marks: a.totalMarks || a.marks || 100,
      description: a.description,
      planId: a.planId || null,
      link: a.link || ''
    };
    this.selectedBatchIds = a.batchIds || [];
    this.showForm = true;
  }

  delete(a: any) {
    if (confirm('Delete assignment?')) {
      this.api.delete(`/api/assignments/${a.id}`).subscribe({
        next: () => { this.assignments = this.assignments.filter(x => x.id !== a.id); },
        error: (err) => { console.error('Failed to delete:', err); alert('Failed to delete assignment'); }
      });
    }
  }

  formatDate(value?: string): string {
    return formatDateTimeDisplay(value);
  }

  resetForm() {
    this.formData = { title: '', courseId: null, dueDate: '', status: 'Pending', marks: 100, description: '', planId: null, link: '', batchIds: [] };
    this.selectedBatchIds = [];
    this.editingId = null;
    this.showForm = false;
  }

}
