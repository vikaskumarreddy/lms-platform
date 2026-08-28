import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';
import { ApiErrorService } from '../../services/api-error.service';

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
  selector: 'app-qa-admin',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
      <h1 style="font-size:24px;font-weight:700;">💬 Q&A Management</h1>
      <button class="btn btn-primary" (click)="openAddModal()">+ Add Question</button>
    </div>

    <!-- Question Modal: Fieldset + Legend with Tabbed content to avoid vertical scroll -->
    <div class="modal-overlay" *ngIf="showForm" (click)="closeModal($event)">
      <div class="modal-content" style="width:90%;max-width:680px;" (click)="$event.stopPropagation()">
        <div style="display:none;justify-content:flex-end;margin-bottom:0;">
          <button class="btn btn-secondary btn-sm" (click)="closeModal()">✕</button>
        </div>

        <!-- Step indicator -->
        <div class="popup-steps">
          <div class="popup-step" [class.active]="questionTab === 'basic'" [class.completed]="questionTab === 'details'">1</div>
          <div class="popup-step-line" [class.completed]="questionTab === 'details'"></div>
          <div class="popup-step" [class.active]="questionTab === 'details'">2</div>
        </div>

        <!-- Tabs -->
        <div class="popup-tabs">
          <button type="button" [class.active]="questionTab === 'basic'" (click)="questionTab = 'basic'">❓ Question</button>
          <button type="button" [class.active]="questionTab === 'details'" (click)="questionTab = 'details'">📋 Status & Access</button>
        </div>

        <form (ngSubmit)="save()">
          <!-- Question tab -->
          <fieldset *ngIf="questionTab === 'basic'">
            <legend>{{editingId ? 'Edit Question' : 'Add New Question'}}</legend>
            <div class="popup-form-grid">
              <div class="full-width">
                <label>Question Title *</label>
                <input type="text" [(ngModel)]="formData.title" name="title" required placeholder="e.g. How do I handle null in Java streams?">
              </div>
              <div>
                <label>Author Name</label>
                <input type="text" [(ngModel)]="formData.authorName" name="authorName" placeholder="Defaults to Mentor">
              </div>
              <div>
                <label>Category</label>
                <input type="text" [(ngModel)]="formData.category" name="category" placeholder="e.g. Java, SQL, React">
              </div>
              <div class="full-width">
                <label>Question Content</label>
                <textarea [(ngModel)]="formData.content" name="content" rows="4" placeholder="Full question text"></textarea>
              </div>
            </div>
          </fieldset>

          <!-- Status & Access tab -->
          <fieldset *ngIf="questionTab === 'details'">
            <legend>Status & Access</legend>
            <div class="popup-form-grid">
              <div>
                <label>Answer Count</label>
                <input type="number" [(ngModel)]="formData.answerCount" name="answerCount" placeholder="0">
              </div>
              <div>
                <label>Status</label>
                <select [(ngModel)]="formData.isAnswered" name="isAnswered">
                  <option [ngValue]="false">Unanswered</option>
                  <option [ngValue]="true">Answered</option>
                </select>
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
            <button type="button" class="btn btn-secondary" *ngIf="questionTab === 'details'" (click)="questionTab = 'basic'">← Back</button>
            <button type="button" class="btn btn-primary" *ngIf="questionTab === 'basic'" (click)="questionTab = 'details'">Next →</button>
            <button type="submit" class="btn btn-accent" *ngIf="questionTab === 'details'" [disabled]="saving">{{saving ? 'Saving...' : (editingId ? 'Update Question' : 'Create Question')}}</button>
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
      <table><thead><tr><th>Title</th><th>Author</th><th>Category</th><th>Subscription</th><th>Batch</th><th>Answers</th><th>Status</th><th>Actions</th></tr></thead>
      <tbody><tr *ngFor="let q of questions">
        <td style="font-weight:600;">{{q.title}}</td><td>{{q.authorName}}</td><td><span class="badge badge-warning">{{q.category}}</span></td>
        <td><span *ngIf="q.planId" class="badge badge-warning">⭐ {{getPlanName(q.planId)}}</span><span *ngIf="!q.planId" style="color:#64748B;font-size:13px;">All</span></td>
        <td><span *ngIf="q.batchId" class="badge" style="background:#EEF2FF;color:#4338CA;">👥 {{getBatchName(q.batchId)}}</span><span *ngIf="!q.batchId" style="color:#64748B;font-size:13px;">All</span></td>
        <td>{{q.answerCount}}</td>
        <td><span [class.badge-success]="q.isAnswered" [class.badge-danger]="!q.isAnswered" class="badge">{{q.isAnswered ? 'Answered' : 'Open'}}</span></td>
        <td><button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;margin-right:8px;" (click)="edit(q)">Edit</button>
        <button class="btn" style="background:#FEE2E2;color:#991B1B;padding:4px 12px;font-size:12px;" (click)="delete(q)">Delete</button></td>
      </tr>
      <tr *ngIf="questions.length === 0">
        <td colspan="8" style="text-align:center;padding:32px;color:#64748B;">No questions found. Click "+ Add Question" to create one.</td>
      </tr>
      </tbody></table>
    </div>
  `
})
export class QaAdminComponent implements OnInit {
  private api = inject(ApiService);
  private errors = inject(ApiErrorService);
  showForm = false; editingId: number | null = null;
  questionTab: 'basic' | 'details' = 'basic';
  saving = false;
  errorMessage = '';
  plans: SubscriptionPlan[] = [];
  batches: Batch[] = [];
  formData: any = { title: '', authorName: '', category: '', content: '', answerCount: 0, isAnswered: false, planId: null, batchId: null };
  questions: any[] = [];

  ngOnInit() {
    this.loadQuestions();
    this.loadPlans();
    this.loadBatches();
  }

  loadQuestions() {
    this.api.get<any[]>('/api/questions').subscribe({
      next: (data) => { this.questions = data; },
      error: (err) => { console.error('Failed to load questions:', err); }
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

  getBatchName(batchId?: number): string {
    if (!batchId) return '';
    const batch = this.batches.find(b => b.id === batchId);
    return batch ? batch.name : '';
  }

  openAddModal() {
    this.resetFormData();
    this.editingId = null;
    this.questionTab = 'basic';
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
      content: this.formData.content,
      category: this.formData.category,
      authorName: this.formData.authorName || 'Mentor',
      isAnswered: this.formData.isAnswered,
      answerCount: this.formData.answerCount || 0,
      planId: this.formData.planId,
      batchId: this.formData.batchId
    };

    if (this.editingId) {
      this.api.put<any>(`/api/questions/${this.editingId}`, payload).subscribe({
        next: (updated) => {
          const i = this.questions.findIndex(q => q.id === this.editingId);
          if (i > -1) this.questions[i] = updated;
          this.saving = false;
          this.resetForm();
        },
        error: (err) => { console.error('Failed to update question:', err); this.saving = false; this.errorMessage = 'Failed to update question'; }
      });
    } else {
      this.api.post<any>('/api/questions', payload).subscribe({
        next: (created) => {
          this.questions.unshift(created);
          this.saving = false;
          this.resetForm();
        },
        error: (err) => { console.error('Failed to create question:', err); this.saving = false; this.errorMessage = 'Failed to create question'; }
      });
    }
  }

  edit(q: any) {
    this.editingId = q.id;
    this.formData = {
      title: q.title,
      authorName: q.authorName || '',
      category: q.category || '',
      content: q.content || '',
      answerCount: q.answerCount || 0,
      isAnswered: q.isAnswered || false,
      planId: q.planId ?? null,
      batchId: q.batchId ?? null
    };
    this.questionTab = 'basic';
    this.errorMessage = '';
    this.showForm = true;
  }

  delete(q: any) {
    if (confirm('Delete this question?')) {
      this.api.delete(`/api/questions/${q.id}`).subscribe({
        next: () => { this.questions = this.questions.filter(x => x.id !== q.id); },
        error: (err) => { this.errors.show(err, 'Failed to delete question'); }
      });
    }
  }

  private resetFormData() {
    this.formData = { title: '', authorName: '', category: '', content: '', answerCount: 0, isAnswered: false, planId: null, batchId: null };
  }

  resetForm() {
    this.resetFormData();
    this.editingId = null;
    this.questionTab = 'basic';
    this.saving = false;
    this.errorMessage = '';
    this.showForm = false;
  }
}
