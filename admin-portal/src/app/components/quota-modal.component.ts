import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { QuotaModalService } from '../services/quota-modal.service';

/**
 * Global popup modal displayed whenever a tenant hits their student, faculty,
 * or storage plan limits.
 *
 * Scoped by role:
 * - Org Admins are shown the reason and given a direct "Upgrade Plan" action.
 * - Faculty members are informed that the limit is reached and advised to
 *   contact their organization administrator.
 */
@Component({
  selector: 'app-quota-modal',
  standalone: true,
  imports: [CommonModule],
  template: `
    @if (prompt(); as p) {
      <div class="quota-overlay" (click)="modal.close()">
        <div class="quota-modal" role="alertdialog" aria-modal="true" (click)="$event.stopPropagation()">
          <div class="quota-header">
            <div class="quota-icon-wrap" [class.quota-icon-storage]="p.title.includes('Storage')">
              <span class="quota-icon">
                @if (p.title.includes('Storage')) { 💾 }
                @else if (p.title.includes('Faculty')) { 👨‍🏫 }
                @else if (p.title.includes('Student')) { 🎓 }
                @else { ⚠️ }
              </span>
            </div>
            <div class="quota-title-wrap">
              <div class="quota-title">{{ p.title }}</div>
              <div class="quota-badge">Plan Limit Exceeded</div>
            </div>
            <button type="button" class="quota-close-btn" (click)="modal.close()" aria-label="Close dialog">×</button>
          </div>

          <div class="quota-body">
            <div class="quota-reason-card">
              <div class="reason-label">Reason:</div>
              <div class="reason-text">{{ p.reason }}</div>
            </div>

            @if (p.isOrgAdmin) {
              <div class="role-notice org-admin-notice">
                <span class="notice-icon">⭐</span>
                <div>
                  <strong>Organization Admin Action Required:</strong>
                  <p>As an Organization Administrator, you can upgrade your subscription tier or add resource add-ons to increase your limit immediately.</p>
                </div>
              </div>
            } @else {
              <div class="role-notice faculty-notice">
                <span class="notice-icon">ℹ️</span>
                <div>
                  <strong>Contact Administrator:</strong>
                  <p>You are logged in with a <strong>Faculty</strong> account. Please contact your organization administrator to upgrade the subscription plan or request additional resources.</p>
                </div>
              </div>
            }
          </div>

          <div class="quota-actions">
            @if (p.isOrgAdmin) {
              <button type="button" class="btn btn-secondary" (click)="modal.close()">
                Cancel
              </button>
              <button type="button" class="btn btn-primary btn-upgrade" (click)="modal.upgrade()">
                🚀 {{ p.upgradeLabel || 'Upgrade Plan' }}
              </button>
            } @else {
              <button type="button" class="btn btn-primary" (click)="modal.close()">
                Got It
              </button>
            }
          </div>
        </div>
      </div>
    }
  `,
  styles: [`
    .quota-overlay {
      position: fixed;
      inset: 0;
      background: rgba(15, 23, 42, 0.65);
      backdrop-filter: blur(4px);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 3500;
      padding: 20px;
      animation: quota-fade 0.15s ease-out;
    }
    @keyframes quota-fade {
      from { opacity: 0; }
      to   { opacity: 1; }
    }
    .quota-modal {
      background: var(--surface, #ffffff);
      border: 1px solid var(--border-light, #E2E8F0);
      border-radius: 20px;
      box-shadow: 0 25px 60px -12px rgba(15, 23, 42, 0.4);
      padding: 26px 28px;
      max-width: 480px;
      width: 100%;
      animation: quota-pop 0.2s cubic-bezier(0.16, 1, 0.3, 1);
    }
    @keyframes quota-pop {
      from { opacity: 0; transform: scale(0.94) translateY(12px); }
      to   { opacity: 1; transform: scale(1) translateY(0); }
    }
    .quota-header {
      display: flex;
      align-items: center;
      gap: 14px;
      position: relative;
      margin-bottom: 20px;
    }
    .quota-icon-wrap {
      width: 48px;
      height: 48px;
      border-radius: 14px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 24px;
      background: #FEF3C7;
      border: 1px solid #FDE68A;
      flex-shrink: 0;
    }
    .quota-icon-wrap.quota-icon-storage {
      background: #E0E7FF;
      border-color: #C7D2FE;
    }
    .quota-title-wrap {
      flex: 1;
    }
    .quota-title {
      font-size: 19px;
      font-weight: 700;
      color: var(--text, #0F172A);
      line-height: 1.25;
    }
    .quota-badge {
      display: inline-block;
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: #B45309;
      background: #FEF3C7;
      padding: 2px 8px;
      border-radius: 6px;
      margin-top: 4px;
    }
    .quota-close-btn {
      position: absolute;
      top: 0;
      right: 0;
      width: 32px;
      height: 32px;
      border-radius: 50%;
      background: var(--surface-alt, #F1F5F9);
      border: none;
      font-size: 20px;
      line-height: 1;
      color: #64748B;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: background 0.15s;
    }
    .quota-close-btn:hover {
      background: #E2E8F0;
      color: #0F172A;
    }
    .quota-body {
      margin-bottom: 24px;
    }
    .quota-reason-card {
      background: #FFFBEB;
      border: 1px solid #FCD34D;
      border-radius: 12px;
      padding: 14px 16px;
      margin-bottom: 16px;
    }
    .reason-label {
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: #92400E;
      margin-bottom: 4px;
    }
    .reason-text {
      font-size: 14px;
      font-weight: 500;
      color: #78350F;
      line-height: 1.5;
    }
    .role-notice {
      display: flex;
      gap: 12px;
      padding: 14px 16px;
      border-radius: 12px;
      font-size: 13px;
      line-height: 1.5;
    }
    .role-notice strong {
      display: block;
      font-size: 13.5px;
      margin-bottom: 3px;
    }
    .role-notice p {
      margin: 0;
    }
    .org-admin-notice {
      background: #EEF2FF;
      border: 1px solid #C7D2FE;
      color: #3730A3;
    }
    .org-admin-notice strong {
      color: #312E81;
    }
    .faculty-notice {
      background: #F1F5F9;
      border: 1px solid #CBD5E1;
      color: #334155;
    }
    .faculty-notice strong {
      color: #0F172A;
    }
    .notice-icon {
      font-size: 20px;
      flex-shrink: 0;
      line-height: 1.3;
    }
    .quota-actions {
      display: flex;
      align-items: center;
      justify-content: flex-end;
      gap: 12px;
    }
    .btn {
      padding: 10px 20px;
      border-radius: 10px;
      font-weight: 600;
      font-size: 14px;
      cursor: pointer;
      transition: all 0.15s ease;
      border: none;
    }
    .btn-secondary {
      background: var(--surface-alt, #F1F5F9);
      border: 1px solid var(--border-light, #CBD5E1);
      color: var(--text, #334155);
    }
    .btn-secondary:hover {
      background: #E2E8F0;
    }
    .btn-primary {
      background: var(--primary, #4F46E5);
      color: #ffffff;
      box-shadow: 0 4px 12px rgba(79, 70, 229, 0.25);
    }
    .btn-primary:hover {
      opacity: 0.93;
      transform: translateY(-1px);
    }
    .btn-upgrade {
      background: linear-gradient(135deg, #4F46E5 0%, #7C3AED 100%);
      box-shadow: 0 4px 14px rgba(99, 102, 241, 0.35);
    }
    .btn-upgrade:hover {
      box-shadow: 0 6px 20px rgba(99, 102, 241, 0.45);
    }
  `]
})
export class QuotaModalComponent {
  modal = inject(QuotaModalService);
  prompt = this.modal.pending;
}
