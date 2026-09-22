import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';
import { ApiErrorService } from '../../services/api-error.service';
import { ConfirmService } from '../../services/confirm.service';

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

    <!-- Issue Certificate Modal -->
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
              <div class="full-width">
                <label>Institute Name *</label>
                <input type="text" [(ngModel)]="formData.instituteName" name="instituteName" required placeholder="Enter institute name">
              </div>
              <div>
                <label>Course *</label>
                <select (change)="onCourseSelect($event)" style="margin-bottom:6px;">
                  <option value="">-- Choose from courses --</option>
                  <option *ngFor="let crs of courses" [value]="crs.title">{{ crs.title }}</option>
                </select>
                <input type="text" [(ngModel)]="formData.courseName" name="courseName" required placeholder="Or enter custom course title">
              </div>
              <div>
                <label>Duration</label>
                <input type="text" [(ngModel)]="formData.duration" name="duration" placeholder="e.g. 6 Months / 120 Hours">
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

    <!-- Certificate Preview Modal -->
    <div class="modal-overlay" *ngIf="previewCert" (click)="previewCert = null">
      <div class="modal-content" style="width:90%;max-width:720px;padding:24px;" (click)="$event.stopPropagation()">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px;">
          <h2 style="font-size:18px;font-weight:700;">Certificate Preview</h2>
          <div style="display:flex;gap:8px;">
            <button class="btn btn-primary btn-sm" (click)="printCertificate()">🖨️ Print / Save PDF</button>
            <button class="btn btn-secondary btn-sm" (click)="previewCert = null">✕</button>
          </div>
        </div>

        <!-- Printable Certificate Card -->
        <div id="print-certificate-area" style="border:8px double #1E3A8A;padding:32px;text-align:center;background:#FFFDF7;border-radius:12px;box-shadow:0 4px 12px rgba(0,0,0,0.08);position:relative;">
          <div style="font-size:14px;letter-spacing:2px;text-transform:uppercase;color:#64748B;margin-bottom:8px;">Certificate of Completion</div>
          <h1 style="font-size:26px;color:#1E3A8A;font-weight:800;margin-bottom:16px;">{{ previewCert.instituteName }}</h1>
          <p style="font-size:14px;color:#475569;margin-bottom:12px;">This is proudly presented to</p>
          <h2 style="font-size:28px;font-family:serif;font-weight:700;color:#0F172A;border-bottom:2px solid #CBD5E1;display:inline-block;padding-bottom:4px;margin-bottom:16px;">
            {{ previewCert.studentName || previewCert.studentEmail }}
          </h2>
          <p style="font-size:14px;color:#475569;max-width:500px;margin:0 auto 20px auto;line-height:1.6;">
            for successfully completing the specialized professional curriculum in
            <strong style="color:#1E3A8A;">{{ previewCert.courseName }}</strong>
            <span *ngIf="previewCert.duration"> over a duration of {{ previewCert.duration }}</span>.
          </p>

          <div style="display:flex;justify-content:space-between;align-items:flex-end;margin-top:24px;padding-top:16px;border-top:1px solid #E2E8F0;">
            <div style="text-align:left;">
              <div style="font-size:11px;color:#64748B;">ISSUED ON</div>
              <div style="font-size:13px;font-weight:600;color:#1E293B;">{{ previewCert.issueDate }}</div>
              <div style="font-size:11px;color:#64748B;margin-top:4px;">CREDENTIAL ID</div>
              <div style="font-family:monospace;font-size:12px;font-weight:700;color:#2563EB;">{{ previewCert.credentialId }}</div>
            </div>
            <div>
              <img [src]="'https://api.qrserver.com/v1/create-qr-code/?size=90x90&data=' + getVerifyUrl(previewCert)" alt="QR" style="width:80px;height:80px;border-radius:4px;border:1px solid #CBD5E1;">
              <div style="font-size:10px;color:#64748B;margin-top:2px;">Scan to Verify</div>
            </div>
          </div>
        </div>

        <div style="margin-top:16px;display:flex;justify-content:space-between;align-items:center;">
          <span style="font-size:12px;color:#64748B;">Public URL: <a [href]="getVerifyUrl(previewCert)" target="_blank">{{ getVerifyUrl(previewCert) }}</a></span>
          <button class="btn btn-secondary btn-sm" (click)="copyVerifyLink(previewCert)">📋 Copy Link</button>
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
            <td style="font-size:12px;">
              <span style="font-family:monospace;color:#2563EB;font-weight:600;">{{ c.credentialId }}</span>
            </td>
            <td style="font-size:13px;">{{ c.issueDate }}</td>
            <td>
              <button class="btn btn-primary" style="padding:4px 10px;font-size:12px;margin-right:6px;" (click)="previewCertificate(c)">Preview</button>
              <button class="btn btn-secondary" style="padding:4px 10px;font-size:12px;margin-right:6px;" (click)="copyVerifyLink(c)" title="Copy public verification link">🔗 Link</button>
              <button class="btn btn-danger" style="padding:4px 10px;font-size:12px;" (click)="deleteCertificate(c)">Revoke</button>
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
  courses: any[] = [];
  previewCert: Certificate | null = null;
  showForm = false;
  saving = false;
  errorMsg = '';

  /** This org's name, used as the default institute name on the issue form. */
  orgName = '';

  formData: any = { userId: null, instituteName: '', courseName: '', duration: '' };

  private errors = inject(ApiErrorService);
  private confirm = inject(ConfirmService);

  constructor(private apiService: ApiService) {}

  ngOnInit() {
    this.loadOrgName();
    this.loadStudents();
    this.loadCertificates();
    this.loadCourses();
  }

  loadOrgName() {
    this.apiService.get<any>('/api/organizations/current').subscribe({
      next: (org) => {
        this.orgName = org?.name || '';
        if (!this.formData.instituteName) {
          this.formData.instituteName = this.orgName;
        }
      },
      error: () => { this.orgName = ''; }
    });
  }

  loadStudents() {
    this.apiService.get<Student[]>('/api/students').subscribe({
      next: (data) => { this.students = data; },
      error: () => { this.students = []; }
    });
  }

  loadCourses() {
    this.apiService.get<any[]>('/api/courses').subscribe({
      next: (data) => { this.courses = data || []; },
      error: () => { this.courses = []; }
    });
  }

  loadCertificates() {
    this.apiService.get<Certificate[]>('/api/certificates').subscribe({
      next: (data) => { this.certificates = data; },
      error: () => { this.certificates = []; }
    });
  }

  onCourseSelect(event: any) {
    const val = event.target.value;
    if (val) {
      this.formData.courseName = val;
    }
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

  previewCertificate(c: Certificate) {
    this.previewCert = c;
  }

  getVerifyUrl(c?: Certificate | null): string {
    if (!c || !c.credentialId) return '';
    return `${window.location.origin}/verify/${c.credentialId}`;
  }

  copyVerifyLink(c: Certificate) {
    const url = this.getVerifyUrl(c);
    if (navigator.clipboard) {
      navigator.clipboard.writeText(url).then(() => {
        this.errors.success('Verification link copied to clipboard!');
      }).catch(() => {
        prompt('Copy verification URL:', url);
      });
    } else {
      prompt('Copy verification URL:', url);
    }
  }

  printCertificate() {
    window.print();
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

  async deleteCertificate(c: Certificate) {
    if (!(await this.confirm.confirm(`Revoke certificate for "${c.studentName}"?`))) return;
    this.apiService.delete(`/api/certificates/${c.id}`).subscribe({
      next: () => { this.certificates = this.certificates.filter(x => x.id !== c.id); },
      error: (err) => { this.errors.show(err, 'Could not revoke that certificate'); }
    });
  }

  private resetFormData() {
    this.formData = { userId: null, instituteName: this.orgName || '', courseName: '', duration: '' };
  }

  resetForm() {
    this.resetFormData();
    this.showForm = false;
    this.saving = false;
    this.errorMsg = '';
  }
}
