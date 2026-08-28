import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { ApiService } from '../../services/api.service';
import { ApiErrorService } from '../../services/api-error.service';
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
      <button class="btn btn-primary" (click)="openAddModal()">+ Add Exam</button>
    </div>

    <!-- Exam Modal: Fieldset + Legend with Tabbed content to avoid vertical scroll -->
    <div class="modal-overlay" *ngIf="showModal" (click)="closeModal($event)">
      <div class="modal-content" style="width:90%;max-width:680px;" (click)="$event.stopPropagation()">
        <div style="display:none;justify-content:flex-end;margin-bottom:0;">
          <button class="btn btn-secondary btn-sm" (click)="closeModal()">✕</button>
        </div>

        <!-- Step indicator -->
        <div class="popup-steps">
          <div class="popup-step" [class.active]="examTab === 'basic'" [class.completed]="examTab === 'details'">1</div>
          <div class="popup-step-line" [class.completed]="examTab === 'details'"></div>
          <div class="popup-step" [class.active]="examTab === 'details'">2</div>
        </div>

        <!-- Tabs -->
        <div class="popup-tabs">
          <button type="button" [class.active]="examTab === 'basic'" (click)="examTab = 'basic'">🔑 Basic Details</button>
          <button type="button" [class.active]="examTab === 'details'" (click)="examTab = 'details'">📊 Marks & Access</button>
        </div>

        <form (ngSubmit)="save()">
          <!-- Basic tab -->
          <fieldset *ngIf="examTab === 'basic'">
            <legend>{{editingId ? 'Edit Exam' : 'Add New Exam'}}</legend>
            <div class="popup-form-grid">
              <div>
                <label>Exam Title *</label>
                <input type="text" [(ngModel)]="formData.title" name="title" required placeholder="e.g. Java Mid-Term Exam">
              </div>
              <div>
                <label>Course ID</label>
                <input type="number" [(ngModel)]="formData.courseId" name="courseId" placeholder="e.g. 12">
              </div>
              <div>
                <label>Exam Date & Time</label>
                <input type="datetime-local" [(ngModel)]="formData.examDate" name="examDate">
              </div>
              <div>
                <label>Duration (minutes)</label>
                <input type="number" [(ngModel)]="formData.durationMinutes" name="durationMinutes" placeholder="e.g. 120">
              </div>
              <div class="full-width">
                <label>Delivery Mode</label>
                <select [(ngModel)]="formData.deliveryMode" name="deliveryMode">
                  <option value="WEB">Web - open a link</option>
                  <option value="IN_APP">In-App - question paper</option>
                </select>
              </div>
            </div>
          </fieldset>

          <!-- Marks & Access tab -->
          <fieldset *ngIf="examTab === 'details'">
            <legend>Marks & Access</legend>
            <div class="popup-form-grid">
              <div>
                <label>Total Marks</label>
                <input type="number" [(ngModel)]="formData.totalMarks" name="totalMarks" placeholder="e.g. 100">
              </div>
              <div>
                <label>Passing Marks</label>
                <input type="number" [(ngModel)]="formData.passingMarks" name="passingMarks" placeholder="e.g. 40">
              </div>
              <div class="full-width" *ngIf="formData.deliveryMode !== 'IN_APP'">
                <label>Link URL</label>
                <input type="text" [(ngModel)]="formData.link" name="link" placeholder="https://example.com">
              </div>
              <div *ngIf="formData.deliveryMode === 'IN_APP'" class="full-width"
                   style="background:#F0FDFA;border:1px solid #5EEAD4;border-radius:10px;padding:10px 12px;font-size:13px;color:#134E4A;">
                Students answer this inside the app. Save it, then use <strong>Create Paper</strong> in the Actions column to add questions.
              </div>
              <div class="full-width">
                <label>Description</label>
                <textarea [(ngModel)]="formData.description" name="description" rows="3" placeholder="Exam instructions or syllabus"></textarea>
              </div>
              <div>
                <label>Subscription Plan</label>
                <select [(ngModel)]="formData.planId" name="planId">
                  <option [ngValue]="null">All Subscriptions</option>
                  <option *ngFor="let p of plans" [ngValue]="p.id">{{p.name}}</option>
                </select>
              </div>
              <div>
                <label>Batches (Ctrl+Click to select multiple)</label>
                <select [(ngModel)]="selectedBatchIds" name="batchIds" multiple style="min-height:110px;">
                  <option *ngFor="let b of batches" [value]="b.id">{{b.name}}</option>
                </select>
              </div>
            </div>
          </fieldset>

          <!-- Navigation -->
          <div class="popup-nav">
            <button type="button" class="btn btn-secondary" *ngIf="examTab === 'details'" (click)="examTab = 'basic'">← Back</button>
            <button type="button" class="btn btn-primary" *ngIf="examTab === 'basic'" (click)="examTab = 'details'">Next →</button>
            <button type="submit" class="btn btn-accent" *ngIf="examTab === 'details'" [disabled]="saving">{{saving ? 'Saving...' : (editingId ? 'Update Exam' : 'Create Exam')}}</button>
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
      <table><thead><tr><th>Title</th><th>Course</th><th>Date</th><th>Duration</th><th>Subscription</th><th>Batch</th><th>Marks</th><th>Mode</th><th>Link / Paper</th><th>Actions</th></tr></thead>
        <tbody>
          <tr *ngFor="let e of exams">
            <td style="font-weight:600;">{{e.title}}</td>
            <td>{{e.courseId}}</td>
            <td>{{formatDate(e.examDate)}}</td>
            <td>{{e.durationMinutes}} min</td>
            <td><span *ngIf="e.planId" class="badge badge-warning">⭐ {{getPlanName(e.planId)}}</span><span *ngIf="!e.planId" style="color:#64748B;font-size:13px;">All</span></td>
            <td><span *ngIf="e.batchIds?.length" class="badge" style="background:#EEF2FF;color:#4338CA;">👥 {{getBatchNames(e.batchIds)}}</span><span *ngIf="!e.batchIds?.length" style="color:#64748B;font-size:13px;">All</span></td>
            <td>{{e.totalMarks}}</td>
            <td>
              <span class="badge" [style.background]="e.deliveryMode === 'IN_APP' ? '#CCFBF1' : '#EEF2FF'"
                    [style.color]="e.deliveryMode === 'IN_APP' ? '#134E4A' : '#4338CA'">
                {{e.deliveryMode === 'IN_APP' ? 'In-App' : 'Web'}}
              </span>
            </td>
            <td>
              <span *ngIf="e.deliveryMode === 'IN_APP'" class="badge" style="background:#F1F5F9;color:#475569;">
                {{questionCounts[e.id] || 0}} question{{(questionCounts[e.id] || 0) === 1 ? '' : 's'}}
              </span>
              <a *ngIf="e.deliveryMode !== 'IN_APP' && e.link" href="{{e.link}}" target="_blank" style="color:#0F172A;text-decoration:underline;">🔗 Link</a>
              <span *ngIf="e.deliveryMode !== 'IN_APP' && !e.link" style="color:#94A3B8;">-</span>
            </td>
            <td>
              <button *ngIf="e.deliveryMode === 'IN_APP'" class="btn btn-primary" style="padding:4px 12px;font-size:12px;margin-right:8px;" (click)="openPaper(e)">
                {{questionCounts[e.id] ? 'Edit Paper' : 'Create Paper'}}
              </button>
              <button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;margin-right:8px;" (click)="edit(e)">Edit</button>
              <button class="btn" style="background:#FEE2E2;color:#991B1B;padding:4px 12px;font-size:12px;" (click)="delete(e)">Delete</button>
            </td>
          </tr>
          <tr *ngIf="exams.length === 0">
            <td colspan="11" style="text-align:center;padding:32px;color:#64748B;">No exams found. Click "+ Add Exam" to create one.</td>
          </tr>
        </tbody>
      </table>
    </div>
  `
})
export class ExamsAdminComponent implements OnInit {
  private api = inject(ApiService);
  private router = inject(Router);
  private errors = inject(ApiErrorService);
  showModal = false; editingId: number | null = null;
  examTab: 'basic' | 'details' = 'basic';
  saving = false;
  errorMessage = '';
  plans: SubscriptionPlan[] = [];
  batches: Batch[] = [];
  selectedBatchIds: number[] = [];
  /** Question count per exam id, so every In-App row can be badged from one request. */
  questionCounts: Record<number, number> = {};
  formData: any = { title: '', courseId: null, examDate: '', durationMinutes: 120, totalMarks: 100, passingMarks: 40, description: '', planId: null, batchIds: [], link: '', deliveryMode: 'WEB' };
  exams: any[] = [];

  ngOnInit() {
    this.loadPlans();
    this.loadBatches();
    this.loadExams();
    this.loadQuestionCounts();
  }

  /** One request badges every In-App row, instead of one request per row. */
  loadQuestionCounts() {
    this.api.get<Record<string, number>>('/api/assessments/exams/question-counts').subscribe({
      next: (data) => {
        const counts: Record<number, number> = {};
        Object.keys(data || {}).forEach(k => counts[Number(k)] = (data as any)[k]);
        this.questionCounts = counts;
      },
      error: err => this.errors.show(err, 'Could not load question counts')
    });
  }

  openPaper(e: any) {
    this.router.navigate(['/assessment-paper', 'exams', e.id]);
  }

  loadExams() {
    this.api.get<any[]>('/api/exams').subscribe({
      next: (data) => { this.exams = data; },
      error: err => this.errors.show(err, 'Could not load exams')
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

  openAddModal() {
    this.resetFormData();
    this.editingId = null;
    this.examTab = 'basic';
    this.errorMessage = '';
    this.showModal = true;
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
      description: this.formData.description,
      examDate: toIsoDateTime(this.formData.examDate),
      durationMinutes: this.formData.durationMinutes,
      totalMarks: this.formData.totalMarks,
      passingMarks: this.formData.passingMarks,
      batchIds: this.selectedBatchIds.length > 0 ? this.selectedBatchIds : [],
      courseId: Number(this.formData.courseId) || null,
      isActive: true,
      deliveryMode: this.formData.deliveryMode || 'WEB',
      // An in-app paper has no external link; keeping a stale one would confuse the app.
      link: this.formData.deliveryMode === 'IN_APP' ? null : (this.formData.link || null)
    };

    if (this.editingId) {
      this.api.put<any>(`/api/exams/${this.editingId}`, payload).subscribe({
        next: () => {
          const i = this.exams.findIndex(e => e.id === this.editingId);
          if (i > -1) this.exams[i] = { ...payload, id: this.editingId, planId: this.formData.planId, batchIds: this.selectedBatchIds };
          this.saving = false;
          this.resetForm();
        },
        error: (err) => { console.error('Failed to update:', err); this.saving = false; this.errorMessage = 'Failed to update exam'; }
      });
    } else {
      this.api.post<any>('/api/exams', payload).subscribe({
        next: (saved: any) => {
          this.exams.push({ ...payload, id: saved?.id || Date.now(), planId: this.formData.planId, batchIds: this.selectedBatchIds });
          this.saving = false;
          this.resetForm();
        },
        error: (err) => { console.error('Failed to create:', err); this.saving = false; this.errorMessage = 'Failed to create exam'; }
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
      link: e.link || '',
      deliveryMode: e.deliveryMode || 'WEB'
    };
    this.selectedBatchIds = e.batchIds || [];
    this.examTab = 'basic';
    this.errorMessage = '';
    this.showModal = true;
  }

  delete(e: any) {
    if (confirm('Delete exam?')) {
      this.api.delete(`/api/exams/${e.id}`).subscribe({
        next: () => { this.exams = this.exams.filter(x => x.id !== e.id); },
        error: (err) => { console.error('Failed to delete:', err); this.errors.show(err, 'Could not delete exam'); }
      });
    }
  }

  formatDate(value?: string): string {
    return formatDateTimeDisplay(value);
  }

  private resetFormData() {
    this.formData = { title: '', courseId: null, examDate: '', durationMinutes: 120, totalMarks: 100, passingMarks: 40, description: '', planId: null, link: '', batchIds: [], deliveryMode: 'WEB' };
    this.selectedBatchIds = [];
  }

  resetForm() {
    this.resetFormData();
    this.editingId = null;
    this.examTab = 'basic';
    this.saving = false;
    this.errorMessage = '';
    this.showModal = false;
  }

}
