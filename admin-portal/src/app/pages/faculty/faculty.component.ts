import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';

interface Faculty {
  id: number;
  name: string;
  email: string;
  phone?: string;
  role: string;
  isActive: boolean;
}

@Component({
  selector: 'app-faculty',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
      <h1 style="font-size:24px;font-weight:700;">Faculty</h1>
      <button class="btn btn-primary" (click)="openAddModal()">+ Add Faculty</button>
    </div>

    <div class="card">
      <table>
        <thead>
          <tr><th>ID</th><th>Name</th><th>Email</th><th>Phone</th><th>Status</th><th>Actions</th></tr>
        </thead>
        <tbody>
          <tr *ngFor="let f of faculty">
            <td>{{f.id}}</td>
            <td>{{f.name}}</td>
            <td>{{f.email}}</td>
            <td>{{f.phone || '-'}}</td>
            <td><span class="badge" [class.badge-success]="f.isActive" [class.badge-danger]="!f.isActive">{{f.isActive ? 'Active' : 'Inactive'}}</span></td>
            <td>
              <button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;margin-right:8px;" (click)="openEditModal(f)">Edit</button>
              <button class="btn btn-danger" style="padding:4px 12px;font-size:12px;" (click)="deleteFaculty(f)">Delete</button>
            </td>
          </tr>
          <tr *ngIf="faculty.length === 0">
            <td colspan="6" style="text-align:center;color:#64748B;padding:32px;">No faculty found. Click "+ Add Faculty" to create one.</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Faculty Modal (Fieldset + Legend) -->
    <div class="modal-overlay" *ngIf="showModal" (click)="closeModal($event)">
      <div class="modal-content" style="width:90%;max-width:560px;" (click)="$event.stopPropagation()">
        <div style="display:none;justify-content:flex-end;margin-bottom:0;">
          <button class="btn btn-secondary btn-sm" (click)="closeModal()">✕</button>
        </div>

        <form (ngSubmit)="saveFaculty()">
          <fieldset>
            <legend>{{editingFaculty ? 'Edit Faculty' : 'Add New Faculty'}}</legend>
            <div class="popup-form-grid">
              <div>
                <label>Full Name</label>
                <input type="text" [(ngModel)]="facultyForm.name" name="name" required placeholder="Enter faculty name">
              </div>
              <div>
                <label>Email</label>
                <input type="email" [(ngModel)]="facultyForm.email" name="email" required placeholder="faculty@example.com">
              </div>
              <div>
                <label>Phone</label>
                <input type="text" [(ngModel)]="facultyForm.phone" name="phone" placeholder="+91 98765 43210">
              </div>
              <div>
                <label>Password</label>
                <input type="password" [(ngModel)]="facultyForm.password" name="password" [required]="!editingFaculty"
                       placeholder="{{editingFaculty ? 'Leave blank to keep current' : 'Enter password'}}">
              </div>
              <div>
                <label>Status</label>
                <select [(ngModel)]="facultyForm.isActive" name="isActive">
                  <option [ngValue]="true">Active</option>
                  <option [ngValue]="false">Inactive</option>
                </select>
              </div>
            </div>
          </fieldset>

          <div class="popup-nav">
            <span style="flex:1"></span>
            <button type="button" class="btn btn-danger" (click)="closeModal()">Cancel</button>
            <button type="submit" class="btn btn-accent" [disabled]="loading">{{loading ? 'Saving...' : (editingFaculty ? 'Update Faculty' : 'Create Faculty')}}</button>
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
export class FacultyComponent implements OnInit {
  faculty: Faculty[] = [];
  showModal = false;
  editingFaculty: Faculty | null = null;
  loading = false;
  errorMessage = '';

  facultyForm: any = {
    name: '',
    email: '',
    phone: '',
    password: '',
    isActive: true
  };

  constructor(private apiService: ApiService) {}

  ngOnInit() {
    this.loadFaculty();
  }

  loadFaculty() {
    this.apiService.get<Faculty[]>('/api/faculty').subscribe({
      next: (data) => {
        this.faculty = data;
      },
      error: (err) => {
        console.error('Failed to load faculty', err);
        this.faculty = [];
      }
    });
  }

  openAddModal() {
    this.editingFaculty = null;
    this.errorMessage = '';
    this.facultyForm = {
      name: '',
      email: '',
      phone: '',
      password: '',
      isActive: true
    };
    this.showModal = true;
  }

  openEditModal(f: Faculty) {
    this.editingFaculty = f;
    this.errorMessage = '';
    this.facultyForm = {
      name: f.name,
      email: f.email,
      phone: f.phone || '',
      password: '',
      isActive: f.isActive
    };
    this.showModal = true;
  }

  closeModal(event?: any) {
    this.showModal = false;
    this.editingFaculty = null;
    this.errorMessage = '';
  }

  saveFaculty() {
    this.loading = true;
    this.errorMessage = '';

    if (this.editingFaculty) {
      this.apiService.put(`/api/faculty/${this.editingFaculty.id}`, this.facultyForm).subscribe({
        next: () => {
          this.loading = false;
          this.loadFaculty();
          this.closeModal();
        },
        error: (err) => {
          this.loading = false;
          console.error('Failed to update faculty', err);
          this.errorMessage = 'Failed to update faculty. ' + (err.error?.message || 'Please check the details and try again.');
        }
      });
    } else {
      this.apiService.post('/api/faculty', this.facultyForm).subscribe({
        next: () => {
          this.loading = false;
          this.loadFaculty();
          this.closeModal();
        },
        error: (err) => {
          this.loading = false;
          console.error('Failed to create faculty', err);
          this.errorMessage = 'Failed to create faculty. ' + (err.error?.message || 'Please check the details and try again.');
        }
      });
    }
  }

  deleteFaculty(f: Faculty) {
    if (!confirm(`Are you sure you want to delete "${f.name}"?`)) return;
    this.apiService.delete(`/api/faculty/${f.id}`).subscribe({
      next: () => {
        this.loadFaculty();
      },
      error: (err) => {
        console.error('Failed to delete faculty', err);
        alert('Failed to delete faculty');
      }
    });
  }
}