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
      <button class="btn btn-primary" (click)="openAddModal()">
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" style="vertical-align:-2px;margin-right:6px;">
          <line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
        </svg>
        Add Assignment
      </button>
    </div>
    <!-- Assignment Modal (Fieldset + Legend with Tabbed content) -->
    <div class="modal-overlay" *ngIf="showModal" (click)="closeModal($event)">
      <div class="modal-content" style="width:90%;max-width:680px;" (click)="$event.stopPropagation()">
        <div style="display:none;justify-content:flex-end;margin-bottom:0;">
          <button class="btn btn-secondary btn-sm" (click)="closeModal()">X</button>
        </div>

        <!-- Step indicator -->
        <div class="popup-steps">
          <div class="popup-step" [class.active]="assignTab === 'basic'" [class.completed]="assignTab === 'details'">1</div>
          <div class="popup-step-line" [class.completed]="assignTab === 'details'"></div>
          <div class="popup-step" [class.active]="assignTab === 'details'">2</div>
        </div>

        <!-- Tabs -->
        <div class="popup-tabs">
          <button [class.active]="assignTab === 'basic'" (click)="assignTab = 'basic'">Basic Details</button>
          <button [class.active]="assignTab === 'details'" (click)="assignTab = 'details'">Access & Description</button>
        </div>

        <form (ngSubmit)="save()">
          <!-- Basic tab -->
          <fieldset *ngIf="assignTab === 'basic'">
            <legend>{{editingId ? 'Edit Assignment' : 'Add New Assignment'}}</legend>
            <div class="popup-form-grid">
              <div class="full-width">
                <label>Title *</label>
                <input type="text" [(ngModel)]="formData.title" name="title" required placeholder="Assignment title">
              </div>
              <div>
                <label>Course ID</label>
                <input type="number" [(ngModel)]="formData.courseId" name="courseId" placeholder="e.g. 1">
              </div>
              <div>
                <label>Due Date & Time</label>
                <input type="datetime-local" [(ngModel)]="formData.dueDate" name="dueDate">
              </div>
              <div>
                <label>Link URL</label>
                <input type="text" [(ngModel)]="formData.link" name="link" placeholder="https://example.com">
              </div>
            </div>
          </fieldset>

          <!-- Access & Description tab -->
          <fieldset *ngIf="assignTab === 'details'">
            <legend>Access & Description</legend>
            <div class="popup-form-grid">
              <div>
                <label>Status</label>
                <select [(ngModel)]="formData.status" name="status">
                  <option value="Pending">Pending</option>
                  <option value="Graded">Graded</option>
                  <option value="Overdue">Overdue</option>
                </select>
              </div>
              <div>
                <label>Total Marks</label>
                <input type="number" [(ngModel)]="formData.marks" name="marks" placeholder="e.g. 100">
              </div>
              <div class="full-width">
                <label>Description</label>
                <textarea [(ngModel)]="formData.description" name="description" rows="3" placeholder="Assignment description"></textarea>
              </div>
              <div>
                <label>Subscription Plan</label>
                <select [(ngModel)]="formData.planId" name="planId">
                  <option [ngValue]="null">All Subscriptions</option>
                  <option *ngFor="let p of plans" [ngValue]="p.id">{{p.name}}</option>
                </select>
              </div>
              <div class="full-width">
                <label>Batches (Ctrl+Click to select multiple)</label>
                <select [(ngModel)]="selectedBatchIds" multiple name="batchIds" style="min-height:100px;">
                  <option *ngFor="let b of batches" [value]="b.id">{{b.name}}</option>
                </select>
              </div>
            </div>
          </fieldset>

          <!-- Navigation -->
          <div class="popup-nav">
            <button type="button" class="btn btn-secondary" *ngIf="assignTab === 'details'" (click)="assignTab = 'basic'">Back</button>
            <button type="button" class="btn btn-primary" *ngIf="assignTab === 'basic'" (click)="assignTab = 'details'">Next</button>
            <button type="submit" class="btn btn-accent" *ngIf="assignTab === 'details'" [disabled]="saving">{{saving ? 'Saving...' : (editingId ? 'Update Assignment' : 'Create Assignment')}}</button>
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
  showModal = false; editingId: number | null = null;
  assignTab: 'basic' | 'details' = 'basic';
  saving = false;
  errorMessage = '';
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

  openAddModal() {
    this.editingId = null;
    this.errorMessage = '';
    this.assignTab = 'basic';
    this.formData = { title: '', courseId: null, dueDate: '', status: 'Pending', marks: 100, description: '', planId: null, batchIds: [], link: '' };
    this.selectedBatchIds = [];
    this.showModal = true;
  }

  closeModal(event?: any) {
    this.showModal = false;
    this.editingId = null;
    this.errorMessage = '';
  }

  edit(a: any) {
    this.editingId = a.id;
    this.assignTab = 'basic';
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
    this.showModal = true;
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
    this.assignTab = 'basic';
    this.showModal = false;
  }

}
