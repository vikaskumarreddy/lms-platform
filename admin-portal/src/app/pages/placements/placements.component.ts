import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';

interface Drive {
  id: number;
  companyName: string;
  role: string;
  packageAmount: number;
  location: string;
  eligibility: string;
  description: string;
  applyLink: string;
  deadline: string;
  isActive: boolean;
  planId?: number;
}

interface SubscriptionPlan {
  id: number;
  name: string;
  price: number;
  period: string;
}

@Component({
  selector: 'app-placements',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
      <h1 style="font-size:24px;font-weight:700;">Placement Drives</h1>
      <button class="btn btn-primary" (click)="openAddModal()">+ Add Drive</button>
    </div>

    <div class="card">
      <table>
        <thead>
          <tr><th>Company</th><th>Role</th><th>Package</th><th>Location</th><th>Plan</th><th>Deadline</th><th>Status</th><th>Actions</th></tr>
        </thead>
        <tbody>
          <tr *ngFor="let d of drives">
            <td>{{d.companyName}}</td>
            <td>{{d.role}}</td>
            <td>{{d.packageAmount ? '₹' + d.packageAmount + ' LPA' : '-'}}</td>
            <td>{{d.location || '-'}}</td>
            <td>
              <span *ngIf="getPlanName(d.planId)" class="badge badge-warning">⭐ {{getPlanName(d.planId)}}</span>
              <span *ngIf="!getPlanName(d.planId)" style="color:#64748B;font-size:13px;">No plan</span>
            </td>
            <td>{{d.deadline ? (d.deadline | slice:0:10) : '-'}}</td>
            <td><span class="badge" [class.badge-success]="d.isActive" [class.badge-danger]="!d.isActive">{{d.isActive ? 'Active' : 'Inactive'}}</span></td>
            <td>
              <button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;margin-right:8px;" (click)="openEditModal(d)">Edit</button>
              <button class="btn btn-danger" style="padding:4px 12px;font-size:12px;" (click)="deleteDrive(d)">Delete</button>
            </td>
          </tr>
          <tr *ngIf="drives.length === 0">
            <td colspan="8" style="text-align:center;color:#64748B;padding:32px;">No placement drives found. Click "+ Add Drive" to create one.</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Drive Modal -->
    <div class="modal-overlay" *ngIf="showModal" (click)="closeModal($event)">
      <div class="modal-content" style="width:90%;max-width:520px;" (click)="$event.stopPropagation()">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
          <h2 style="font-size:20px;font-weight:700;">{{editingDrive ? 'Edit Drive' : 'Add New Drive'}}</h2>
          <button class="btn btn-secondary" (click)="closeModal()">✕</button>
        </div>

        <form (ngSubmit)="saveDrive()">
          <div style="margin-bottom:20px;">
            <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">Company Name</label>
            <input type="text" [(ngModel)]="driveForm.companyName" name="companyName" required
                   style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;"
                   placeholder="Enter company name">
          </div>

          <div style="margin-bottom:20px;">
            <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">Role</label>
            <input type="text" [(ngModel)]="driveForm.role" name="role" required
                   style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;"
                   placeholder="e.g. SDE-1">
          </div>

          <div style="margin-bottom:20px;">
            <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">Package (LPA)</label>
            <input type="number" [(ngModel)]="driveForm.packageAmount" name="packageAmount"
                   style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;"
                   placeholder="e.g. 25">
          </div>

          <div style="margin-bottom:20px;">
            <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">Location</label>
            <input type="text" [(ngModel)]="driveForm.location" name="location"
                   style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;"
                   placeholder="e.g. Bangalore">
          </div>

          <div style="margin-bottom:20px;">
            <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">Subscription Plan (for access control)</label>
            <select [(ngModel)]="driveForm.planId" name="planId"
                    style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;background:white;">
              <option [ngValue]="null">No plan (free access)</option>
              <option *ngFor="let p of plans" [ngValue]="p.id">{{p.name}} - ₹{{p.price}}{{p.period}}</option>
            </select>
          </div>

          <div style="margin-bottom:20px;">
            <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">Deadline</label>
            <input type="datetime-local" [(ngModel)]="driveForm.deadline" name="deadline"
                   style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;">
          </div>

          <div style="margin-bottom:20px;">
            <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">Eligibility</label>
            <textarea [(ngModel)]="driveForm.eligibility" name="eligibility" rows="2"
                      style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;resize:vertical;"
                      placeholder="Eligibility criteria"></textarea>
          </div>

          <div style="margin-bottom:20px;">
            <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">Description</label>
            <textarea [(ngModel)]="driveForm.description" name="description" rows="3"
                      style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;resize:vertical;"
                      placeholder="Job description"></textarea>
          </div>

          <div style="margin-bottom:20px;">
            <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">Apply Link</label>
            <input type="text" [(ngModel)]="driveForm.applyLink" name="applyLink"
                   style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;"
                   placeholder="https://...">
          </div>

          <div style="margin-bottom:20px;">
            <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">Status</label>
            <select [(ngModel)]="driveForm.isActive" name="isActive"
                    style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;background:white;">
              <option [ngValue]="true">Active</option>
              <option [ngValue]="false">Inactive</option>
            </select>
          </div>

          <div style="display:flex;gap:12px;justify-content:flex-end;margin-top:24px;">
            <button type="button" class="btn btn-secondary" (click)="closeModal()">Cancel</button>
            <button type="submit" class="btn btn-primary" [disabled]="saving">{{saving ? 'Saving...' : (editingDrive ? 'Update Drive' : 'Create Drive')}}</button>
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
export class PlacementsComponent implements OnInit {
  drives: Drive[] = [];
  plans: SubscriptionPlan[] = [];
  showModal = false;
  editingDrive: Drive | null = null;
  saving = false;
  errorMessage = '';

  driveForm: any = {
    companyName: '',
    role: '',
    packageAmount: null,
    location: '',
    eligibility: '',
    description: '',
    applyLink: '',
    deadline: '',
    isActive: true,
    planId: null
  };

  constructor(private apiService: ApiService) {}

  ngOnInit() {
    this.loadDrives();
    this.loadPlans();
  }

  loadDrives() {
    this.apiService.get<Drive[]>('/api/placement-drives').subscribe({
      next: (data) => {
        this.drives = data;
      },
      error: (err) => {
        console.error('Failed to load drives', err);
        this.drives = [];
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

  getPlanName(planId?: number): string {
    if (!planId) return '';
    const plan = this.plans.find(p => p.id === planId);
    return plan ? plan.name : '';
  }

  openAddModal() {
    this.editingDrive = null;
    this.errorMessage = '';
    this.driveForm = {
      companyName: '',
      role: '',
      packageAmount: null,
      location: '',
      eligibility: '',
      description: '',
      applyLink: '',
      deadline: '',
      isActive: true,
      planId: null
    };
    this.showModal = true;
  }

  openEditModal(drive: Drive) {
    this.editingDrive = drive;
    this.errorMessage = '';
    this.driveForm = {
      companyName: drive.companyName,
      role: drive.role,
      packageAmount: drive.packageAmount,
      location: drive.location || '',
      eligibility: drive.eligibility || '',
      description: drive.description || '',
      applyLink: drive.applyLink || '',
      deadline: drive.deadline ? drive.deadline.slice(0, 16) : '',
      isActive: drive.isActive,
      planId: drive.planId || null
    };
    this.showModal = true;
  }

  closeModal(event?: any) {
    this.showModal = false;
    this.editingDrive = null;
    this.errorMessage = '';
  }

  saveDrive() {
    this.saving = true;
    this.errorMessage = '';

    if (this.editingDrive) {
      this.apiService.put(`/api/placement-drives/${this.editingDrive.id}`, this.driveForm).subscribe({
        next: () => {
          this.saving = false;
          this.loadDrives();
          this.closeModal();
        },
        error: (err) => {
          this.saving = false;
          console.error('Failed to update drive', err);
          this.errorMessage = 'Failed to update drive. ' + (err.error?.message || 'Please check the details and try again.');
        }
      });
    } else {
      this.apiService.post('/api/placement-drives', this.driveForm).subscribe({
        next: () => {
          this.saving = false;
          this.loadDrives();
          this.closeModal();
        },
        error: (err) => {
          this.saving = false;
          console.error('Failed to create drive', err);
          this.errorMessage = 'Failed to create drive. ' + (err.error?.message || 'Please check the details and try again.');
        }
      });
    }
  }

  deleteDrive(drive: Drive) {
    if (!confirm(`Are you sure you want to delete "${drive.companyName}" drive?`)) return;
    this.apiService.delete(`/api/placement-drives/${drive.id}`).subscribe({
      next: () => {
        this.loadDrives();
      },
      error: (err) => {
        console.error('Failed to delete drive', err);
        alert('Failed to delete drive');
      }
    });
  }
}