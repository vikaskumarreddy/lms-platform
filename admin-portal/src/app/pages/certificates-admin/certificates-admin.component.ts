import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';

interface Student {
  id: number;
  name: string;
  email: string;
}

interface Certificate {
  id: number;
  userId: number;
  studentName: string;
  studentEmail: string;
  instituteName: string;
  courseName: string;
  duration: string;
  credentialId: string;
  issueDate: string;
}

@Component({
  selector: 'app-certificates-admin',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
      <h1 style="font-size:24px;font-weight:700;">🎓 Certificates</h1>
      <button class="btn btn-primary" (click)="openIssueModal()">+ Issue Certificate</button>
    </div>

    <!-- Issue Certificate Modal: single fieldset (only four fields, no tabs needed) -->
    <div class="modal-overlay" *ngIf="showForm" (click)="closeModal($event)">
      <div class="modal-content" style="width:90%;max-width:560px;" (click)="$event.stopPropagation()">
        <div style="display:none;justify-content:flex-end;margin-bottom:0;">
          <button class="btn btn-secondary btn-sm" (click)="closeModal()">✕</button>
        </div>

        <form (ngSubmit)="issue()">
          <fieldset>
            <legend>Issue New Certificate</legend>
            <div class="popup-form-grid">
              <div class="full-width">
                <label>Student *</label>
                <select [(ngModel)]="formData.userId" name="userId" required>
                  <option [ngValue]="null">Select Student</option>
                  <option *ngFor="let s of students" [ngValue]="s.id">{{ s.name }} ({{ s.email }})</option>
                </select>
              </div>
              <div>
                <label>Institute Name *</label>
                <input type="text" [(ngModel)]="formData.instituteName" name="instituteName" required placeholder="Enter institute name">
              </div>
              <div>
                <label>Course Name *</label>
                <input type="text" [(ngModel)]="formData.courseName" name="courseName" required placeholder="e.g. Java Full Stack">
              </div>
              <div>
                <label>Duration</label>
                <input type="text" [(ngModel)]="formData.duration" name="duration" placeholder="e.g. 6 Months">
              </div>
            </div>
          </fieldset>

          <div class="popup-nav">
            <button type="submit" class="btn btn-accent" [disabled]="saving">{{ saving ? 'Issuing...' : 'Issue Certificate' }}</button>
            <span style="flex:1"></span>
            <button type="button" class="btn btn-danger" (click)="closeModal()">Cancel</button>
          </div>
        </form>

        <div *ngIf="errorMsg" style="margin-top:16px;padding:12px;background:#FEE2E2;color:#991B1B;border-radius:8px;font-size:14px;">
          {{ errorMsg }}
        </div>
      </div>
    </div>

    <div class="card">
      <table>
        <thead>
          <tr><th>Student</th><th>Institute</th><th>Course</th><th>Duration</th><th>Credential ID</th><th>Issue Date</th><th>Actions</th></tr>
        </thead>
        <tbody>
          <tr *ngFor="let c of certificates">
            <td style="font-weight:600;">{{ c.studentName || c.studentEmail || 'Unknown' }}</td>
            <td>{{ c.instituteName }}</td>
            <td>{{ c.courseName }}</td>
            <td>{{ c.duration || '—' }}</td>
            <td style="font-size:12px;">{{ c.credentialId }}</td>
            <td style="font-size:13px;">{{ c.issueDate }}</td>
            <td>
              <button class="btn btn-danger" style="padding:4px 12px;font-size:12px;" (click)="deleteCertificate(c)">Revoke</button>
            </td>
          </tr>
          <tr *ngIf="certificates.length === 0">
            <td colspan="7" style="text-align:center;color:#64748B;padding:32px;">No certificates issued yet.</td>
          </tr>
        </tbody>
      </table>
    </div>
  `
})
export class CertificatesAdminComponent implements OnInit {
  students: Student[] = [];
  certificates: Certificate[] = [];
  showForm = false;
  saving = false;
  errorMsg = '';

  formData: any = { userId: null, instituteName: 'Axisora Forge Academy', courseName: '', duration: '' };

  constructor(private apiService: ApiService) {}

  ngOnInit() {
    this.loadStudents();
    this.loadCertificates();
  }

  loadStudents() {
    this.apiService.get<Student[]>('/api/students').subscribe({
      next: (data) => { this.students = data; },
      error: () => { this.students = []; }
    });
  }

  loadCertificates() {
    this.apiService.get<Certificate[]>('/api/certificates').subscribe({
      next: (data) => { this.certificates = data; },
      error: () => { this.certificates = []; }
    });
  }

  openIssueModal() {
    this.resetFormData();
    this.errorMsg = '';
    this.showForm = true;
  }

  closeModal(event?: Event) {
    if (event && event.target !== event.currentTarget) return;
    this.resetForm();
  }

  issue() {
    this.errorMsg = '';
    if (!this.formData.userId) { this.errorMsg = 'Please select a student'; return; }
    if (!this.formData.instituteName || !this.formData.courseName) { this.errorMsg = 'Institute name and course name are required'; return; }

    this.saving = true;
    this.apiService.post('/api/certificates', this.formData).subscribe({
      next: () => {
        this.saving = false;
        this.loadCertificates();
        this.resetForm();
      },
      error: (err) => {
        this.saving = false;
        this.errorMsg = err.error?.message || 'Failed to issue certificate';
      }
    });
  }

  deleteCertificate(c: Certificate) {
    if (!confirm(`Revoke certificate for "${c.studentName}"?`)) return;
    this.apiService.delete(`/api/certificates/${c.id}`).subscribe({
      next: () => { this.certificates = this.certificates.filter(x => x.id !== c.id); },
      error: () => { alert('Failed to revoke certificate'); }
    });
  }

  private resetFormData() {
    this.formData = { userId: null, instituteName: 'Axisora Forge Academy', courseName: '', duration: '' };
  }

  resetForm() {
    this.resetFormData();
    this.showForm = false;
    this.saving = false;
    this.errorMsg = '';
  }
}
