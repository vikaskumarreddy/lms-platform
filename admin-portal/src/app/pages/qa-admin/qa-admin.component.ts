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
        <input [(ngModel)]="formData.author" placeholder="Author Name" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
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
        <td style="font-weight:600;">{{q.title}}</td><td>{{q.author}}</td><td><span class="badge badge-warning">{{q.category}}</span></td>
        <td><span *ngIf="q.planId" class="badge badge-warning">⭐ {{getPlanName(q.planId)}}</span><span *ngIf="!q.planId" style="color:#64748B;font-size:13px;">All</span></td>
        <td><span *ngIf="q.batchId" class="badge" style="background:#EEF2FF;color:#4338CA;">👥 {{getBatchName(q.batchId)}}</span><span *ngIf="!q.batchId" style="color:#64748B;font-size:13px;">All</span></td>
        <td>{{q.answerCount}}</td>
        <td><span [class.badge-success]="q.isAnswered" [class.badge-danger]="!q.isAnswered" class="badge">{{q.isAnswered ? 'Answered' : 'Open'}}</span></td>
        <td><button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;margin-right:8px;" (click)="edit(q)">Edit</button>
        <button class="btn" style="background:#FEE2E2;color:#991B1B;padding:4px 12px;font-size:12px;" (click)="delete(q)">Delete</button></td>
      </tr></tbody></table>
    </div>
  `
})
export class QaAdminComponent implements OnInit {
  private api = inject(ApiService);
  showForm = false; editingId: number | null = null;
  plans: SubscriptionPlan[] = [];
  batches: Batch[] = [];
  formData: any = { title: '', author: '', category: '', content: '', answerCount: 0, isAnswered: false, planId: null, batchId: null };
  questions: any[] = [
    { id: 1, title: 'How to use Java Streams?', author: 'John Doe', category: 'Java', content: 'Can someone explain Java Streams?', answerCount: 3, isAnswered: true, planId: null, batchId: null },
    { id: 2, title: 'SQL JOIN vs Subquery', author: 'Jane Smith', category: 'SQL', content: 'Which is better for performance?', answerCount: 2, isAnswered: true, planId: null, batchId: null },
    { id: 3, title: 'React useEffect cleanup', author: 'Mike Johnson', category: 'React', content: 'How to properly cleanup useEffect?', answerCount: 0, isAnswered: false, planId: null, batchId: null },
  ];

  ngOnInit() {
    this.loadPlans();
    this.loadBatches();
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

  save() { if (this.editingId) { const i = this.questions.findIndex(q => q.id === this.editingId); if (i > -1) this.questions[i] = { ...this.formData, id: this.editingId }; } else { this.questions.push({ ...this.formData, id: Date.now() }); } this.resetForm(); }
  edit(q: any) { this.editingId = q.id; this.formData = { ...q }; delete (this.formData as any).id; this.showForm = true; }
  delete(q: any) { if (confirm('Delete?')) this.questions = this.questions.filter(x => x.id !== q.id); }
  resetForm() { this.formData = { title: '', author: '', category: '', content: '', answerCount: 0, isAnswered: false, planId: null, batchId: null }; this.editingId = null; this.showForm = false; }
}
