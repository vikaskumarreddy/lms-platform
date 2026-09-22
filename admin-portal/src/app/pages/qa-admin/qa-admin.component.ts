import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';
import { ApiErrorService } from '../../services/api-error.service';
import { ConfirmService } from '../../services/confirm.service';

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
        <td><button class="btn btn-primary" style="padding:4px 12px;font-size:12px;margin-right:8px;" (click)="viewQuestion(q)">💬 View & Resolve</button>
        <button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;margin-right:8px;" (click)="edit(q)">Edit</button>
        <button class="btn" style="background:#FEE2E2;color:#991B1B;padding:4px 12px;font-size:12px;" (click)="delete(q)">Delete</button></td>
      </tr>
      <tr *ngIf="questions.length === 0">
        <td colspan="8" style="text-align:center;padding:32px;color:#64748B;">No questions found. Click "+ Add Question" to create one.</td>
      </tr>
      </tbody></table>
    </div>

    <!-- View & Resolve Modal -->
    <div class="modal-overlay" *ngIf="resolvingQuestion" (click)="closeResolveModal($event)">
      <div class="modal-content" style="width:90%;max-width:760px;max-height:90vh;overflow-y:auto;" (click)="$event.stopPropagation()">
        <div style="display:flex;justify-content:space-between;align-items:flex-start;border-bottom:1px solid #E2E8F0;padding-bottom:12px;margin-bottom:16px;">
          <div>
            <span class="badge" [class.badge-success]="resolvingQuestion.isAnswered" [class.badge-danger]="!resolvingQuestion.isAnswered">
              {{resolvingQuestion.isAnswered ? 'Resolved / Answered' : 'Unresolved Doubt'}}
            </span>
            <span class="badge badge-warning" style="margin-left:8px;">{{resolvingQuestion.category || 'General'}}</span>
            <h2 style="font-size:20px;font-weight:700;margin:8px 0 4px 0;">{{resolvingQuestion.title}}</h2>
            <div style="font-size:13px;color:#64748B;">
              Asked by <strong>{{resolvingQuestion.authorName || 'Student'}}</strong>
              <span *ngIf="resolvingQuestion.createdAt"> • {{resolvingQuestion.createdAt | date:'medium'}}</span>
            </div>
          </div>
          <button class="btn btn-secondary btn-sm" (click)="closeResolveModal()">✕</button>
        </div>

        <div style="background:#F8FAFC;padding:16px;border-radius:8px;border:1px solid #E2E8F0;margin-bottom:20px;">
          <h4 style="font-size:14px;font-weight:600;color:#334155;margin-bottom:8px;">Question Details:</h4>
          <p style="white-space:pre-wrap;color:#1E293B;font-size:14px;line-height:1.6;margin:0;">
            {{resolvingQuestion.content || 'No additional content provided.'}}
          </p>
        </div>

        <!-- Answers Section -->
        <h3 style="font-size:16px;font-weight:700;margin-bottom:12px;display:flex;align-items:center;gap:8px;">
          💡 Existing Answers ({{answers.length}})
          <span *ngIf="loadingAnswers" style="font-size:12px;font-weight:normal;color:#64748B;">Loading...</span>
        </h3>

        <div *ngIf="answers.length === 0 && !loadingAnswers" style="padding:16px;background:#F1F5F9;border-radius:8px;color:#64748B;font-size:14px;text-align:center;margin-bottom:20px;">
          No answers yet. Post faculty answer below to resolve this doubt!
        </div>

        <div *ngFor="let ans of answers" style="background:#FFFFFF;border:1px solid #E2E8F0;border-radius:8px;padding:14px;margin-bottom:12px;">
          <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;">
            <div style="display:flex;align-items:center;gap:8px;">
              <span style="font-weight:600;font-size:13px;color:#0F172A;">{{ans.authorName || 'Faculty'}}</span>
              <span *ngIf="ans.createdAt" style="font-size:12px;color:#94A3B8;">{{ans.createdAt | date:'short'}}</span>
            </div>
            <button class="btn" style="background:#FEE2E2;color:#991B1B;padding:2px 8px;font-size:11px;" (click)="deleteAnswer(ans.id)">Delete</button>
          </div>
          <p style="white-space:pre-wrap;color:#334155;font-size:13px;line-height:1.5;margin:0;">{{ans.content}}</p>
        </div>

        <!-- Post Resolution / Answer Form -->
        <div style="border-top:1px solid #E2E8F0;padding-top:16px;margin-top:16px;">
          <h4 style="font-size:14px;font-weight:600;color:#0F172A;margin-bottom:10px;">Post Resolution / Faculty Answer</h4>
          <div style="margin-bottom:10px;">
            <label style="display:block;font-size:12px;font-weight:600;color:#475569;margin-bottom:4px;">Author / Faculty Name</label>
            <input type="text" [(ngModel)]="newAnswerAuthor" placeholder="e.g. Dr. Instructor / Academy Team" style="width:100%;padding:8px;border:1px solid #CBD5E1;border-radius:6px;font-size:13px;">
          </div>
          <div style="margin-bottom:12px;">
            <label style="display:block;font-size:12px;font-weight:600;color:#475569;margin-bottom:4px;">Answer / Solution Content *</label>
            <textarea [(ngModel)]="newAnswerContent" rows="4" placeholder="Explain the concept or provide solution steps here..." style="width:100%;padding:8px;border:1px solid #CBD5E1;border-radius:6px;font-size:13px;"></textarea>
          </div>
          <div style="display:flex;justify-content:space-between;align-items:center;">
            <button class="btn btn-secondary" (click)="toggleResolvedStatus()">
              {{resolvingQuestion.isAnswered ? 'Mark as Open / Unresolved' : 'Mark as Resolved'}}
            </button>
            <button class="btn btn-primary" [disabled]="submittingAnswer || !newAnswerContent.trim()" (click)="submitAnswer()">
              {{submittingAnswer ? 'Posting...' : '✓ Submit Answer & Resolve'}}
            </button>
          </div>
        </div>
      </div>
    </div>
  `
})
export class QaAdminComponent implements OnInit {
  private api = inject(ApiService);
  private confirm = inject(ConfirmService);
  private errors = inject(ApiErrorService);
  showForm = false; editingId: number | null = null;
  questionTab: 'basic' | 'details' = 'basic';
  saving = false;
  errorMessage = '';
  plans: SubscriptionPlan[] = [];
  batches: Batch[] = [];
  formData: any = { title: '', authorName: '', category: '', content: '', answerCount: 0, isAnswered: false, planId: null, batchId: null };
  questions: any[] = [];
  resolvingQuestion: any = null;
  answers: any[] = [];
  loadingAnswers = false;
  newAnswerAuthor = 'Faculty Team';
  newAnswerContent = '';
  submittingAnswer = false;

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

  async delete(q: any) {
    if (await this.confirm.confirm('Delete this question?')) {
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

  viewQuestion(q: any) {
    this.resolvingQuestion = q;
    this.newAnswerContent = '';
    this.loadAnswersForQuestion(q.id);
  }

  closeResolveModal(event?: Event) {
    if (event && event.target !== event.currentTarget) return;
    this.resolvingQuestion = null;
    this.answers = [];
    this.newAnswerContent = '';
  }

  loadAnswersForQuestion(questionId: number) {
    this.loadingAnswers = true;
    this.api.get<any[]>(`/api/questions/${questionId}/answers`).subscribe({
      next: (data) => {
        this.answers = data || [];
        this.loadingAnswers = false;
      },
      error: (err) => {
        console.error('Failed to load answers:', err);
        this.loadingAnswers = false;
      }
    });
  }

  submitAnswer() {
    if (!this.resolvingQuestion || !this.newAnswerContent.trim()) return;
    this.submittingAnswer = true;
    const payload = {
      content: this.newAnswerContent.trim(),
      authorName: this.newAnswerAuthor || 'Faculty Team',
      isAccepted: true
    };

    this.api.post<any>(`/api/questions/${this.resolvingQuestion.id}/answers`, payload).subscribe({
      next: (created) => {
        this.answers.push(created);
        this.newAnswerContent = '';
        this.submittingAnswer = false;
        // Update status in local question object
        this.resolvingQuestion.isAnswered = true;
        this.resolvingQuestion.answerCount = (this.resolvingQuestion.answerCount || 0) + 1;
        const idx = this.questions.findIndex(q => q.id === this.resolvingQuestion.id);
        if (idx > -1) {
          this.questions[idx].isAnswered = true;
          this.questions[idx].answerCount = this.resolvingQuestion.answerCount;
        }
      },
      error: (err) => {
        this.submittingAnswer = false;
        this.errors.show(err, 'Failed to post answer');
      }
    });
  }

  async deleteAnswer(answerId: number) {
    if (await this.confirm.confirm('Delete this answer?')) {
      this.api.delete(`/api/questions/answers/${answerId}`).subscribe({
        next: () => {
          this.answers = this.answers.filter(a => a.id !== answerId);
          if (this.resolvingQuestion) {
            this.resolvingQuestion.answerCount = Math.max(0, (this.resolvingQuestion.answerCount || 1) - 1);
            if (this.answers.length === 0) {
              this.resolvingQuestion.isAnswered = false;
            }
            const idx = this.questions.findIndex(q => q.id === this.resolvingQuestion.id);
            if (idx > -1) {
              this.questions[idx].answerCount = this.resolvingQuestion.answerCount;
              this.questions[idx].isAnswered = this.resolvingQuestion.isAnswered;
            }
          }
        },
        error: (err) => this.errors.show(err, 'Failed to delete answer')
      });
    }
  }

  toggleResolvedStatus() {
    if (!this.resolvingQuestion) return;
    const newStatus = !this.resolvingQuestion.isAnswered;
    const payload = {
      ...this.resolvingQuestion,
      isAnswered: newStatus
    };
    this.api.put<any>(`/api/questions/${this.resolvingQuestion.id}`, payload).subscribe({
      next: (updated) => {
        this.resolvingQuestion.isAnswered = updated.isAnswered;
        const idx = this.questions.findIndex(q => q.id === this.resolvingQuestion.id);
        if (idx > -1) {
          this.questions[idx].isAnswered = updated.isAnswered;
        }
      },
      error: (err) => this.errors.show(err, 'Failed to update status')
    });
  }
}
