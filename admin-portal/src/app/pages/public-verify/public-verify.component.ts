import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, RouterModule } from '@angular/router';
import { HttpClient } from '@angular/common/http';

interface VerifiedCertificate {
  id: number;
  userId?: number;
  studentName: string;
  studentEmail?: string;
  instituteName: string;
  courseName: string;
  duration?: string;
  credentialId: string;
  issueDate: string;
  status: string;
  verifiedAt?: string;
}

@Component({
  selector: 'app-public-verify',
  standalone: true,
  imports: [CommonModule, RouterModule],
  template: `
    <div class="verify-container">
      <!-- Top Brand Bar -->
      <div class="verify-header">
        <div class="brand">
          <span class="brand-icon">🎓</span>
          <span class="brand-name">Digital Academy LMS</span>
        </div>
        <div class="auth-tag">Official Credential Verification</div>
      </div>

      <!-- Main Body -->
      <div class="verify-body">
        <!-- Loading State -->
        <div *ngIf="loading" class="state-box">
          <div class="spinner"></div>
          <p style="margin-top:16px;color:#64748B;font-size:15px;">Verifying credential with issuing registry...</p>
        </div>

        <!-- Error State -->
        <div *ngIf="!loading && error" class="state-box">
          <div class="status-circle error">✕</div>
          <h2 style="font-size:22px;color:#991B1B;margin:16px 0 8px 0;font-weight:700;">Certificate Not Found</h2>
          <p style="color:#64748B;max-width:440px;line-height:1.5;margin-bottom:20px;">
            The credential ID <strong>{{ credentialId }}</strong> could not be verified in the institutional registry. It may be invalid, expired, or revoked.
          </p>
          <a routerLink="/login" class="btn btn-secondary">Go to Academy Portal</a>
        </div>

        <!-- Verified Success State -->
        <div *ngIf="!loading && cert" class="cert-card">
          <!-- Verified Banner -->
          <div class="verified-banner">
            <div class="check-icon">✓</div>
            <div>
              <div class="banner-title">Authentic Certificate Verified</div>
              <div class="banner-subtitle">
                Issued by <strong>{{ cert.instituteName || 'Digital Academy' }}</strong> • Registry Record Confirmed
              </div>
            </div>
            <div class="pill-verified">VERIFIED</div>
          </div>

          <!-- Certificate Details -->
          <div class="cert-content">
            <div class="cert-pretitle">This is to certify that</div>
            <div class="student-name">{{ cert.studentName || 'Student' }}</div>
            <div class="cert-desc">has successfully completed the curriculum requirements for the course</div>
            <div class="course-name">{{ cert.courseName }}</div>

            <div class="meta-grid">
              <div class="meta-item">
                <div class="meta-label">Credential ID</div>
                <div class="meta-value monospace">{{ cert.credentialId }}</div>
              </div>
              <div class="meta-item">
                <div class="meta-label">Issue Date</div>
                <div class="meta-value">{{ cert.issueDate | date:'longDate' }}</div>
              </div>
              <div class="meta-item" *ngIf="cert.duration">
                <div class="meta-label">Program Duration</div>
                <div class="meta-value">{{ cert.duration }}</div>
              </div>
              <div class="meta-item">
                <div class="meta-label">Issuing Authority</div>
                <div class="meta-value">{{ cert.instituteName || 'Academy Partner' }}</div>
              </div>
            </div>

            <!-- Actions -->
            <div class="action-bar">
              <button class="btn btn-linkedin" (click)="shareToLinkedIn()">
                <svg style="width:16px;height:16px;margin-right:8px;fill:currentColor;" viewBox="0 0 24 24">
                  <path d="M19 3a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h14m-.5 15.5v-5.3a3.26 3.26 0 0 0-3.26-3.26c-.85 0-1.84.52-2.28 1.3v-1.11h-2.79v8.37h2.79v-4.93c0-.77.62-1.4 1.39-1.4a1.4 1.4 0 0 1 1.4 1.4v4.93h2.75M6.46 10.9v8.37H9.2V10.9H6.46M7.83 6.2a1.64 1.64 0 0 0-1.66 1.64c0 .91.74 1.65 1.66 1.65a1.64 1.64 0 0 0 1.65-1.65c0-.9-.74-1.64-1.65-1.64Z"/>
                </svg>
                Add to LinkedIn Profile
              </button>
              <button class="btn btn-secondary" (click)="printCertificate()">
                🖨️ Print / Save
              </button>
            </div>
          </div>

          <!-- Footer Seal -->
          <div class="cert-footer">
            <div class="security-note">
              🔒 Tamper-evident verification token validated against institute ledger at {{ cert.verifiedAt | date:'medium' }}.
            </div>
          </div>
        </div>
      </div>
    </div>
  `,
  styles: [`
    .verify-container {
      min-height: 100vh;
      background: #F8FAFC;
      display: flex;
      flex-direction: column;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    }
    .verify-header {
      background: #0C2B64;
      color: white;
      padding: 16px 24px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .brand-icon { font-size: 24px; }
    .brand-name { font-weight: 700; font-size: 17px; letter-spacing: 0.3px; }
    .auth-tag {
      font-size: 12px;
      background: rgba(255,255,255,0.15);
      padding: 4px 10px;
      border-radius: 12px;
      letter-spacing: 0.5px;
      color: #93C5FD;
    }
    .verify-body {
      flex: 1;
      display: flex;
      justify-content: center;
      align-items: center;
      padding: 32px 16px;
    }
    .state-box {
      background: white;
      border-radius: 16px;
      padding: 40px;
      text-align: center;
      box-shadow: 0 4px 20px rgba(0,0,0,0.05);
      border: 1px solid #E2E8F0;
      display: flex;
      flex-direction: column;
      align-items: center;
    }
    .status-circle {
      width: 56px; height: 56px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 24px;
      font-weight: bold;
    }
    .status-circle.error {
      background: #FEE2E2;
      color: #DC2626;
    }
    .spinner {
      width: 40px; height: 40px;
      border: 3px solid #E2E8F0;
      border-top-color: #2563EB;
      border-radius: 50%;
      animation: spin 0.8s linear infinite;
    }
    @keyframes spin { to { transform: rotate(360deg); } }

    .cert-card {
      background: white;
      border-radius: 20px;
      box-shadow: 0 10px 30px rgba(12, 43, 100, 0.08);
      border: 1px solid #E2E8F0;
      max-width: 680px;
      width: 100%;
      overflow: hidden;
    }
    .verified-banner {
      background: #ECFDF5;
      border-bottom: 1px solid #A7F3D0;
      padding: 16px 24px;
      display: flex;
      align-items: center;
      gap: 14px;
    }
    .check-icon {
      width: 36px; height: 36px;
      background: #10B981;
      color: white;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: bold;
      font-size: 18px;
      flex-shrink: 0;
    }
    .banner-title {
      font-weight: 700;
      color: #065F46;
      font-size: 15px;
    }
    .banner-subtitle {
      font-size: 12px;
      color: #047857;
      margin-top: 2px;
    }
    .pill-verified {
      margin-left: auto;
      background: #10B981;
      color: white;
      font-size: 11px;
      font-weight: 800;
      letter-spacing: 1px;
      padding: 4px 10px;
      border-radius: 20px;
    }
    .cert-content {
      padding: 32px 28px 24px 28px;
      text-align: center;
    }
    .cert-pretitle {
      font-size: 13px;
      color: #64748B;
      text-transform: uppercase;
      letter-spacing: 1.5px;
      font-weight: 600;
      margin-bottom: 8px;
    }
    .student-name {
      font-size: 26px;
      font-weight: 800;
      color: #0F172A;
      margin-bottom: 6px;
    }
    .cert-desc {
      font-size: 14px;
      color: #64748B;
      margin-bottom: 10px;
    }
    .course-name {
      font-size: 20px;
      font-weight: 700;
      color: #1E40AF;
      margin-bottom: 28px;
    }
    .meta-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 16px;
      background: #F8FAFC;
      border: 1px solid #E2E8F0;
      border-radius: 12px;
      padding: 16px 20px;
      text-align: left;
      margin-bottom: 24px;
    }
    .meta-label {
      font-size: 11px;
      font-weight: 600;
      color: #64748B;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      margin-bottom: 4px;
    }
    .meta-value {
      font-size: 14px;
      font-weight: 700;
      color: #1E293B;
    }
    .monospace {
      font-family: monospace;
      color: #0369A1;
      font-size: 13px;
    }
    .action-bar {
      display: flex;
      justify-content: center;
      gap: 12px;
      flex-wrap: wrap;
    }
    .btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      padding: 10px 20px;
      border-radius: 10px;
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      border: none;
      transition: all 0.2s;
    }
    .btn-linkedin {
      background: #0A66C2;
      color: white;
    }
    .btn-linkedin:hover {
      background: #084E96;
    }
    .btn-secondary {
      background: #F1F5F9;
      color: #334155;
      border: 1px solid #CBD5E1;
    }
    .btn-secondary:hover {
      background: #E2E8F0;
    }
    .cert-footer {
      background: #F8FAFC;
      border-top: 1px solid #E2E8F0;
      padding: 12px 24px;
      text-align: center;
    }
    .security-note {
      font-size: 11px;
      color: #94A3B8;
    }
    @media (max-width: 600px) {
      .meta-grid { grid-template-columns: 1fr; }
      .student-name { font-size: 22px; }
      .course-name { font-size: 18px; }
    }
    @media print {
      .verify-header, .action-bar, .auth-tag { display: none !important; }
      .cert-card { box-shadow: none; border: 2px solid #0F172A; }
    }
  `]
})
export class PublicVerifyComponent implements OnInit {
  private route = inject(ActivatedRoute);
  private http = inject(HttpClient);

  credentialId = '';
  cert: VerifiedCertificate | null = null;
  loading = true;
  error = false;

  ngOnInit() {
    this.credentialId = this.route.snapshot.paramMap.get('credentialId') || '';
    if (!this.credentialId) {
      this.loading = false;
      this.error = true;
      return;
    }

    this.http.get<VerifiedCertificate>(`/api/certificates/verify/${this.credentialId}`).subscribe({
      next: (data) => {
        this.cert = data;
        this.loading = false;
      },
      error: (err) => {
        console.error('Certificate verification failed', err);
        this.loading = false;
        this.error = true;
      }
    });
  }

  shareToLinkedIn() {
    if (!this.cert) return;
    const certUrl = window.location.href;
    const url = `https://www.linkedin.com/profile/add?startTask=CERTIFICATION_NAME&name=${encodeURIComponent(this.cert.courseName)}&organizationName=${encodeURIComponent(this.cert.instituteName || 'Digital Academy')}&certUrl=${encodeURIComponent(certUrl)}&certId=${encodeURIComponent(this.cert.credentialId)}`;
    window.open(url, '_blank');
  }

  printCertificate() {
    window.print();
  }
}
