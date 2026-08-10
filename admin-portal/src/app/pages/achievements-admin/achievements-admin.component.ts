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
  selector: 'app-achievements-admin',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
      <h1 style="font-size:24px;font-weight:700;">🏆 Achievements</h1>
      <button class="btn btn-primary" (click)="showForm = !showForm">{{ showForm ? 'Cancel' : '+ Add Achievement'}}</button>
    </div>
    <div class="card" *ngIf="showForm" style="margin-bottom:20px;">
      <h3 style="margin-bottom:16px;">{{editingId ? 'Edit' : 'Add New'}} Achievement</h3>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;">
        <input [(ngModel)]="formData.title" placeholder="Title" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <input [(ngModel)]="formData.description" placeholder="Description" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <input [(ngModel)]="formData.icon" placeholder="Icon (emoji)" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <input [(ngModel)]="formData.points" type="number" placeholder="Points" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <select [(ngModel)]="formData.category" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
          <option value="Learning">Learning</option><option value="Streak">Streak</option><option value="Milestone">Milestone</option><option value="Special">Special</option>
        </select>
        <select [(ngModel)]="formData.unlocked" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
          <option [ngValue]="false">Locked</option><option [ngValue]="true">Unlocked</option>
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
    <div class="grid-2" *ngIf="!showForm">
      <div class="card" *ngFor="let a of achievements">
        <div style="display:flex;align-items:center;gap:16px;">
          <div style="font-size:32px;">{{a.icon}}</div>
          <div><h3 style="font-weight:700;">{{a.title}}</h3><p style="color:#64748B;font-size:14px;">{{a.description}}</p></div>
        </div>
        <div style="margin-top:12px;display:flex;gap:12px;flex-wrap:wrap;">
          <span class="badge badge-warning">{{a.points}} pts</span>
          <span [class.badge-success]="a.unlocked" [class.badge-danger]="!a.unlocked" class="badge">{{a.unlocked ? 'Unlocked' : 'Locked'}}</span>
          <span class="badge badge-success">{{a.category}}</span>
          <span *ngIf="a.planId" class="badge badge-warning">⭐ {{getPlanName(a.planId)}}</span>
          <span *ngIf="a.batchId" class="badge" style="background:#EEF2FF;color:#4338CA;">👥 {{getBatchName(a.batchId)}}</span>
        </div>
        <div style="margin-top:12px;">
          <button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;margin-right:8px;" (click)="edit(a)">Edit</button>
          <button class="btn" style="background:#FEE2E2;color:#991B1B;padding:4px 12px;font-size:12px;" (click)="delete(a)">Delete</button>
        </div>
      </div>
    </div>
  `
})
export class AchievementsAdminComponent implements OnInit {
  private api = inject(ApiService);
  showForm = false; editingId: number | null = null;
  plans: SubscriptionPlan[] = [];
  batches: Batch[] = [];
  formData: any = { title: '', description: '', icon: '🏆', points: 100, category: 'Learning', unlocked: false, planId: null, batchId: null };
  achievements: any[] = [
    { id: 1, title: 'First Steps', description: 'Complete your first lesson', icon: '🎯', points: 50, category: 'Learning', unlocked: true, planId: null, batchId: null },
    { id: 2, title: 'Quiz Master', description: 'Score 100% in 5 quizzes', icon: '🧠', points: 200, category: 'Learning', unlocked: true, planId: null, batchId: null },
    { id: 3, title: '7-Day Streak', description: 'Study for 7 consecutive days', icon: '🔥', points: 150, category: 'Streak', unlocked: true, planId: null, batchId: null },
    { id: 4, title: 'Course Champion', description: 'Complete a full course', icon: '🎓', points: 500, category: 'Milestone', unlocked: false, planId: null, batchId: null },
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

  save() { if (this.editingId) { const i = this.achievements.findIndex(a => a.id === this.editingId); if (i > -1) this.achievements[i] = { ...this.formData, id: this.editingId }; } else { this.achievements.push({ ...this.formData, id: Date.now() }); } this.resetForm(); }
  edit(a: any) { this.editingId = a.id; this.formData = { ...a }; delete (this.formData as any).id; this.showForm = true; }
  delete(a: any) { if (confirm('Delete?')) this.achievements = this.achievements.filter(x => x.id !== a.id); }
  resetForm() { this.formData = { title: '', description: '', icon: '🏆', points: 100, category: 'Learning', unlocked: false, planId: null, batchId: null }; this.editingId = null; this.showForm = false; }
}
