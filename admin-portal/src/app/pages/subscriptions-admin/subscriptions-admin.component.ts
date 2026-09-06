import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';
import { ApiErrorService } from '../../services/api-error.service';
import { ConfirmService } from '../../services/confirm.service';

interface Plan {
  id: number;
  name: string;
  description: string;
  price: number;
  durationDays: number;
  isActive: boolean;
  features: string;
  color: string;
  period: string;
  isPopular: boolean;
}

/** A student's request to move plan, raised from the mobile app. */
interface PlanRequest {
  id: number;
  studentId: number;
  studentName: string;
  studentEmail?: string;
  requestedPlanId: number;
  requestedPlanName: string;
  currentPlanId?: number | null;
  currentPlanName?: string | null;
  status: string;
  studentNote?: string | null;
  decisionNote?: string | null;
  createdAt?: string;
  decidedAt?: string | null;
}

interface Subscription {
  id: number;
  user: { id: number; fullName: string; email: string };
  plan: { id: number; name: string };
  status: string;
  startDate: string;
  endDate: string;
}

interface Student {
  id: number;
  name: string;
  email: string;
}

interface StudentSubscription {
  id: number;
  planId: number;
  planName: string;
  status: string;
  startDate: string;
  endDate: string;
}

interface PlanFormData {
  name: string;
  description: string;
  price: number;
  durationDays: number;
  isActive: boolean;
  features: string;
  color: string;
  period: string;
  isPopular: boolean;
}

