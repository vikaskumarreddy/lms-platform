import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
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
              <button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;margin-right:8px;" (click)="viewStudent(s)">View</button>
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

    <!-- Student Modal (Fieldset + Legend with Tabbed content) -->
    <div class="modal-overlay" *ngIf="showModal" (click)="closeModal($event)">
      <div class="modal-content" style="width:90%;max-width:680px;" (click)="$event.stopPropagation()">
        <div style="display:none;justify-content:flex-end;margin-bottom:0;">
          <button class="btn btn-secondary btn-sm" (click)="closeModal()">✕</button>
        </div>

        <!-- Step indicator -->
        <div class="popup-steps">
          <div class="popup-step" [class.active]="studentTab === 'basic'" [class.completed]="studentTab === 'details'">1</div>
          <div class="popup-step-line" [class.completed]="studentTab === 'details'"></div>
          <div class="popup-step" [class.active]="studentTab === 'details'">2</div>
        </div>

        <!-- Tabs -->
        <div class="popup-tabs">
          <button [class.active]="studentTab === 'basic'" (click)="studentTab = 'basic'">🔑 Basic Details</button>
          <button [class.active]="studentTab === 'details'" (click)="studentTab = 'details'">👤 Profile & Social</button>
        </div>

        <form (ngSubmit)="saveStudent()">
          <!-- Basic tab -->
          <fieldset *ngIf="studentTab === 'basic'">
            <legend>{{editingStudent ? 'Edit Student' : 'Add New Student'}}</legend>
            <div class="popup-form-grid">
              <div>
                <label>Full Name</label>
                <input type="text" [(ngModel)]="studentForm.name" name="name" required placeholder="Enter student name">
              </div>
              <div>
                <label>Email</label>
                <input type="email" [(ngModel)]="studentForm.email" name="email" required placeholder="student@example.com">
              </div>
              <div>
                <label>Phone</label>
                <input type="text" [(ngModel)]="studentForm.phone" name="phone" placeholder="+91 98765 43210">
              </div>
              <div>
                <label>Password</label>
                <input type="password" [(ngModel)]="studentForm.password" name="password" [required]="!editingStudent"
                       placeholder="{{editingStudent ? 'Leave blank to keep current' : 'Enter password'}}">
              </div>
            </div>
          </fieldset>

          <!-- Profile & Social tab -->
          <fieldset *ngIf="studentTab === 'details'">
            <legend>Profile & Social</legend>
            <div class="popup-form-grid">
              <div>
                <label>Batch</label>
                <select [(ngModel)]="studentForm.batchId" name="batchId">
                  <option [ngValue]="null">No batch</option>
                  <option *ngFor="let b of batches" [ngValue]="b.id">{{b.name}}{{b.isActive ? '' : ' (Inactive)'}}</option>
                </select>
              </div>
              <div>
                <label>Subscription Plan</label>
                <select [(ngModel)]="studentForm.planId" name="planId">
                  <option [ngValue]="null">No plan (free access)</option>
                  <option *ngFor="let p of plans" [ngValue]="p.id">{{p.name}} - ₹{{p.price}}{{p.period}}</option>
                </select>
              </div>
              <div class="full-width">
                <label>LinkedIn</label>
                <input type="text" [(ngModel)]="studentForm.linkedin" name="linkedin" placeholder="linkedin.com/in/username">
              </div>
              <div class="full-width">
                <label>GitHub</label>
                <input type="text" [(ngModel)]="studentForm.github" name="github" placeholder="github.com/username">
              </div>
              <div>
                <label>Status</label>
                <select [(ngModel)]="studentForm.isActive" name="isActive">
                  <option [ngValue]="true">Active</option>
                  <option [ngValue]="false">Inactive</option>
                </select>
              </div>
            </div>
          </fieldset>

          <!-- Navigation -->
          <div class="popup-nav">
            <button type="button" class="btn btn-secondary" *ngIf="studentTab === 'details'" (click)="studentTab = 'basic'">← Back</button>
            <button type="button" class="btn btn-primary" *ngIf="studentTab === 'basic'" (click)="studentTab = 'details'">Next →</button>
            <button type="submit" class="btn btn-accent" *ngIf="studentTab === 'details'" [disabled]="loading">{{loading ? 'Saving...' : (editingStudent ? 'Update Student' : 'Create Student')}}</button>
            <span style="flex:1"></span>
            <button type="button" class="btn btn-danger" (click)="closeModal()">Cancel</button>
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
  studentTab: 'basic' | 'details' = 'basic';

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

    constructor(private apiService: ApiService, private router: Router) {}

  viewStudent(student: Student) {
    this.router.navigate(['/students', student.id]);
  }

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
    this.studentTab = 'basic';
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
    this.studentTab = 'basic';
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