import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';
import { ApiErrorService } from '../../services/api-error.service';
import { ConfirmService } from '../../services/confirm.service';

interface Drive {
  id: number;
  companyName: string;
  companyLogoUrl?: string;
  role: string;
  packageAmount: number;
  location: string;
  eligibility: string;
  description: string;
  applyLink: string;
  deadline: string;
  isActive: boolean;
  planId?: number;
  driveType?: 'INTERNAL' | 'EXTERNAL';
  recruiterToken?: string;
  minAttendancePercent?: number | null;
  minCourseCompletionPercent?: number | null;
  minAssignmentAvgPercent?: number | null;
  minExamAvgPercent?: number | null;
  assignedFacultyId?: number | null;
  facultyName?: string;
  facultyEmail?: string;
}

interface InterviewSlot {
  id: number;
  driveId: number;
  slotTime: string;
  location?: string;
  notes?: string;
  facultyId?: number | null;
  facultyName?: string;
  facultyEmail?: string;
  roomCode?: string;
  bookedByUserId?: number;
  bookedByName?: string;
  bookedByEmail?: string;
  status: 'AVAILABLE' | 'BOOKED' | 'COMPLETED' | 'CANCELLED';
}


interface StudentApplication {
  id: number;
  user: { id: number; name?: string; fullName?: string; email?: string; phone?: string };
  companyName: string;
  role: string;
  driveId?: number;
  status: 'OPEN' | 'APPLIED' | 'SHORTLISTED' | 'TECH_ROUND' | 'OFFER_EXTENDED' | 'SELECTED' | 'REJECTED';
  hiringStage?: string;
  atsScore?: number;
  resumeUrl?: string;
  placedDate?: string;
  createdAt?: string;
}

interface SubscriptionPlan {
  id: number;
  name: string;
  price: number;
  period: string;
}

/** A student's placements question, raised from the mobile app's "Request Support". */
interface SupportRequest {
  id: number;
  studentId: number;
  studentName: string;
  studentEmail?: string;
  driveId?: number | null;
  companyName: string;
  message: string;
  status: 'PENDING' | 'RESPONDED';
  adminResponse?: string | null;
  createdAt?: string;
  decidedAt?: string | null;
}

