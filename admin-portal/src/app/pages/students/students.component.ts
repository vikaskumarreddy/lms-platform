import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';

interface Student {
  id: number;
  name: string;
  email: string;
  phone?: string;
  username?: string;
  role: string;
  isActive: boolean;
  isEmailVerified: boolean;
  planId?: number;
  batchId?: number;
  linkedin?: string;
  github?: string;
  createdAt?: string;
}

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
  selector: 'app-students',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
      <h1 style="font-size:24px;font-weight:700;">Students</h1>
      <button class="btn btn-primary" (click)="openAddModal()">+ Add Student</button>
    </div>

    <div class="card">
      <table>
        <thead>
          <tr>
            <th>ID</th>
            <th>Name</th>
            <th>Email</th>
            <th>Phone</th>
            <th>Batch</th>
            <th>Subscription Plan</th>
            <th>Status</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr *ngFor="let s of students">
            <td>{{s.id}}</td>
            <td>{{s.name}}</td>
            <td>{{s.email}}</td>
            <td>{{s.phone || '-'}}</td>
            <td>
              <span *ngIf="getBatchName(s.batchId)" class="badge" style="background:#EEF2FF;color:#4338CA;">👥 {{getBatchName(s.batchId)}}</span>
              <span *ngIf="!getBatchName(s.batchId)" style="color:#64748B;font-size:13px;">No batch</span>
            </td>
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
              <button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;margin-right:8px;" (click)="openEditModal(s)">Edit</button>
              <button class="btn btn-danger" style="padding:4px 12px;font-size:12px;" (click)="deleteStudent(s)">Delete</button>
            </td>
          </tr>
          <tr *ngIf="students.length === 0">
            <td colspan="8" style="text-align:center;color:#64748B;padding:32px;">No students found. Click "+ Add Student" to create one.</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Student Modal -->
    <div class="modal-overlay" *ngIf="showModal" (click)="closeModal($event)">
      <div class="modal-content" style="width:90%;max-width:520px;" (click)="$event.stopPropagation()">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
          <h2 style="font-size:20px;font-weight:700;">{{editingStudent ? 'Edit Student' : 'Add New Student'}}</h2>
          <button class="btn btn-secondary" (click)="closeModal()">✕</button>
        </div>

        <form (ngSubmit)="saveStudent()">
          <div style="margin-bottom:20px;">
            <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">Full Name</label>
            <input type="text" [(ngModel)]="studentForm.name" name="name" required
                   style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;"
                   placeholder="Enter student name">
          </div>

          <div style="margin-bottom:20px;">
            <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">Email</label>
            <input type="email" [(ngModel)]="studentForm.email" name="email" required
                   style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;"
                   placeholder="student@example.com">
          </div>

          <div style="margin-bottom:20px;">
            <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">Phone</label>
            <input type="text" [(ngModel)]="studentForm.phone" name="phone"
                   style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;"
                   placeholder="+91 98765 43210">
          </div>

          <div style="margin-bottom:20px;">
            <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">Password</label>
            <input type="password" [(ngModel)]="studentForm.password" name="password"
                   [required]="!editingStudent"
                   style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;"
                   placeholder="{{editingStudent ? 'Leave blank to keep current' : 'Enter password'}}">
          </div>

          <div style="margin-bottom:20px;">
            <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">Batch</label>
            <select [(ngModel)]="studentForm.batchId" name="batchId"
                    style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;background:white;">
              <option [ngValue]="null">No batch</option>
              <option *ngFor="let b of batches" [ngValue]="b.id">{{b.name}}{{b.isActive ? '' : ' (Inactive)'}}</option>
            </select>
          </div>

          <div style="margin-bottom:20px;">
            <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">Subscription Plan (for access control)</label>
            <select [(ngModel)]="studentForm.planId" name="planId"
                    style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;background:white;">
              <option [ngValue]="null">No plan (free access)</option>
              <option *ngFor="let p of plans" [ngValue]="p.id">{{p.name}} - ₹{{p.price}}{{p.period}}</option>
            </select>
          </div>

          <div style="margin-bottom:20px;">
            <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">LinkedIn</label>
            <input type="text" [(ngModel)]="studentForm.linkedin" name="linkedin"
                   style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;"
                   placeholder="linkedin.com/in/username">
          </div>

          <div style="margin-bottom:20px;">
            <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">GitHub</label>
            <input type="text" [(ngModel)]="studentForm.github" name="github"
                   style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;"
                   placeholder="github.com/username">
          </div>

          <div style="margin-bottom:20px;">
            <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">Status</label>
            <select [(ngModel)]="studentForm.isActive" name="isActive"
                    style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;background:white;">
              <option [ngValue]="true">Active</option>
              <option [ngValue]="false">Inactive</option>
            </select>
          </div>

          <div style="display:flex;gap:12px;justify-content:flex-end;margin-top:24px;">
            <button type="button" class="btn btn-secondary" (click)="closeModal()">Cancel</button>
            <button type="submit" class="btn btn-primary" [disabled]="loading">{{loading ? 'Saving...' : (editingStudent ? 'Update Student' : 'Create Student')}}</button>
          </div>
        </form>

        <div *ngIf="errorMessage" style="margin-top:16px;padding:12px;background:#FEE2E2;color:#991B1B;border-radius:8px;font-size:14px;">
          {{errorMessage}}
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
export class StudentsComponent implements OnInit {
  students: Student[] = [];
  plans: SubscriptionPlan[] = [];
  batches: Batch[] = [];
  showModal = false;
  editingStudent: Student | null = null;
  loading = false;
  errorMessage = '';

