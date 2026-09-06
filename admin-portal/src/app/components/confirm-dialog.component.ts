import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ConfirmService, PendingConfirm } from '../services/confirm.service';

/**
 * Renders the app's confirmation modal (replaces the native `confirm()`).
 * It is hosted once in the admin layout and reads the current prompt from
 * ConfirmService.pending, so any component can open it by calling
 * `confirmService.confirm(...)` without wiring up its own template.
 */
@Component({
  selector: 'app-confirm-dialog',
  standalone: true,
  imports: [CommonModule],
  template: `
    @if (prompt(); as p) {
      <div class="confirm-overlay" (click)="confirm.cancel()">
        <div class="confirm-modal" role="alertdialog" aria-modal="true" (click)="$event.stopPropagation()">
          <div class="confirm-icon" [class.confirm-icon-danger]="p.kind === 'danger'">
            {{ p.kind === 'danger' ? '!' : '?' }}
          </div>
          <div class="confirm-body">
            <div class="confirm-title">{{ p.title || 'Are you sure?' }}</div>
            <div class="confirm-message">{{ p.message }}</div>
          </div>
          <div class="confirm-actions">
            <button type="button" class="btn" (click)="confirm.cancel()">
              {{ p.cancelLabel || 'Cancel' }}
            </button>
            <button
              type="button"
              class="btn"
              [class.btn-danger]="p.kind === 'danger'"
              [class.btn-primary]="p.kind !== 'danger'"
              (click)="confirm.ok()"
            >
              {{ p.confirmLabel || 'Confirm' }}
            </button>
          </div>
        </div>
      </div>
    }
  `,
  styles: [
    `
      .confirm-overlay {
        position: fixed;
        inset: 0;
        background: rgba(15, 23, 42, 0.5);
        backdrop-filter: blur(2px);
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 3000;
        padding: 20px;
      }
      .confirm-modal {
        background: var(--surface, #ffffff);
        border-radius: 16px;
        box-shadow: 0 20px 60px rgba(15, 23, 42, 0.35);
        padding: 24px;
        max-width: 420px;
        width: 100%;
        animation: confirm-in 0.16s ease-out;
      }
      @keyframes confirm-in {
        from { opacity: 0; transform: scale(0.96) translateY(8px); }
        to   { opacity: 1; transform: scale(1) translateY(0); }
      }
      .confirm-icon {
        width: 44px;
        height: 44px;
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 22px;
        font-weight: 700;
        background: #E0EAFF;
        color: #1D4ED8;
        margin-bottom: 14px;
      }
      .confirm-icon-danger { background: #FEE2E2; color: #B91C1C; }
      .confirm-title {
        font-size: 17px;
        font-weight: 700;
        color: var(--text, #0F172A);
        margin-bottom: 8px;
      }
      .confirm-message {
        font-size: 14px;
        color: var(--text-secondary, #475569);
        line-height: 1.55;
      }
      .confirm-actions {
        display: flex;
        justify-content: flex-end;
        gap: 10px;
        margin-top: 22px;
      }
      .btn {
        padding: 9px 18px;
        border-radius: 8px;
        border: 1px solid var(--border, #E2E8F0);
        background: var(--surface, #fff);
        color: var(--text, #0F172A);
        font-weight: 600;
        font-size: 14px;
        cursor: pointer;
      }
      .btn:hover { background: var(--surface-hover, #F8FAFC); }
      .btn-primary { background: var(--primary, #0F172A); color: #fff; border-color: var(--primary, #0F172A); }
      .btn-primary:hover { opacity: 0.9; }
      .btn-danger { background: #DC2626; color: #fff; border-color: #DC2626; }
      .btn-danger:hover { background: #B91C1C; }
    `,
  ],
})
export class ConfirmDialogComponent {
  confirm = inject(ConfirmService);
  prompt = this.confirm.pending;
}