@Component({
  selector: 'app-placements',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:20px;">
      <h1 style="font-size:24px;font-weight:700;">Placements</h1>
      <button class="btn btn-primary" *ngIf="activeTab === 'drives'" (click)="openAddModal()">
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" style="vertical-align:-2px;margin-right:6px;"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
        Add Drive
      </button>
    </div>

    <div class="popup-tabs" style="margin-bottom:20px;">
      <button [class.active]="activeTab === 'drives'" (click)="activeTab = 'drives'">📋 Drives</button>
      <button [class.active]="activeTab === 'applications'" (click)="activeTab = 'applications'">🎓 Applications</button>
      <button [class.active]="activeTab === 'support'" (click)="activeTab = 'support'">
        💬 Support Requests
        <span class="badge" *ngIf="pendingSupportRequests.length" style="background:#FEF3C7;color:#92400E;margin-left:6px;">
          {{ pendingSupportRequests.length }}
        </span>
      </button>
    </div>

    <ng-container *ngIf="activeTab === 'drives'">
    <div class="card">
      <table>
        <thead>
          <tr><th>Company</th><th>Role</th><th>Type</th><th>Package</th><th>Location</th><th>Plan</th><th>Deadline</th><th>Status</th><th>Actions</th></tr>
        </thead>
        <tbody>
          <tr *ngFor="let d of drives">
            <td>
              <div style="display:flex;align-items:center;gap:8px;">
                <img *ngIf="d.companyLogoUrl" [src]="d.companyLogoUrl" (error)="d.companyLogoUrl = ''" style="width:28px;height:28px;border-radius:6px;object-fit:cover;" alt="">
                <span>{{d.companyName}}</span>
              </div>
            </td>
            <td>{{d.role}}</td>
            <td>
              <span class="badge" [class.badge-success]="d.driveType === 'INTERNAL'" [class.badge-info]="d.driveType !== 'INTERNAL'">
                {{ d.driveType === 'INTERNAL' ? '🏢 Internal' : '🌐 External' }}
              </span>
            </td>
            <td>{{d.packageAmount ? '₹' + d.packageAmount + ' LPA' : '-'}}</td>
            <td>{{d.location || '-'}}</td>
            <td>
              <span *ngIf="getPlanName(d.planId)" class="badge badge-warning">⭐ {{getPlanName(d.planId)}}</span>
              <span *ngIf="!getPlanName(d.planId)" style="color:#64748B;font-size:13px;">No plan</span>
            </td>
            <td>{{d.deadline ? (d.deadline | slice:0:10) : '-'}}</td>
            <td><span class="badge" [class.badge-success]="d.isActive" [class.badge-danger]="!d.isActive">{{d.isActive ? 'Active' : 'Inactive'}}</span></td>
            <td>
              <button *ngIf="d.driveType === 'INTERNAL'" class="icon-btn icon-btn-slot" title="Manage interview slots" (click)="openSlotsModal(d)">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
              </button>
              <button class="icon-btn icon-btn-edit" title="Edit drive" (click)="openEditModal(d)">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20h9"/><path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z"/></svg>
              </button>
              <button class="icon-btn icon-btn-criteria" title="Set eligibility criteria" (click)="openCriteriaModal(d)">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="4" y1="21" x2="4" y2="14"/><line x1="4" y1="10" x2="4" y2="3"/><line x1="12" y1="21" x2="12" y2="12"/><line x1="12" y1="8" x2="12" y2="3"/><line x1="20" y1="21" x2="20" y2="16"/><line x1="20" y1="12" x2="20" y2="3"/><line x1="1" y1="14" x2="7" y2="14"/><line x1="9" y1="8" x2="15" y2="8"/><line x1="17" y1="16" x2="23" y2="16"/></svg>
              </button>
              <button class="icon-btn" title="Copy Recruiter Review Link" (click)="copyRecruiterLink(d)" style="color:#4F46E5;">
                🔗
              </button>
              <button class="icon-btn icon-btn-danger" title="Delete drive" (click)="deleteDrive(d)">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
              </button>
            </td>
          </tr>
          <tr *ngIf="drives.length === 0">
            <td colspan="9" style="text-align:center;color:#64748B;padding:32px;">No placement drives found. Click "+ Add Drive" to create one.</td>
          </tr>
        </tbody>
      </table>
    </div>
    </ng-container>

    <ng-container *ngIf="activeTab === 'applications'">
    <div class="card">
      <table>
        <thead>
          <tr>
            <th>Student</th>
            <th>Company</th>
            <th>Role</th>
            <th>ATS Score</th>
            <th>Hiring Stage</th>
            <th>Status</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr *ngFor="let a of applications">
            <td>
              <div style="font-weight:600;">{{ a.user?.fullName || a.user?.name || a.user?.email || 'Unknown' }}</div>
              <a *ngIf="a.resumeUrl" [href]="a.resumeUrl" target="_blank" style="font-size:11px;color:#2563EB;display:inline-block;margin-top:2px;">📄 View Resume</a>
            </td>
            <td>{{ a.companyName }}</td>
            <td>{{ a.role }}</td>
            <td>
              <span class="badge" [style.background]="getAtsBg(a.atsScore)" [style.color]="getAtsFg(a.atsScore)" style="font-weight:700;">
                🎯 {{ a.atsScore ? a.atsScore + '%' : 'Pending' }}
              </span>
            </td>
            <td>
              <span class="badge" [style.background]="getStageBg(a.hiringStage || a.status)" [style.color]="getStageFg(a.hiringStage || a.status)">
                {{ a.hiringStage || a.status }}
              </span>
            </td>
            <td>
              <span class="badge"
                    [class.badge-success]="a.status === 'SELECTED' || a.status === 'OFFER_EXTENDED'"
                    [class.badge-warning]="a.status === 'APPLIED' || a.status === 'SHORTLISTED' || a.status === 'TECH_ROUND'"
                    [class.badge-danger]="a.status === 'REJECTED'">
                {{ a.status }}
              </span>
            </td>
            <td>
              <select [ngModel]="a.hiringStage || a.status" (ngModelChange)="updateHiringStage(a, $event)"
                      style="padding:6px;border:1px solid #E2E8F0;border-radius:6px;font-size:12px;">
                <option value="APPLIED">Applied</option>
                <option value="SHORTLISTED">Shortlisted</option>
                <option value="TECH_ROUND">Technical Round</option>
                <option value="OFFER_EXTENDED">Offer Extended</option>
                <option value="SELECTED">Selected / Placed</option>
                <option value="REJECTED">Rejected</option>
              </select>
            </td>
          </tr>
          <tr *ngIf="applications.length === 0">
            <td colspan="7" style="text-align:center;color:#64748B;padding:32px;">No student applications yet.</td>
          </tr>
        </tbody>
      </table>
    </div>
    </ng-container>

    <ng-container *ngIf="activeTab === 'support'">
    <div class="card">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;">
        <p style="color:#64748B;font-size:13px;margin:0;">
          Questions students raised about a drive (or an off-list company) from the mobile app.
        </p>
        <label style="font-size:13px;color:#64748B;display:flex;align-items:center;gap:6px;">
          <input type="checkbox" [(ngModel)]="showRespondedRequests" (change)="loadSupportRequests()">
          Show responded
        </label>
      </div>

      <table *ngIf="visibleSupportRequests.length">
        <thead>
          <tr><th>Student</th><th>Company</th><th>Question</th><th>Asked</th><th>Status</th><th>Actions</th></tr>
        </thead>
        <tbody>
          <tr *ngFor="let r of visibleSupportRequests">
            <td>
              <div style="font-weight:600;">{{ r.studentName }}</div>
              <div style="color:#94A3B8;font-size:12px;">{{ r.studentEmail || '—' }}</div>
            </td>
            <td>{{ r.companyName }}</td>
            <td style="max-width:280px;font-size:13px;color:#475569;">
              {{ r.message }}
              <div *ngIf="r.adminResponse" style="color:#0F766E;font-size:12px;margin-top:4px;">
                Response: {{ r.adminResponse }}
              </div>
            </td>
            <td style="font-size:13px;">{{ formatDate(r.createdAt) }}</td>
            <td>
              <span class="badge" [class.badge-warning]="r.status === 'PENDING'" [class.badge-success]="r.status === 'RESPONDED'">
                {{ r.status }}
              </span>
            </td>
            <td>
              <button *ngIf="r.status === 'PENDING'" class="btn btn-primary" style="padding:6px 12px;font-size:12px;"
                      (click)="openRespondModal(r)">Respond</button>
              <span *ngIf="r.status !== 'PENDING'" style="color:#94A3B8;font-size:12px;">—</span>
            </td>
          </tr>
        </tbody>
      </table>

      <div *ngIf="!visibleSupportRequests.length" style="color:#64748B;padding:32px;text-align:center;">
        {{ showRespondedRequests ? 'No support requests yet.' : 'No pending support requests.' }}
      </div>
    </div>
    </ng-container>

    <!-- Respond Modal -->
    <div class="modal-overlay" *ngIf="respondingRequest" (click)="closeRespondModal()">
      <div class="modal-content" style="width:90%;max-width:480px;" (click)="$event.stopPropagation()">
        <fieldset>
          <legend>Respond — {{ respondingRequest.companyName }}</legend>
          <p style="font-size:13px;color:#475569;margin-bottom:12px;">{{ respondingRequest.message }}</p>
          <textarea [(ngModel)]="responseText" name="responseText" rows="4" placeholder="Type your response..."
                    style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;"></textarea>
        </fieldset>
        <div style="display:flex;gap:12px;justify-content:flex-end;margin-top:16px;">
          <button type="button" class="btn btn-secondary" (click)="closeRespondModal()">Cancel</button>
          <button type="button" class="btn btn-primary" [disabled]="savingResponse || !responseText.trim()" (click)="submitResponse()">
            {{ savingResponse ? 'Sending...' : 'Send Response' }}
          </button>
        </div>
      </div>
    </div>

    <!-- Drive Modal: Fieldset + Legend with Tabbed content to avoid vertical scroll -->
    <div class="modal-overlay" *ngIf="showModal" (click)="closeModal($event)">
      <div class="modal-content" style="width:90%;max-width:680px;" (click)="$event.stopPropagation()">
        <div style="display:none;justify-content:flex-end;margin-bottom:0;">
          <button class="btn btn-secondary btn-sm" (click)="closeModal()">✕</button>
        </div>

        <!-- Step indicator -->
        <div class="popup-steps">
          <div class="popup-step" [class.active]="driveTab === 'basic'" [class.completed]="driveTab === 'details'">1</div>
          <div class="popup-step-line" [class.completed]="driveTab === 'details'"></div>
          <div class="popup-step" [class.active]="driveTab === 'details'">2</div>
        </div>

        <!-- Tabs -->
        <div class="popup-tabs">
          <button [class.active]="driveTab === 'basic'" (click)="driveTab = 'basic'">🔑 Basic Details</button>
          <button [class.active]="driveTab === 'details'" (click)="driveTab = 'details'">📋 Full Details</button>
        </div>

        <form (ngSubmit)="saveDrive()">
          <!-- Basic tab -->
          <fieldset *ngIf="driveTab === 'basic'">
            <legend>{{editingDrive ? 'Edit Drive' : 'Add New Drive'}}</legend>
            <div class="popup-form-grid">
              <div>
                <label>Company Name</label>
                <input type="text" [(ngModel)]="driveForm.companyName" name="companyName" required placeholder="Enter company name">
              </div>
              <div>
                <label>Company Logo URL (optional)</label>
                <input type="text" [(ngModel)]="driveForm.companyLogoUrl" name="companyLogoUrl" placeholder="https://…/logo.png">
              </div>
              <div>
                <label>Role</label>
                <input type="text" [(ngModel)]="driveForm.role" name="role" required placeholder="e.g. SDE-1">
              </div>
              <div>
                <label>Drive Type</label>
                <select [(ngModel)]="driveForm.driveType" name="driveType">
                  <option value="EXTERNAL">🌐 External (company-run)</option>
                  <option value="INTERNAL">🏢 Internal (institute-run)</option>
                </select>
              </div>
              <div *ngIf="driveForm.driveType === 'INTERNAL'">
                <label>Assigned Faculty / Interviewer</label>
                <select [(ngModel)]="driveForm.assignedFacultyId" (change)="onFacultySelected()" name="assignedFacultyId">
                  <option [ngValue]="null">Select Faculty Interviewer</option>
                  <option *ngFor="let f of facultyList" [ngValue]="f.id">👨‍🏫 {{f.name}} ({{f.email}})</option>
                </select>
              </div>
              <div>
                <label>Subscription Plan</label>
                <select [(ngModel)]="driveForm.planId" name="planId">
                  <option [ngValue]="null">No plan (free access)</option>
                  <option *ngFor="let p of plans" [ngValue]="p.id">{{p.name}} - ₹{{p.price}}{{p.period}}</option>
                </select>
              </div>
            </div>
          </fieldset>

          <!-- Details tab -->
          <fieldset *ngIf="driveTab === 'details'">
            <legend>Drive Details</legend>
            <div class="popup-form-grid">
              <div>
                <label>Package (LPA)</label>
                <input type="number" [(ngModel)]="driveForm.packageAmount" name="packageAmount" placeholder="e.g. 25">
              </div>
              <div>
                <label>Location</label>
                <input type="text" [(ngModel)]="driveForm.location" name="location" placeholder="e.g. Bangalore">
              </div>
              <div>
                <label>Deadline</label>
                <input type="datetime-local" [(ngModel)]="driveForm.deadline" name="deadline">
              </div>
              <div>
                <label>Status</label>
                <select [(ngModel)]="driveForm.isActive" name="isActive">
                  <option [ngValue]="true">Active</option>
                  <option [ngValue]="false">Inactive</option>
                </select>
              </div>
              <div class="full-width">
                <label>Eligibility</label>
                <textarea [(ngModel)]="driveForm.eligibility" name="eligibility" rows="2" placeholder="Eligibility criteria"></textarea>
              </div>
              <div class="full-width">
                <label>Description</label>
                <textarea [(ngModel)]="driveForm.description" name="description" rows="3" placeholder="Job description"></textarea>
              </div>
              <div class="full-width">
                <label>Apply Link</label>
                <input type="text" [(ngModel)]="driveForm.applyLink" name="applyLink" placeholder="https://...">
              </div>
            </div>
          </fieldset>

          <!-- Navigation -->
          <div class="popup-nav">
            <button type="button" class="btn btn-secondary" *ngIf="driveTab === 'details'" (click)="driveTab = 'basic'">← Back</button>
            <button type="button" class="btn btn-primary" *ngIf="driveTab === 'basic'" (click)="driveTab = 'details'">Next →</button>
            <button type="submit" class="btn btn-accent" *ngIf="driveTab === 'details'" [disabled]="saving">{{saving ? 'Saving...' : (editingDrive ? 'Update Drive' : 'Create Drive')}}</button>
            <span style="flex:1"></span>
            <button type="button" class="btn btn-danger" (click)="closeModal()">Cancel</button>
          </div>
        </form>

        <div *ngIf="errorMessage" style="margin-top:16px;padding:12px;background:#FEE2E2;color:#991B1B;border-radius:8px;font-size:14px;">
          {{errorMessage}}
        </div>
      </div>
    </div>

    <!-- Interview Slots Modal (INTERNAL drives) -->
    <div class="modal-overlay" *ngIf="showSlotsModal" (click)="closeSlotsModal()">
      <div class="modal-content" style="width:90%;max-width:640px;" (click)="$event.stopPropagation()">
        <fieldset>
          <legend>Interview Slots — {{ slotsForDrive?.companyName }}</legend>
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-bottom:16px;">
            <input type="datetime-local" [(ngModel)]="newSlot.slotTime" name="slotTime" style="padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
            <input type="text" [(ngModel)]="newSlot.location" name="slotLocation" placeholder="Location (e.g. Studio Room / Google Meet)" style="padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
            <div>
              <select [(ngModel)]="newSlot.facultyId" name="slotFaculty" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
                <option [ngValue]="null">Interviewer: {{ slotsForDrive?.facultyName || 'Default Drive Faculty' }}</option>
                <option *ngFor="let f of facultyList" [ngValue]="f.id">👨‍🏫 {{f.name}}</option>
              </select>
            </div>
            <input type="text" [(ngModel)]="newSlot.notes" name="slotNotes" placeholder="Notes (optional)" style="padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
          </div>
          <button class="btn btn-primary" (click)="addSlot()" style="margin-bottom:20px;">
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" style="vertical-align:-2px;margin-right:6px;"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
            Add Slot
          </button>

          <table>
            <thead><tr><th>Date & Time</th><th>Interviewer Faculty</th><th>Location</th><th>Status</th><th>Booked By</th><th></th></tr></thead>
            <tbody>
              <tr *ngFor="let s of slots">
                <td style="font-size:13px;">{{ s.slotTime | slice:0:16 }}</td>
                <td style="font-size:13px;font-weight:600;color:#0F172A;">{{ s.facultyName || slotsForDrive?.facultyName || 'Lead Faculty' }}</td>
                <td>{{ s.location || '-' }}</td>
                <td>
                  <span class="badge" [class.badge-success]="s.status === 'BOOKED'" [class.badge-warning]="s.status === 'AVAILABLE'">{{ s.status }}</span>
                </td>
                <td>{{ s.bookedByName || s.bookedByEmail || s.bookedByUserId || '-' }}</td>
                <td><button class="icon-btn icon-btn-danger" title="Delete slot" (click)="deleteSlot(s)">
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
                  </button></td>
              </tr>
              <tr *ngIf="slots.length === 0">
                <td colspan="6" style="text-align:center;color:#64748B;padding:24px;">No interview slots yet. Add one above.</td>
              </tr>
            </tbody>
          </table>
        </fieldset>
        <div style="display:flex;justify-content:flex-end;margin-top:16px;">
          <button class="btn btn-secondary" (click)="closeSlotsModal()">Close</button>
        </div>
      </div>
    </div>

    <!-- Eligibility Criteria Modal -->
    <div class="modal-overlay" *ngIf="showCriteriaModal" (click)="closeCriteriaModal()">
      <div class="modal-content" style="width:90%;max-width:520px;" (click)="$event.stopPropagation()">
        <fieldset>
          <legend>Eligibility Criteria — {{ criteriaDrive?.companyName }}</legend>
          <p style="font-size:12px;color:#64748B;margin-bottom:16px;">
            Optional minimum thresholds (%). A student who does not meet any set
            threshold will see "Not eligible" instead of Apply in the app. Leave blank to skip a rule.
          </p>
          <div class="popup-form-grid" style="font-size:13px;">
            <div>
              <label style="display:block;font-weight:600;margin-bottom:6px;font-size:12px;color:#475569;">Attendance (%)</label>
              <input type="number" min="0" max="100" step="0.1" [(ngModel)]="criteria.minAttendance"
                     name="criteriaAttendance" placeholder="e.g. 75">
            </div>
            <div>
              <label style="display:block;font-weight:600;margin-bottom:6px;font-size:12px;color:#475569;">Course Completion (%)</label>
              <input type="number" min="0" max="100" step="0.1" [(ngModel)]="criteria.minCourseCompletion"
                     name="criteriaCourseCompletion" placeholder="e.g. 80">
            </div>
            <div>
              <label style="display:block;font-weight:600;margin-bottom:6px;font-size:12px;color:#475569;">Assignments Avg Score (%)</label>
              <input type="number" min="0" max="100" step="0.1" [(ngModel)]="criteria.minAssignmentAvg"
                     name="criteriaAssignmentAvg" placeholder="e.g. 70">
            </div>
            <div>
              <label style="display:block;font-weight:600;margin-bottom:6px;font-size:12px;color:#475569;">Exam Avg Score (%)</label>
              <input type="number" min="0" max="100" step="0.1" [(ngModel)]="criteria.minExamAvg"
                     name="criteriaExamAvg" placeholder="e.g. 70">
            </div>
          </div>
        </fieldset>
        <div style="display:flex;gap:12px;justify-content:flex-end;margin-top:16px;">
          <button type="button" class="btn btn-secondary" (click)="closeCriteriaModal()">Cancel</button>
          <button type="button" class="btn btn-primary" [disabled]="savingCriteria" (click)="saveCriteria()">{{savingCriteria ? 'Saving...' : 'Save Criteria'}}</button>
        </div>
        <div *ngIf="criteriaMessage" style="margin-top:16px;padding:12px;background:#DCFCE7;color:#166534;border-radius:8px;font-size:14px;">
          {{criteriaMessage}}
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
      background: var(--surface);
      color: var(--text);
      border-radius: 16px;
      padding: 32px;
      box-shadow: 0 20px 25px -5px rgba(0,0,0,0.1);
      max-height: 90vh;
      overflow-y: auto;
    }
    .modal-content select {
      background: var(--surface);
      color: var(--text);
      border-color: var(--border-light);
    }
    /* Fieldset/legend and field styling is shared -- see .modal-overlay fieldset in styles.css */
    /* Icon-only action buttons */
    .icon-btn{
      display: inline-flex;
      align-items: center;
      justify-content: center;
      width: 30px;
      height: 30px;
      padding: 0;
      border: none;
      border-radius: 8px;
      cursor: pointer;
      background: #F1F5F9;
      color: #334155;
      margin-right: 6px;
      vertical-align: middle;
    }
    .icon-btn svg{display:block}
    .icon-btn:hover{background:#E2E8F0}
    .icon-btn-edit{background:#F1F5F9;color:#334155}
    .icon-btn-edit:hover{background:#E0E7FF;color:#3730A3}
    .icon-btn-slot{background:#FEF3C7;color:#92400E}
    .icon-btn-slot:hover{background:#FDE68A}
    .icon-btn-criteria{background:#EDE9FE;color:#6D28D9}
    .icon-btn-criteria:hover{background:#DDD6FE}
    .icon-btn-danger{background:#FEE2E2;color:#991B1B}
    .icon-btn-danger:hover{background:#FCA5A5}
  `]
})
export class PlacementsComponent implements OnInit {
  private errors = inject(ApiErrorService);
  private confirm = inject(ConfirmService);
  drives: Drive[] = [];
  plans: SubscriptionPlan[] = [];
  applications: StudentApplication[] = [];
  showModal = false;
  editingDrive: Drive | null = null;
  saving = false;
  errorMessage = '';
  driveTab: 'basic' | 'details' = 'basic';

  driveForm: any = {
    companyName: '',
    companyLogoUrl: '',
    role: '',
    driveType: 'EXTERNAL',
    packageAmount: null,
    location: '',
    eligibility: '',
    description: '',
    applyLink: '',
    deadline: '',
    isActive: true,
    planId: null,
    assignedFacultyId: null,
    facultyName: '',
    facultyEmail: ''
  };

  showSlotsModal = false;
  slotsForDrive: Drive | null = null;
  slots: InterviewSlot[] = [];
  newSlot: { slotTime: string; location: string; notes: string; facultyId: number | null } = { slotTime: '', location: '', notes: '', facultyId: null };
  facultyList: any[] = [];

  showCriteriaModal = false;
  criteriaDrive: Drive | null = null;
  criteria = { minAttendance: null as number | null, minCourseCompletion: null as number | null, minAssignmentAvg: null as number | null, minExamAvg: null as number | null };
  savingCriteria = false;
  criteriaMessage = '';

  activeTab: 'drives' | 'applications' | 'support' = 'drives';
  supportRequests: SupportRequest[] = [];
  showRespondedRequests = false;
  respondingRequest: SupportRequest | null = null;
  responseText = '';
  savingResponse = false;

  get pendingSupportRequests(): SupportRequest[] {
    return this.supportRequests.filter(r => r.status === 'PENDING');
  }

  get visibleSupportRequests(): SupportRequest[] {
    return this.showRespondedRequests ? this.supportRequests : this.pendingSupportRequests;
  }

  constructor(private apiService: ApiService) {}

  ngOnInit() {
    this.loadDrives();
    this.loadPlans();
    this.loadApplications();
    this.loadSupportRequests();
    this.loadFaculty();
  }

  loadFaculty() {
    this.apiService.get<any[]>('/api/faculty').subscribe({
      next: (data) => { this.facultyList = data || []; },
      error: () => {
        this.apiService.get<any[]>('/api/users?role=INSTRUCTOR').subscribe({
          next: (d) => { this.facultyList = d || []; },
          error: () => { this.facultyList = []; }
        });
      }
    });
  }

  onFacultySelected() {
    const selected = this.facultyList.find(f => f.id === this.driveForm.assignedFacultyId);
    if (selected) {
      this.driveForm.facultyName = selected.name;
      this.driveForm.facultyEmail = selected.email;
    } else {
      this.driveForm.facultyName = '';
      this.driveForm.facultyEmail = '';
    }
  }

  loadSupportRequests() {
    const status = this.showRespondedRequests ? 'ALL' : 'PENDING';
    this.apiService.get<SupportRequest[]>(`/api/support-requests?status=${status}`).subscribe({
      next: (data) => { this.supportRequests = data; },
      error: (err) => {
        console.error('Failed to load support requests', err);
        this.supportRequests = [];
      }
    });
  }

  openRespondModal(request: SupportRequest) {
    this.respondingRequest = request;
    this.responseText = '';
  }

  closeRespondModal() {
    this.respondingRequest = null;
    this.responseText = '';
    this.savingResponse = false;
  }

  submitResponse() {
    if (!this.respondingRequest || !this.responseText.trim()) return;
    this.savingResponse = true;
    this.apiService.put(`/api/support-requests/${this.respondingRequest.id}/respond`, { response: this.responseText.trim() }).subscribe({
      next: () => {
        this.savingResponse = false;
        this.closeRespondModal();
        this.loadSupportRequests();
      },
      error: (err) => {
        this.savingResponse = false;
        this.errors.show(err, 'Could not send response');
      }
    });
  }

  formatDate(value?: string): string {
    if (!value) return '-';
    const d = new Date(value);
    return isNaN(d.getTime()) ? '-' : d.toLocaleDateString();
  }

  loadApplications() {
    this.apiService.get<StudentApplication[]>('/api/student-placements').subscribe({
      next: (data) => { this.applications = data; },
      error: (err) => { console.error('Failed to load applications', err); this.applications = []; }
    });
  }

  updateApplicationStatus(application: StudentApplication, status: string) {
    this.apiService.put(`/api/student-placements/${application.id}/status`, { status }).subscribe({
      next: () => {
        application.status = status as StudentApplication['status'];
      },
      error: (err) => {
        console.error('Failed to update status', err);
        this.errors.show(err, 'Could not update application status');
      }
    });
  }

  updateHiringStage(application: StudentApplication, stage: string) {
    application.hiringStage = stage;
    let status = 'APPLIED';
    if (stage === 'SELECTED' || stage === 'OFFER_EXTENDED') status = 'SELECTED';
    else if (stage === 'REJECTED') status = 'REJECTED';
    else if (stage === 'SHORTLISTED') status = 'SHORTLISTED';
    else if (stage === 'TECH_ROUND') status = 'TECH_ROUND';

    this.apiService.put(`/api/student-placements/${application.id}/status`, { status }).subscribe({
      next: () => {
        application.status = status as StudentApplication['status'];
        this.errors.success(`Application updated to ${stage}`);
      },
      error: (err) => {
        console.error('Failed to update stage', err);
        this.errors.show(err, 'Could not update application stage');
      }
    });
  }

  getAtsBg(score?: number): string {
    if (!score) return '#F1F5F9';
    if (score >= 80) return '#DCFCE7';
    if (score >= 65) return '#FEF3C7';
    return '#FEE2E2';
  }

  getAtsFg(score?: number): string {
    if (!score) return '#64748B';
    if (score >= 80) return '#166534';
    if (score >= 65) return '#92400E';
    return '#991B1B';
  }

  getStageBg(stage?: string): string {
    switch (stage) {
      case 'SELECTED':
      case 'OFFER_EXTENDED': return '#DCFCE7';
      case 'SHORTLISTED':
      case 'TECH_ROUND': return '#E0E7FF';
      case 'REJECTED': return '#FEE2E2';
      default: return '#FEF3C7';
    }
  }

  getStageFg(stage?: string): string {
    switch (stage) {
      case 'SELECTED':
      case 'OFFER_EXTENDED': return '#166534';
      case 'SHORTLISTED':
      case 'TECH_ROUND': return '#3730A3';
      case 'REJECTED': return '#991B1B';
      default: return '#92400E';
    }
  }

  copyRecruiterLink(d: Drive) {
    const token = d.recruiterToken || d.id;
    const url = `${window.location.origin}/api/student-placements/recruiter/${token}`;
    if (navigator.clipboard) {
      navigator.clipboard.writeText(url).then(() => {
        this.errors.success('Recruiter portal link copied to clipboard!');
      }).catch(() => {
        prompt('Recruiter Portal URL:', url);
      });
    } else {
      prompt('Recruiter Portal URL:', url);
    }
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
    this.driveTab = 'basic';
    this.driveForm = {
      companyName: '',
      role: '',
      driveType: 'EXTERNAL',
      packageAmount: null,
      location: '',
      eligibility: '',
      description: '',
      applyLink: '',
      deadline: '',
      isActive: true,
      planId: null,
      assignedFacultyId: null,
      facultyName: '',
      facultyEmail: ''
    };
    this.showModal = true;
  }

  openEditModal(drive: Drive) {
    this.editingDrive = drive;
    this.errorMessage = '';
    this.driveTab = 'basic';
    this.driveForm = {
      companyName: drive.companyName,
      companyLogoUrl: drive.companyLogoUrl || '',
      role: drive.role,
      driveType: drive.driveType || 'EXTERNAL',
      packageAmount: drive.packageAmount,
      location: drive.location || '',
      eligibility: drive.eligibility || '',
      description: drive.description || '',
      applyLink: drive.applyLink || '',
      deadline: drive.deadline ? drive.deadline.slice(0, 16) : '',
      isActive: drive.isActive,
      planId: drive.planId || null,
      assignedFacultyId: drive.assignedFacultyId || null,
      facultyName: drive.facultyName || '',
      facultyEmail: drive.facultyEmail || ''
    };
    this.showModal = true;
  }

  openCriteriaModal(drive: Drive) {
    this.criteriaDrive = drive;
    this.criteriaMessage = '';
    this.criteria = {
      minAttendance: drive.minAttendancePercent ?? null,
      minCourseCompletion: drive.minCourseCompletionPercent ?? null,
      minAssignmentAvg: drive.minAssignmentAvgPercent ?? null,
      minExamAvg: drive.minExamAvgPercent ?? null
    };
    this.showCriteriaModal = true;
  }

  closeCriteriaModal() {
    this.showCriteriaModal = false;
    this.criteriaDrive = null;
    this.criteriaMessage = '';
  }

  saveCriteria() {
    if (!this.criteriaDrive || this.savingCriteria) return;
    this.savingCriteria = true;
    this.criteriaMessage = '';
    const payload = {
      minAttendancePercent: this.criteria.minAttendance ?? null,
      minCourseCompletionPercent: this.criteria.minCourseCompletion ?? null,
      minAssignmentAvgPercent: this.criteria.minAssignmentAvg ?? null,
      minExamAvgPercent: this.criteria.minExamAvg ?? null
    };
    this.apiService.put(`/api/placement-drives/${this.criteriaDrive.id}/criteria`, payload).subscribe({
      next: () => {
        this.savingCriteria = false;
        this.criteriaMessage = 'Criteria saved successfully.';
        Object.assign(this.criteriaDrive!, payload);
        setTimeout(() => { this.closeCriteriaModal(); }, 900);
      },
      error: (err) => {
        this.savingCriteria = false;
        console.error('Failed to save criteria', err);
        this.errors.show(err, 'Could not save eligibility criteria');
      }
    });
  }

  openSlotsModal(drive: Drive) {
    this.slotsForDrive = drive;
    this.newSlot = { slotTime: '', location: drive.location || '', notes: '', facultyId: drive.assignedFacultyId || null };
    this.showSlotsModal = true;
    this.loadSlots(drive.id);
  }

  closeSlotsModal() {
    this.showSlotsModal = false;
    this.slotsForDrive = null;
    this.slots = [];
  }

  loadSlots(driveId: number) {
    this.apiService.get<InterviewSlot[]>(`/api/interview-slots/drive/${driveId}`).subscribe({
      next: (data) => { this.slots = data; },
      error: () => { this.slots = []; }
    });
  }

  addSlot() {
    if (!this.slotsForDrive || !this.newSlot.slotTime) return;
    const payload = {
      driveId: this.slotsForDrive.id,
      slotTime: this.newSlot.slotTime.length === 16 ? `${this.newSlot.slotTime}:00` : this.newSlot.slotTime,
      location: this.newSlot.location,
      notes: this.newSlot.notes,
      facultyId: this.newSlot.facultyId || this.slotsForDrive.assignedFacultyId || null
    };
    this.apiService.post('/api/interview-slots', payload).subscribe({
      next: () => {
        this.loadSlots(this.slotsForDrive!.id);
        this.newSlot = { slotTime: '', location: this.slotsForDrive!.location || '', notes: '', facultyId: this.slotsForDrive!.assignedFacultyId || null };
      },
      error: err => this.errors.show(err, 'Could not add interview slot')
    });
  }


  async deleteSlot(slot: InterviewSlot) {
    if (!(await this.confirm.confirm('Delete this interview slot?'))) return;
    this.apiService.delete(`/api/interview-slots/${slot.id}`).subscribe({
      next: () => this.loadSlots(this.slotsForDrive!.id),
      error: err => this.errors.show(err, 'Could not delete interview slot')
    });
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

  async deleteDrive(drive: Drive) {
    if (!(await this.confirm.confirm(`Are you sure you want to delete "${drive.companyName}" drive?`))) return;
    this.apiService.delete(`/api/placement-drives/${drive.id}`).subscribe({
      next: () => {
        this.loadDrives();
      },
      error: (err) => {
        console.error('Failed to delete drive', err);
        this.errors.show(err, 'Could not delete placement drive');
      }
    });
  }
}
