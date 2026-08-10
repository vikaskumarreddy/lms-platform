import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';

interface Batch {
  id: number;
  name: string;
  description?: string;
  planId?: number;
  startDate?: string;
  endDate?: string;
  isActive: boolean;
  maxStudents?: number;
  schedule?: string;
  createdAt?: string;
}

interface Student {
  id: number;
  name: string;
  email: string;
  phone?: string;
  isActive: boolean;
  planId?: number;
  batchId?: number;
}

interface SubscriptionPlan {
  id: number;
  name: string;
  price: number;
  period: string;
}

@Component({
  selector: 'app-batches',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
      <h1 style="font-size:24px;font-weight:700;">👥 Batches</h1>
      <button class="btn btn-primary" (click)="openAddModal()">+ Create Batch</button>
    </div>

    <div class="card" style="margin-bottom:20px;">
      <table>
        <thead>
          <tr>
            <th>ID</th>
            <th>Batch Name</th>
            <th>Subscription Plan</th>
            <th>Start Date</th>
            <th>End Date</th>
            <th>Students</th>
            <th>Status</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr *ngFor="let b of batches">
            <td>{{b.id}}</td>
            <td style="font-weight:600;">{{b.name}}</td>
            <td>
              <span *ngIf="getPlanName(b.planId)" class="badge badge-warning">⭐ {{getPlanName(b.planId)}}</span>
              <span *ngIf="!getPlanName(b.planId)" style="color:#64748B;font-size:13px;">No plan</span>
            </td>
            <td>{{formatDate(b.startDate)}}</td>
            <td>{{formatDate(b.endDate)}}</td>
            <td>
              <span class="badge" style="background:#EEF2FF;color:#4338CA;">{{getBatchStudentCount(b.id)}} students</span>
            </td>
            <td>
              <span class="badge" [class.badge-success]="b.isActive" [class.badge-danger]="!b.isActive">
                {{b.isActive ? 'Active' : 'Inactive'}}
              </span>
            </td>
            <td>
              <button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;margin-right:8px;" (click)="viewBatch(b)">👥 Manage</button>
              <button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;margin-right:8px;" (click)="openEditModal(b)">Edit</button>
              <button class="btn btn-danger" style="padding:4px 12px;font-size:12px;" (click)="deleteBatch(b)">Delete</button>
            </td>
          </tr>
          <tr *ngIf="batches.length === 0">
            <td colspan="8" style="text-align:center;color:#64748B;padding:32px;">No batches found. Click "+ Create Batch" to create one.</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Batch Form Modal -->
    <div class="modal-overlay" *ngIf="showModal" (click)="closeModal($event)">
      <div class="modal-content" style="width:90%;max-width:560px;" (click)="$event.stopPropagation()">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
          <h2 style="font-size:20px;font-weight:700;">{{editingBatch ? 'Edit Batch' : 'Create New Batch'}}</h2>
          <button class="btn btn-secondary" (click)="closeModal()">✕</button>
        </div>

        <form (ngSubmit)="saveBatch()">
          <div style="margin-bottom:20px;">
            <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">Batch Name *</label>
            <input type="text" [(ngModel)]="batchForm.name" name="name" required
                   style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;"
                   placeholder="e.g. Java Full Stack - Jan 2026">
          </div>

          <div style="margin-bottom:20px;">
            <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">Description</label>
            <textarea [(ngModel)]="batchForm.description" name="description" rows="2"
                      style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;"
                      placeholder="Batch description"></textarea>
          </div>

          <div style="margin-bottom:20px;">
            <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">Subscription Plan</label>
            <select [(ngModel)]="batchForm.planId" name="planId"
                    style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;background:white;">
              <option [ngValue]="null">No plan</option>
              <option *ngFor="let p of plans" [ngValue]="p.id">{{p.name}} - ₹{{p.price}}{{p.period}}</option>
            </select>
          </div>

          <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-bottom:20px;">
            <div>
              <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">Start Date</label>
              <input type="datetime-local" [(ngModel)]="batchForm.startDate" name="startDate"
                     style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;">
            </div>
            <div>
              <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">End Date</label>
              <input type="datetime-local" [(ngModel)]="batchForm.endDate" name="endDate"
                     style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;">
            </div>
          </div>

          <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-bottom:20px;">
            <div>
              <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">Max Students</label>
              <input type="number" [(ngModel)]="batchForm.maxStudents" name="maxStudents"
                     style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;"
                     placeholder="e.g. 50">
            </div>
            <div>
              <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">Schedule</label>
              <input type="text" [(ngModel)]="batchForm.schedule" name="schedule"
                     style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;"
                     placeholder="e.g. Mon/Wed/Fri 10am-12pm">
            </div>
          </div>

          <div style="margin-bottom:20px;">
            <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">Status</label>
            <select [(ngModel)]="batchForm.isActive" name="isActive"
                    style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;background:white;">
              <option [ngValue]="true">Active</option>
              <option [ngValue]="false">Inactive</option>
            </select>
          </div>

          <div style="display:flex;gap:12px;justify-content:flex-end;margin-top:24px;">
            <button type="button" class="btn btn-secondary" (click)="closeModal()">Cancel</button>
            <button type="submit" class="btn btn-primary" [disabled]="loading">{{loading ? 'Saving...' : (editingBatch ? 'Update Batch' : 'Create Batch')}}</button>
          </div>
        </form>

        <div *ngIf="errorMessage" style="margin-top:16px;padding:12px;background:#FEE2E2;color:#991B1B;border-radius:8px;font-size:14px;">
          {{errorMessage}}
        </div>
      </div>
    </div>

    <!-- Batch Detail / Manage Students Modal -->
    <div class="modal-overlay" *ngIf="showBatchDetail" (click)="closeBatchDetail($event)">
      <div class="modal-content" style="width:90%;max-width:800px;" (click)="$event.stopPropagation()">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
          <div>
            <h2 style="font-size:20px;font-weight:700;">👥 {{selectedBatch?.name}}</h2>
            <div style="margin-top:8px;display:flex;gap:16px;flex-wrap:wrap;">
              <span style="font-size:13px;color:#64748B;" *ngIf="getPlanName(selectedBatch?.planId)">⭐ {{getPlanName(selectedBatch?.planId)}}</span>
              <span style="font-size:13px;color:#64748B;" *ngIf="selectedBatch?.startDate">📅 {{formatDate(selectedBatch?.startDate)}} → {{formatDate(selectedBatch?.endDate)}}</span>
              <span style="font-size:13px;color:#64748B;" *ngIf="selectedBatch?.maxStudents">👤 Max: {{selectedBatch?.maxStudents}}</span>
              <span style="font-size:13px;color:#64748B;" *ngIf="selectedBatch?.schedule">🕐 {{selectedBatch?.schedule}}</span>
            </div>
            <div style="margin-top:8px;font-size:13px;color:#64748B;" *ngIf="selectedBatch?.description">{{selectedBatch?.description}}</div>
          </div>
          <button class="btn btn-secondary" (click)="closeBatchDetail()">✕</button>
        </div>

        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px;">
          <h3 style="font-weight:700;font-size:16px;">Students in this batch ({{batchStudents.length}})</h3>
          <button class="btn btn-primary" style="padding:6px 14px;font-size:12px;" (click)="showAddStudent = !showAddStudent">
            {{ showAddStudent ? 'Cancel' : '+ Add Student to Batch' }}
          </button>
        </div>

        <!-- Add student to batch -->
        <div *ngIf="showAddStudent" class="card" style="margin-bottom:16px;padding:16px;background:#F8FAFC;">
          <div style="display:flex;gap:12px;align-items:center;">
            <select [(ngModel)]="selectedStudentId" style="flex:1;padding:10px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;background:white;">
              <option [ngValue]="null">Select a student to add...</option>
              <option *ngFor="let s of availableStudents" [ngValue]="s.id">{{s.name}} ({{s.email}})</option>
            </select>
            <button class="btn btn-primary" (click)="addStudentToBatch()" [disabled]="!selectedStudentId">Add</button>
          </div>
          <div *ngIf="availableStudents.length === 0" style="margin-top:8px;font-size:13px;color:#64748B;">All students are already in this batch or no students exist.</div>
        </div>

        <div class="card" style="padding:0;overflow:hidden;">
          <table>
            <thead>
              <tr>
                <th>ID</th>
                <th>Name</th>
                <th>Email</th>
                <th>Phone</th>
                <th>Plan</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr *ngFor="let s of batchStudents">
                <td>{{s.id}}</td>
                <td style="font-weight:600;">{{s.name}}</td>
                <td>{{s.email}}</td>
                <td>{{s.phone || '-'}}</td>
                <td>
                  <span *ngIf="getPlanName(s.planId)" class="badge badge-warning">⭐ {{getPlanName(s.planId)}}</span>
                  <span *ngIf="!getPlanName(s.planId)" style="color:#64748B;font-size:13px;">No plan</span>
                </td>
                <td>
                  <span class="badge" [class.badge-success]="s.isActive" [class.badge-danger]="!s.isActive">
                    {{s.isActive ? 'Active' : 'Inactive'}}
                  </span>
                </td>
                <td>
                  <button class="btn btn-danger" style="padding:4px 12px;font-size:12px;" (click)="removeStudentFromBatch(s)">Remove</button>
                </td>
              </tr>
              <tr *ngIf="batchStudents.length === 0">
                <td colspan="7" style="text-align:center;color:#64748B;padding:32px;">No students in this batch yet. Click "+ Add Student to Batch" to assign students.</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  `,
  styles: [`
    .modal-overlay {
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(0,0,0,0.5);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 1000;
    }
    .modal-content {
      background: white;
      border-radius: 16px;
      padding: 32px;
      box-shadow: 0 20px 25px -5px rgba(0,0,0,0.1);
      max-height: 90vh;
      overflow-y: auto;
    }
  `]
})
export class BatchesComponent implements OnInit {
  private api = inject(ApiService);

  batches: Batch[] = [];
  allStudents: Student[] = [];
  plans: SubscriptionPlan[] = [];

  showModal = false;
  editingBatch: Batch | null = null;
  loading = false;
  errorMessage = '';

  batchForm: any = {
    name: '',
    description: '',
    planId: null,
    startDate: '',
    endDate: '',
    isActive: true,
    maxStudents: null,
    schedule: ''
  };

  // Batch detail / manage students
  showBatchDetail = false;
  selectedBatch: Batch | null = null;
  batchStudents: Student[] = [];
  showAddStudent = false;
  selectedStudentId: number | null = null;

  ngOnInit() {
    this.loadBatches();
    this.loadStudents();
    this.loadPlans();
  }

  loadBatches() {
    this.api.get<Batch[]>('/api/batches').subscribe({
      next: (data) => { this.batches = data; },
      error: (err) => { console.error('Failed to load batches', err); this.batches = []; }
    });
  }

  loadStudents() {
    this.api.get<Student[]>('/api/students').subscribe({
      next: (data) => { this.allStudents = data; },
      error: (err) => { console.error('Failed to load students', err); this.allStudents = []; }
    });
  }

  loadPlans() {
    this.api.get<SubscriptionPlan[]>('/api/subscription-plans/admin/all').subscribe({
      next: (data) => { this.plans = data; },
      error: (err) => { console.error('Failed to load subscription plans', err); this.plans = []; }
    });
  }

  getPlanName(planId?: number): string {
    if (!planId) return '';
    const plan = this.plans.find(p => p.id === planId);
    return plan ? plan.name : '';
  }

  formatDate(date?: string): string {
    if (!date) return '-';
    try {
      return new Date(date).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
    } catch {
      return date;
    }
  }

  getBatchStudentCount(batchId: number): number {
    return this.allStudents.filter(s => s.batchId === batchId).length;
  }

  openAddModal() {
    this.editingBatch = null;
    this.errorMessage = '';
    this.batchForm = {
      name: '',
      description: '',
      planId: null,
      startDate: '',
      endDate: '',
      isActive: true,
      maxStudents: null,
      schedule: ''
    };
    this.showModal = true;
  }

  openEditModal(batch: Batch) {
    this.editingBatch = batch;
    this.errorMessage = '';
    this.batchForm = {
      name: batch.name,
      description: batch.description || '',
      planId: batch.planId || null,
      startDate: batch.startDate ? new Date(batch.startDate).toISOString().slice(0, 16) : '',
      endDate: batch.endDate ? new Date(batch.endDate).toISOString().slice(0, 16) : '',
      isActive: batch.isActive,
      maxStudents: batch.maxStudents || null,
      schedule: batch.schedule || ''
    };
    this.showModal = true;
  }

  closeModal(event?: any) {
    this.showModal = false;
    this.editingBatch = null;
    this.errorMessage = '';
  }

  saveBatch() {
    if (!this.batchForm.name) {
      this.errorMessage = 'Batch name is required';
      return;
    }
    this.loading = true;
    this.errorMessage = '';

    const payload = { ...this.batchForm };

    if (this.editingBatch) {
      this.api.put(`/api/batches/${this.editingBatch.id}`, payload).subscribe({
        next: () => {
          this.loading = false;
          this.loadBatches();
          this.closeModal();
        },
        error: (err) => {
          this.loading = false;
          console.error('Failed to update batch', err);
          this.errorMessage = 'Failed to update batch. ' + (err.error?.message || 'Please check the details and try again.');
        }
      });
    } else {
      this.api.post('/api/batches', payload).subscribe({
        next: () => {
          this.loading = false;
          this.loadBatches();
          this.closeModal();
        },
        error: (err) => {
          this.loading = false;
          console.error('Failed to create batch', err);
          this.errorMessage = 'Failed to create batch. ' + (err.error?.message || 'Please check the details and try again.');
        }
      });
    }
  }

  deleteBatch(batch: Batch) {
    if (!confirm(`Are you sure you want to delete batch "${batch.name}"? Students will remain but will be unassigned from this batch.`)) return;
    this.api.delete(`/api/batches/${batch.id}`).subscribe({
      next: () => { this.loadBatches(); },
      error: (err) => { console.error('Failed to delete batch', err); alert('Failed to delete batch'); }
    });
  }

  // Batch detail / student management
  viewBatch(batch: Batch) {
    this.selectedBatch = batch;
    this.batchStudents = this.allStudents.filter(s => s.batchId === batch.id);
    this.showAddStudent = false;
    this.selectedStudentId = null;
    this.showBatchDetail = true;
  }

  closeBatchDetail(event?: any) {
    this.showBatchDetail = false;
    this.selectedBatch = null;
    this.batchStudents = [];
    this.showAddStudent = false;
    this.selectedStudentId = null;
  }

  get availableStudents(): Student[] {
    if (!this.selectedBatch) return [];
    return this.allStudents.filter(s => s.batchId !== this.selectedBatch!.id);
  }

  addStudentToBatch() {
    if (!this.selectedBatch || !this.selectedStudentId) return;
    const student = this.allStudents.find(s => s.id === this.selectedStudentId);
    if (!student) return;

    const updatedStudent = { ...student, batchId: this.selectedBatch.id };
    this.api.put(`/api/students/${student.id}`, {
      name: student.name,
      email: student.email,
      phone: student.phone || '',
      isActive: student.isActive,
      planId: student.planId || null,
      batchId: this.selectedBatch.id
    }).subscribe({
      next: () => {
        this.loadStudents();
        this.batchStudents = this.allStudents.filter(s => s.batchId === this.selectedBatch!.id);
        this.selectedStudentId = null;
        this.showAddStudent = false;
      },
      error: (err) => {
        console.error('Failed to add student to batch', err);
        alert('Failed to add student to batch');
      }
    });
  }

  removeStudentFromBatch(student: Student) {
    if (!this.selectedBatch) return;
    if (!confirm(`Remove "${student.name}" from batch "${this.selectedBatch.name}"?`)) return;

    this.api.put(`/api/students/${student.id}`, {
      name: student.name,
      email: student.email,
      phone: student.phone || '',
      isActive: student.isActive,
      planId: student.planId || null,
      batchId: null
    }).subscribe({
      next: () => {
        this.loadStudents();
        this.batchStudents = this.allStudents.filter(s => s.batchId === this.selectedBatch!.id);
      },
      error: (err) => {
        console.error('Failed to remove student from batch', err);
        alert('Failed to remove student from batch');
      }
    });
  }
}