@Component({
  selector: 'app-subscriptions-admin',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
      <h1 style="font-size:24px;font-weight:700;">⭐ Subscription Plans</h1>
      <button class="btn btn-primary" (click)="showForm = !showForm">{{ showForm ? 'Cancel' : '+ Add Plan' }}</button>
    </div>

    <!-- Upgrade requests. Sits above everything else because it is the only part
         of this page with a queue waiting on the admin. -->
    <div class="card" style="margin-bottom:20px;" *ngIf="planRequests.length || requestsLoaded">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:4px;">
        <h3 style="margin:0;">
          📥 Plan Upgrade Requests
          <span class="badge" *ngIf="pendingRequests.length"
                style="background:#FEF3C7;color:#92400E;margin-left:8px;">
            {{ pendingRequests.length }} pending
          </span>
        </h3>
        <label style="font-size:13px;color:#64748B;display:flex;align-items:center;gap:6px;">
          <input type="checkbox" [(ngModel)]="showDecidedRequests" (change)="loadPlanRequests()">
          Show decided
        </label>
      </div>
      <p style="color:#64748B;font-size:13px;margin:0 0 16px;">
        Raised by students from the mobile app. Approving moves the student onto the plan
        immediately and notifies them.
      </p>

      <table *ngIf="visibleRequests.length">
        <thead>
          <tr>
            <th>Student</th><th>From → To</th><th>Note</th><th>Requested</th><th>Status</th><th>Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr *ngFor="let r of visibleRequests">
            <td>
              <div style="font-weight:600;">{{ r.studentName }}</div>
              <div style="color:#94A3B8;font-size:12px;">{{ r.studentEmail || '—' }}</div>
            </td>
            <td style="font-size:13px;">
              <span style="color:#64748B;">{{ r.currentPlanName || 'No plan' }}</span>
              <span style="margin:0 6px;">→</span>
              <strong>{{ r.requestedPlanName }}</strong>
            </td>
            <td style="max-width:220px;font-size:13px;color:#475569;">
              {{ r.studentNote || '—' }}
              <div *ngIf="r.decisionNote" style="color:#94A3B8;font-size:12px;margin-top:2px;">
                Decision: {{ r.decisionNote }}
              </div>
            </td>
            <td style="font-size:13px;">{{ formatDate(r.createdAt) }}</td>
            <td>
              <span class="badge"
                    [class.badge-warning]="r.status === 'PENDING'"
                    [class.badge-success]="r.status === 'APPROVED'"
                    [class.badge-danger]="r.status === 'REJECTED'">
                {{ r.status }}
              </span>
            </td>
            <td style="white-space:nowrap;">
              <ng-container *ngIf="r.status === 'PENDING'">
                <button class="btn btn-primary" style="padding:6px 12px;font-size:12px;margin-right:6px;"
                        [disabled]="decidingId === r.id" (click)="decideRequest(r, true)">
                  {{ decidingId === r.id ? '…' : 'Approve' }}
                </button>
                <button class="btn btn-danger" style="padding:6px 12px;font-size:12px;"
                        [disabled]="decidingId === r.id" (click)="decideRequest(r, false)">
                  Reject
                </button>
              </ng-container>
              <span *ngIf="r.status !== 'PENDING'" style="color:#94A3B8;font-size:12px;">—</span>
            </td>
          </tr>
        </tbody>
      </table>

      <div *ngIf="!visibleRequests.length" style="color:#64748B;padding:16px;text-align:center;">
        {{ showDecidedRequests ? 'No upgrade requests yet.' : 'No pending requests.' }}
      </div>

      <div *ngIf="requestError" style="margin-top:12px;padding:10px 12px;background:#FEE2E2;color:#991B1B;border-radius:8px;font-size:13px;">
        {{ requestError }}
      </div>
    </div>

    <!-- Plan Form -->
    <div class="card" *ngIf="showForm" style="margin-bottom:20px;">
      <h3 style="margin-bottom:16px;">{{ editingId ? 'Edit' : 'Add New' }} Plan</h3>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;">
        <input [(ngModel)]="formData.name" placeholder="Plan Name" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <input type="number" [(ngModel)]="formData.price" placeholder="Price (e.g. 1999)" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <input type="number" [(ngModel)]="formData.durationDays" placeholder="Duration (days, e.g. 365)" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <input [(ngModel)]="formData.period" placeholder="Period (e.g. /month)" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <input [(ngModel)]="formData.color" placeholder="Color (e.g. #EAB308)" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <select [(ngModel)]="formData.isPopular" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
          <option [ngValue]="false">Not Popular</option>
          <option [ngValue]="true">Popular</option>
        </select>
        <select [(ngModel)]="formData.isActive" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
          <option [ngValue]="true">Active</option>
          <option [ngValue]="false">Inactive</option>
        </select>
        <textarea [(ngModel)]="formData.features" placeholder="Features (comma separated)" rows="3" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;"></textarea>
        <textarea [(ngModel)]="formData.description" placeholder="Description" rows="2" style="grid-column: 1 / -1;width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;"></textarea>
      </div>
      <div style="margin-top:16px;display:flex;gap:12px;">
        <button class="btn btn-primary" (click)="save()">{{ editingId ? 'Update' : 'Create' }}</button>
        <button class="btn" style="background:#E2E8F0;" (click)="resetForm()">Reset</button>
      </div>
      <div *ngIf="errorMsg" style="margin-top:8px;color:#EF4444;font-size:14px;">{{ errorMsg }}</div>
    </div>

    <!-- Plans Grid -->
    <div class="grid-2" *ngIf="!showForm && plans.length">
      <div class="card" *ngFor="let p of plans">
        <div style="display:flex;justify-content:space-between;align-items:center;">
          <h3 style="font-weight:700;color:{{p.color}};">{{ p.name }}</h3>
          <span *ngIf="p.isPopular" class="badge badge-warning">POPULAR</span>
          <span *ngIf="!p.isActive" class="badge badge-danger">INACTIVE</span>
        </div>
        <div style="margin:12px 0;"><span style="font-size:28px;font-weight:700;">₹{{ p.price }}</span><span style="color:#64748B;">{{ p.period }}</span></div>
        <div style="margin:8px 0;font-size:13px;color:#64748B;">{{ p.durationDays }} days · {{ p.description }}</div>
        <div style="margin-top:12px;">
          <div *ngFor="let f of p.features.split(',')" style="display:flex;align-items:center;gap:8px;margin-bottom:6px;">
            <span style="color:#16A34A;">✓</span><span style="font-size:14px;">{{ f.trim() }}</span>
          </div>
        </div>
        <div style="margin-top:12px;">
          <button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;margin-right:8px;" (click)="edit(p)">Edit</button>
          <button class="btn" style="background:#FEE2E2;color:#991B1B;padding:4px 12px;font-size:12px;" (click)="delete(p)">Delete</button>
        </div>
      </div>
    </div>
    <div *ngIf="!showForm && !plans.length && !loading" style="color:#64748B;padding:20px;">No plans found.</div>

    <!-- Map a Student to Multiple Subscriptions -->
    <h2 style="font-size:20px;font-weight:700;margin:24px 0 16px;">Assign Subscription to Student</h2>
    <p style="color:#64748B;margin-bottom:12px;font-size:13px;">
      A student can be subscribed to multiple plans at once (e.g. "Java Full Stack" + "Placement Pro").
      Assigning a plan here adds it to the student's active subscriptions without removing existing ones.
    </p>
    <div class="card" style="margin-bottom:20px;">
      <div style="display:grid;grid-template-columns:1fr 1fr auto;gap:16px;align-items:end;">
        <div>
          <label style="display:block;font-weight:600;margin-bottom:6px;font-size:13px;">Student</label>
          <select [(ngModel)]="assignForm.studentId" (ngModelChange)="onStudentSelected($event)"
                  style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;background:white;">
            <option [ngValue]="null">Select Student</option>
            <option *ngFor="let s of students" [ngValue]="s.id">{{ s.name }} ({{ s.email }})</option>
          </select>
        </div>
        <div>
          <label style="display:block;font-weight:600;margin-bottom:6px;font-size:13px;">Plan</label>
          <select [(ngModel)]="assignForm.planId" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;background:white;">
            <option [ngValue]="null">Select Plan</option>
            <option *ngFor="let p of plans" [ngValue]="p.id">{{ p.name }} - ₹{{ p.price }}{{ p.period }}</option>
          </select>
        </div>
        <button class="btn btn-primary" [disabled]="assigning" (click)="assignSubscription()">
          {{ assigning ? 'Assigning...' : '+ Assign Plan' }}
        </button>
      </div>
      <div *ngIf="assignError" style="margin-top:8px;color:#EF4444;">{{ assignError }}</div>

      <div *ngIf="assignForm.studentId" style="margin-top:20px;">
        <h4 style="font-size:14px;font-weight:700;margin-bottom:8px;">
          Current subscriptions for {{ getStudentName(assignForm.studentId) }}
        </h4>
        <table *ngIf="studentSubscriptions.length">
          <thead><tr><th>Plan</th><th>Status</th><th>Start</th><th>End</th><th>Actions</th></tr></thead>
          <tbody>
            <tr *ngFor="let s of studentSubscriptions">
              <td style="font-weight:600;">{{ s.planName || '—' }}</td>
              <td><span class="badge" [ngClass]="s.status === 'ACTIVE' ? 'badge-success' : 'badge-warning'">{{ s.status }}</span></td>
              <td style="font-size:13px;">{{ s.startDate || '—' }}</td>
              <td style="font-size:13px;">{{ s.endDate || '—' }}</td>
              <td>
                <button class="btn btn-danger" style="padding:4px 12px;font-size:12px;" (click)="removeStudentSubscription(s)">Remove</button>
              </td>
            </tr>
          </tbody>
        </table>
        <div *ngIf="!studentSubscriptions.length" style="color:#64748B;padding:12px;text-align:center;">No subscriptions for this student yet.</div>
      </div>
    </div>

    <!-- All Subscriptions -->
    <h2 style="font-size:20px;font-weight:700;margin:24px 0 16px;">All Subscriptions ({{ subscriptions.length }})</h2>
    <div class="card">
      <table *ngIf="subscriptions.length">
        <thead>
          <tr><th>User</th><th>Plan</th><th>Status</th><th>Start</th><th>End</th></tr>
        </thead>
        <tbody>
          <tr *ngFor="let s of subscriptions">
            <td>{{ s.user?.fullName || s.user?.email || '—' }}</td>
            <td>{{ s.plan?.name || '—' }}</td>
            <td><span class="badge" [ngClass]="s.status === 'ACTIVE' ? 'badge-success' : 'badge-warning'">{{ s.status }}</span></td>
            <td style="font-size:13px;">{{ s.startDate || '—' }}</td>
            <td style="font-size:13px;">{{ s.endDate || '—' }}</td>
          </tr>
        </tbody>
      </table>
      <div *ngIf="!subscriptions.length" style="color:#64748B;padding:16px;text-align:center;">No subscriptions yet.</div>
    </div>
  `
})
export class SubscriptionsAdminComponent implements OnInit {
  private api = inject(ApiService);
  private confirm = inject(ConfirmService);
  private errors = inject(ApiErrorService);
  plans: Plan[] = [];
  subscriptions: Subscription[] = [];
  students: Student[] = [];
  studentSubscriptions: StudentSubscription[] = [];
  showForm = false;
  editingId: number | null = null;
  loading = false;
  errorMsg = '';

  planRequests: PlanRequest[] = [];
  requestsLoaded = false;
  showDecidedRequests = false;
  decidingId: number | null = null;
  requestError = '';

  assignForm: { studentId: number | null; planId: number | null } = { studentId: null, planId: null };
  assigning = false;
  assignError = '';

  formData: PlanFormData = {
    name: '', description: '', price: 0, durationDays: 30, isActive: true,
    features: '', color: '#0F172A', period: '/month', isPopular: false
  };

  ngOnInit() {
    this.loadPlans();
    this.loadSubscriptions();
    this.loadStudents();
    this.loadPlanRequests();
  }

  get pendingRequests(): PlanRequest[] {
    return this.planRequests.filter(r => r.status === 'PENDING');
  }

  /** Pending only by default; decided rows are history and would bury the queue. */
  get visibleRequests(): PlanRequest[] {
    return this.showDecidedRequests ? this.planRequests : this.pendingRequests;
  }

  loadPlanRequests() {
    const status = this.showDecidedRequests ? 'ALL' : 'PENDING';
    this.api.get<PlanRequest[]>(`/api/student-plan-requests?status=${status}`).subscribe({
      next: (data) => { this.planRequests = data || []; this.requestsLoaded = true; },
      error: (err) => {
        console.error('Failed to load plan requests', err);
        this.planRequests = [];
        this.requestsLoaded = true;
      }
    });
  }

  async decideRequest(request: PlanRequest, approve: boolean) {
    const verb = approve ? 'Approve' : 'Reject';
    const confirmText = approve
      ? `Move ${request.studentName} to the ${request.requestedPlanName} plan?`
      : `Reject ${request.studentName}'s request for ${request.requestedPlanName}?`;
    if (!(await this.confirm.confirm(confirmText))) return;

    // A rejection without a reason is unhelpful to the student, so ask for one —
    // but do not force it, since the admin may have explained in person.
    let note: string | null = null;
    if (!approve) {
      note = prompt('Reason (optional, shown to the student):', '');
      if (note === null) return; // cancelled the prompt
    }

    this.decidingId = request.id;
    this.requestError = '';
    const action = approve ? 'approve' : 'reject';

    this.api.put(`/api/student-plan-requests/${request.id}/${action}`, { note }).subscribe({
      next: () => {
        this.decidingId = null;
        this.loadPlanRequests();
        // The student's plan changed, so the assignment tables below are now stale.
        this.loadStudents();
        this.loadSubscriptions();
      },
      error: (err) => {
        this.decidingId = null;
        console.error(`Failed to ${action} request`, err);
        this.requestError = err.error?.error || `Could not ${verb.toLowerCase()} the request.`;
      }
    });
  }

  formatDate(value?: string | null): string {
    if (!value) return '—';
    const d = new Date(value);
    return isNaN(d.getTime()) ? '—' : d.toLocaleDateString('en-IN', {
      day: '2-digit', month: 'short', year: 'numeric'
    });
  }

  loadStudents() {
    this.api.get<Student[]>('/api/students').subscribe({
      next: (data) => { this.students = data; },
      error: () => { this.students = []; }
    });
  }

  getStudentName(studentId: number | null): string {
    if (!studentId) return '';
    const student = this.students.find(s => s.id === studentId);
    return student ? student.name : '';
  }

  onStudentSelected(studentId: number | null) {
    this.studentSubscriptions = [];
    if (!studentId) return;
    this.api.get<StudentSubscription[]>(`/api/students/${studentId}/subscriptions`).subscribe({
      next: (data) => { this.studentSubscriptions = data; },
      error: () => { this.studentSubscriptions = []; }
    });
  }

  assignSubscription() {
    this.assignError = '';
    if (!this.assignForm.studentId) { this.assignError = 'Please select a student'; return; }
    if (!this.assignForm.planId) { this.assignError = 'Please select a plan'; return; }

    this.assigning = true;
    this.api.post(`/api/students/${this.assignForm.studentId}/subscriptions`, { planId: this.assignForm.planId }).subscribe({
      next: () => {
        this.assigning = false;
        this.onStudentSelected(this.assignForm.studentId);
        this.loadSubscriptions();
      },
      error: (err) => {
        this.assigning = false;
        this.assignError = err.error?.message || 'Failed to assign subscription';
      }
    });
  }

  async removeStudentSubscription(sub: StudentSubscription) {
    if (!this.assignForm.studentId) return;
    if (!(await this.confirm.confirm(`Remove "${sub.planName}" subscription?`))) return;
    this.api.delete(`/api/students/${this.assignForm.studentId}/subscriptions/${sub.id}`).subscribe({
      next: () => {
        this.onStudentSelected(this.assignForm.studentId);
        this.loadSubscriptions();
      },
      error: (err) => { this.errors.show(err, 'Could not remove that subscription'); }
    });
  }

  loadPlans() {
    this.loading = true;
    this.api.get<Plan[]>('/api/subscription-plans/admin/all').subscribe({
      next: (data) => { this.plans = data; this.loading = false; },
      error: () => { this.loading = false; }
    });
  }

  loadSubscriptions() {
    this.api.get<Subscription[]>('/api/subscriptions').subscribe({
      next: (data) => { this.subscriptions = data; },
      error: (err) => this.errors.show(err, 'Could not load subscriptions')
    });
  }

  save() {
    this.errorMsg = '';
    if (!this.formData.name) { this.errorMsg = 'Plan name is required'; return; }

    if (this.editingId) {
      this.api.put<Plan>(`/api/subscription-plans/${this.editingId}`, this.formData).subscribe({
        next: () => { this.loadPlans(); this.resetForm(); },
        error: (err) => { this.errorMsg = err.error?.message || 'Failed to update plan'; }
      });
    } else {
      this.api.post<Plan>('/api/subscription-plans', this.formData).subscribe({
        next: () => { this.loadPlans(); this.resetForm(); },
        error: (err) => { this.errorMsg = err.error?.message || 'Failed to create plan'; }
      });
    }
  }

  edit(p: Plan) {
    this.editingId = p.id;
    this.formData = { ...p };
    this.showForm = true;
  }

  async delete(p: Plan) {
    if (await this.confirm.confirm(`Delete plan "${p.name}"?`)) {
      this.api.delete<void>(`/api/subscription-plans/${p.id}`).subscribe({
        next: () => this.loadPlans(),
        error: (err) => { this.errorMsg = err.error?.message || 'Failed to delete plan'; }
      });
    }
  }

  resetForm() {
    this.formData = {
      name: '', description: '', price: 0, durationDays: 30, isActive: true,
      features: '', color: '#0F172A', period: '/month', isPopular: false
    };
    this.editingId = null;
    this.showForm = false;
    this.errorMsg = '';
  }
}