  studentForm: any = {
    name: '',
    email: '',
    phone: '',
    password: '',
    isActive: true,
    planId: null,
    batchId: null,
    linkedin: '',
    github: ''
  };

  constructor(private apiService: ApiService) {}

  ngOnInit() {
    this.loadStudents();
    this.loadPlans();
    this.loadBatches();
  }

  loadStudents() {
    this.apiService.get<Student[]>('/api/students').subscribe({
      next: (data) => {
        this.students = data;
      },
      error: (err) => {
        console.error('Failed to load students', err);
        this.students = [];
      }
    });
  }

  loadPlans() {
    this.apiService.get<SubscriptionPlan[]>('/api/subscription-plans/admin/all').subscribe({
      next: (data) => {
        this.plans = data;
      },
      error: (err) => {
        console.error('Failed to load subscription plans', err);
        this.plans = [];
      }
    });
  }

  loadBatches() {
    this.apiService.get<Batch[]>('/api/batches').subscribe({
      next: (data) => {
        this.batches = data;
      },
      error: (err) => {
        console.error('Failed to load batches', err);
        this.batches = [];
      }
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
    this.editingStudent = null;
    this.errorMessage = '';
    this.studentForm = {
      name: '',
      email: '',
      phone: '',
      password: '',
      isActive: true,
      planId: null,
      batchId: null,
      linkedin: '',
      github: ''
    };
    this.showModal = true;
  }

  openEditModal(student: Student) {
    this.editingStudent = student;
    this.errorMessage = '';
    this.studentForm = {
      name: student.name,
      email: student.email,
      phone: student.phone || '',
      password: '',
      isActive: student.isActive,
      planId: student.planId || null,
      batchId: student.batchId || null,
      linkedin: student.linkedin || '',
      github: student.github || ''
    };
    this.showModal = true;
  }

  closeModal(event?: any) {
    this.showModal = false;
    this.editingStudent = null;
    this.errorMessage = '';
  }

  saveStudent() {
    this.loading = true;
    this.errorMessage = '';

    if (this.editingStudent) {
      this.apiService.put(`/api/students/${this.editingStudent.id}`, this.studentForm).subscribe({
        next: () => {
          this.loading = false;
          this.loadStudents();
          this.closeModal();
        },
        error: (err) => {
          this.loading = false;
          console.error('Failed to update student', err);
          this.errorMessage = 'Failed to update student. ' + (err.error?.message || 'Please check the details and try again.');
        }
      });
    } else {
      this.apiService.post('/api/students', this.studentForm).subscribe({
        next: () => {
          this.loading = false;
          this.loadStudents();
          this.closeModal();
        },
        error: (err) => {
          this.loading = false;
          console.error('Failed to create student', err);
          this.errorMessage = 'Failed to create student. ' + (err.error?.message || 'Please check the details and try again.');
        }
      });
    }
  }

  deleteStudent(student: Student) {
    if (!confirm(`Are you sure you want to delete "${student.name}"?`)) return;
    this.apiService.delete(`/api/students/${student.id}`).subscribe({
      next: () => {
        this.loadStudents();
      },
      error: (err) => {
        console.error('Failed to delete student', err);
        alert('Failed to delete student');
      }
    });
  }
}