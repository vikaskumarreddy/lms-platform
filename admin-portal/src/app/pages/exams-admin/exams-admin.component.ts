import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';
import { formatDateTimeDisplay, toDateTimeLocalValue, toIsoDateTime } from '../../utils/date.util';

interface SubscriptionPlan { id: number; name: string; price: number; period: string; }
interface Batch { id: number; name: string; isActive: boolean; }

@Component({
  selector: 'app-exams-admin',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
      <h1 style="font-size:24px;font-weight:700;">📋 Exams</h1>
      <button class="btn btn-primary" (click)="showForm = !showForm">{{ showForm ? 'Cancel' : '+ Add Exam'}}</button>
    </div>
    <div class="card" *ngIf="showForm" style="margin-bottom:20px;">
      <h3 style="margin-bottom:16px;">{{editingId ? 'Edit' : 'Add New'}} Exam</h3>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;">
        <input [(ngModel)]="formData.title" placeholder="Exam Title" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <input [(ngModel)]="formData.courseId" type="number" placeholder="Course ID" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <div>
          <label style="display:block;margin-bottom:4px;font-weight:600;font-size:14px;">Exam Date & Time</label>
          <input [(ngModel)]="formData.examDate" type="datetime-local" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        </div>
        <input [(ngModel)]="formData.link" placeholder="Link URL (e.g., https://example.com)" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <input [(ngModel)]="formData.durationMinutes" type="number" placeholder="Duration (minutes)" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <input [(ngModel)]="formData.totalMarks" type="number" placeholder="Total Marks" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <input [(ngModel)]="formData.passingMarks" type="number" placeholder="Passing Marks" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
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
      <table><thead><tr><th>Title</th><th>Course</th><th>Date</th><th>Duration</th><th>Subscription</th><th>Batch</th><th>Marks</th><th>Link</th><th>Actions</th></tr></thead>
        <tbody>
          <tr *ngFor="let e of exams">
            <td style="font-weight:600;">{{e.title}}</td>
            <td>{{e.courseId}}</td>
            <td>{{formatDate(e.examDate)}}</td>
            <td>{{e.durationMinutes}} min</td>
            <td><span *ngIf="e.planId" class="badge badge-warning">⭐ {{getPlanName(e.planId)}}</span><span *ngIf="!e.planId" style="color:#64748B;font-size:13px;">All</span></td>
            <td><span *ngIf="e.batchIds?.length" class="badge" style="background:#EEF2FF;color:#4338CA;">👥 {{getBatchNames(e.batchIds)}}</span><span *ngIf="!e.batchIds?.length" style="color:#64748B;font-size:13px;">All</span></td>
            <td>{{e.totalMarks}}</td>
            <td><a *ngIf="e.link" href="{{e.link}}" target="_blank" style="color:#0F172A;text-decoration:underline;">🔗 Link</a><span *ngIf="!e.link" style="color:#94A3B8;">-</span></td>
            <td>
              <button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;margin-right:8px;" (click)="edit(e)">Edit</button>
              <button class="btn" style="background:#FEE2E2;color:#991B1B;padding:4px 12px;font-size:12px;" (click)="delete(e)">Delete</button>
            </td>
          </tr>
          <tr *ngIf="exams.length === 0">
            <td colspan="9" style="text-align:center;padding:32px;color:#64748B;">No exams found. Click "+ Add Exam" to create one.</td>
          </tr>
        </tbody>
      </table>
    </div>
  `
})
export class ExamsAdminComponent implements OnInit {
  private api = inject(ApiService);
  showForm = false; editingId: number | null = null;
  plans: SubscriptionPlan[] = [];
  batches: Batch[] = [];
  selectedBatchIds: number[] = [];
  formData: any = { title: '', courseId: null, examDate: '', durationMinutes: 120, totalMarks: 100, passingMarks: 40, description: '', planId: null, batchIds: [] };
  exams: any[] = [];

  ngOnInit() {
    this.loadPlans();
    this.loadBatches();
    this.loadExams();
  }

  loadExams() {
    this.api.get<any[]>('/api/exams').subscribe({
      next: (data) => { this.exams = data; },
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
      examDate: toIsoDateTime(this.formData.examDate),
      durationMinutes: this.formData.durationMinutes,
      totalMarks: this.formData.totalMarks,
      passingMarks: this.formData.passingMarks,
      batchIds: this.selectedBatchIds.length > 0 ? this.selectedBatchIds : [],
      courseId: Number(this.formData.courseId) || null,
      isActive: true,
      link: this.formData.link || null
    };

    if (this.editingId) {
      this.api.put<any>(`/api/exams/${this.editingId}`, payload).subscribe({
        next: () => {
          const i = this.exams.findIndex(e => e.id === this.editingId);
          if (i > -1) this.exams[i] = { ...payload, id: this.editingId, planId: this.formData.planId, batchIds: this.selectedBatchIds };
          this.resetForm();
        },
        error: (err) => { console.error('Failed to update:', err); alert('Failed to update exam'); }
      });
    } else {
      this.api.post<any>('/api/exams', payload).subscribe({
        next: (saved: any) => {
          this.exams.push({ ...payload, id: saved?.id || Date.now(), planId: this.formData.planId, batchIds: this.selectedBatchIds });
          this.resetForm();
        },
        error: (err) => { console.error('Failed to create:', err); alert('Failed to create exam'); }
      });
    }
  }

  edit(e: any) {
    this.editingId = e.id;
    this.formData = {
      title: e.title,
      courseId: e.courseId,
      examDate: toDateTimeLocalValue(e.examDate),
      durationMinutes: e.durationMinutes || 120,
      totalMarks: e.totalMarks || 100,
      passingMarks: e.passingMarks || 40,
      description: e.description,
      planId: e.planId || null,
      link: e.link || ''
    };
    this.selectedBatchIds = e.batchIds || [];
    this.showForm = true;
  }

  delete(e: any) {
    if (confirm('Delete exam?')) {
      this.api.delete(`/api/exams/${e.id}`).subscribe({
        next: () => { this.exams = this.exams.filter(x => x.id !== e.id); },
        error: (err) => { console.error('Failed to delete:', err); alert('Failed to delete exam'); }
      });
    }
  }

  formatDate(value?: string): string {
    return formatDateTimeDisplay(value);
  }

  resetForm() {
    this.formData = { title: '', courseId: null, examDate: '', durationMinutes: 120, totalMarks: 100, passingMarks: 40, description: '', planId: null, link: '', batchIds: [] };
    this.selectedBatchIds = [];
    this.editingId = null;
    this.showForm = false;
  }

}
