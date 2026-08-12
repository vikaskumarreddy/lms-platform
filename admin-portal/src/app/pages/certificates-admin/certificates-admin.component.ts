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
      <button class="btn btn-primary" (click)="showForm = !showForm">{{ showForm ? 'Cancel' : '+ Issue Certificate' }}</button>
    </div>

    <div class="card" *ngIf="showForm" style="margin-bottom:20px;">
      <h3 style="margin-bottom:16px;">Issue New Certificate</h3>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;">
        <select [(ngModel)]="formData.userId" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;background:white;">
          <option [ngValue]="null">Select Student</option>
          <option *ngFor="let s of students" [ngValue]="s.id">{{ s.name }} ({{ s.email }})</option>
        </select>
        <input [(ngModel)]="formData.instituteName" placeholder="Institute Name" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <input [(ngModel)]="formData.courseName" placeholder="Course Name" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <input [(ngModel)]="formData.duration" placeholder="Duration (e.g. 6 Months)" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
      </div>
      <div style="margin-top:16px;display:flex;gap:12px;">
        <button class="btn btn-primary" [disabled]="saving" (click)="issue()">{{ saving ? 'Issuing...' : 'Issue Certificate' }}</button>
        <button class="btn" style="background:#E2E8F0;" (click)="resetForm()">Reset</button>
      </div>
      <div *ngIf="errorMsg" style="margin-top:8px;color:#EF4444;">{{ errorMsg }}</div>
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

  resetForm() {
    this.formData = { userId: null, instituteName: 'Axisora Forge Academy', courseName: '', duration: '' };
    this.showForm = false;
    this.errorMsg = '';
  }
}
