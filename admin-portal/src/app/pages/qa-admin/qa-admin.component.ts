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
  selector: 'app-qa-admin',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
      <h1 style="font-size:24px;font-weight:700;">💬 Q&A Management</h1>
      <button class="btn btn-primary" (click)="showForm = !showForm">{{ showForm ? 'Cancel' : '+ Add Question'}}</button>
    </div>
    <div class="card" *ngIf="showForm" style="margin-bottom:20px;">
      <h3 style="margin-bottom:16px;">{{editingId ? 'Edit' : 'Add New'}} Question</h3>
      <div style="display:grid;gap:16px;">
        <input [(ngModel)]="formData.title" placeholder="Question Title" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <input [(ngModel)]="formData.authorName" placeholder="Author Name" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <input [(ngModel)]="formData.category" placeholder="Category (e.g. Java, SQL, React)" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <textarea [(ngModel)]="formData.content" placeholder="Question Content" rows="3" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;"></textarea>
        <input [(ngModel)]="formData.answerCount" type="number" placeholder="Answer Count" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <select [(ngModel)]="formData.isAnswered" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
          <option [ngValue]="false">Unanswered</option><option [ngValue]="true">Answered</option>
        </select>
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
  showForm = false; editingId: number | null = null;
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

  save() {
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
          this.resetForm();
        },
        error: (err) => { console.error('Failed to update question:', err); alert('Failed to update question'); }
      });
    } else {
      this.api.post<any>('/api/questions', payload).subscribe({
        next: (created) => {
          this.questions.unshift(created);
          this.resetForm();
        },
        error: (err) => { console.error('Failed to create question:', err); alert('Failed to create question'); }
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
    this.showForm = true;
  }

  delete(q: any) {
    if (confirm('Delete this question?')) {
      this.api.delete(`/api/questions/${q.id}`).subscribe({
        next: () => { this.questions = this.questions.filter(x => x.id !== q.id); },
        error: (err) => { console.error('Failed to delete question:', err); alert('Failed to delete question'); }
      });
    }
  }

  resetForm() {
    this.formData = { title: '', authorName: '', category: '', content: '', answerCount: 0, isAnswered: false, planId: null, batchId: null };
    this.editingId = null;
    this.showForm = false;
  }
}
