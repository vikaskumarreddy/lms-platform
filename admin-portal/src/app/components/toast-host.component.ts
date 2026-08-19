import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { ApiErrorService, Toast } from '../services/api-error.service';

/**
 * Renders the app's toasts, including the action button that quota and entitlement
 * errors carry.
 *
 * <p>This is what replaces `alert()` throughout the portal. The difference that
 * matters is the action: when an administrator hits a plan limit they now get a
 * button that takes them to the plan comparison, rather than a modal telling them
 * "Bad Request" with nothing to do next.
 */
@Component({
  selector: 'app-toast-host',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="toast-host">
      @for (toast of toasts(); track toast.id) {
        <div class="toast" [class]="'toast-' + toast.severity">
          <div class="toast-icon">{{ iconFor(toast) }}</div>
          <div class="toast-body">
            <div class="toast-title">{{ toast.title }}</div>
            <div class="toast-message">{{ toast.message }}</div>

            @if (toast.resolution) {
              <button class="toast-action" (click)="act(toast)">
                {{ toast.resolution.label }}
              </button>
            }
          </div>
          <button class="toast-close" (click)="dismiss(toast.id)" aria-label="Dismiss">×</button>
        </div>
      }
    </div>
  `,
  styles: [`
    .toast-host {
      position: fixed;
      top: 20px;
      right: 20px;
      z-index: 2000;
      display: flex;
      flex-direction: column;
      gap: 12px;
      max-width: 420px;
    }
    .toast {
      display: flex;
      gap: 12px;
      background: var(--surface);
      border-radius: 12px;
      padding: 14px 16px;
      box-shadow: 0 8px 24px rgba(15, 23, 42, 0.16);
      border-left: 4px solid var(--border);
      animation: toast-in 0.18s ease-out;
    }
    @keyframes toast-in {
      from { opacity: 0; transform: translateX(16px); }
      to   { opacity: 1; transform: translateX(0); }
    }
    .toast-error   { border-left-color: #DC2626; }
    .toast-warning { border-left-color: #EAB308; }
    .toast-success { border-left-color: #16A34A; }
    .toast-info    { border-left-color: #2563EB; }

    .toast-icon { font-size: 18px; line-height: 1.4; }
    .toast-body { flex: 1; min-width: 0; }
    .toast-title {
      font-weight: 700;
      font-size: 14px;
      color: var(--text);
      margin-bottom: 4px;
    }
    .toast-message {
      font-size: 13px;
      color: var(--text-secondary);
      line-height: 1.5;
    }
    .toast-action {
      margin-top: 10px;
      padding: 7px 14px;
      border: none;
      border-radius: 6px;
      background: var(--primary);
      color: #fff;
      font-weight: 600;
      font-size: 13px;
      cursor: pointer;
    }
    .toast-action:hover { opacity: 0.9; }
    .toast-close {
      background: none;
      border: none;
      font-size: 20px;
      line-height: 1;
      color: var(--text-secondary);
      cursor: pointer;
      padding: 0 2px;
      align-self: flex-start;
    }
  `]
})
export class ToastHostComponent {
  private errors = inject(ApiErrorService);
  private router = inject(Router);

  toasts = this.errors.toasts;

  iconFor(toast: Toast): string {
    switch (toast.severity) {
      case 'success': return '✓';
      case 'warning': return '!';
      case 'info': return 'i';
      default: return '×';
    }
  }

  /**
   * Every action lands on the Account page: it is where plans are compared, add-ons
   * are requested and renewals happen, so it is the single place an administrator can
   * actually resolve any of these.
   */
  act(toast: Toast) {
    const resolution = toast.resolution;
    this.dismiss(toast.id);
    if (!resolution) {
      return;
    }
    const queryParams: Record<string, string> = {};
    if (resolution.planCode) queryParams['highlightPlan'] = resolution.planCode;
    if (resolution.addonCode) queryParams['highlightAddon'] = resolution.addonCode;
    if (resolution.kind === 'ADDON') queryParams['tab'] = 'addons';
    if (resolution.kind === 'UPGRADE' || resolution.kind === 'CONTACT') queryParams['tab'] = 'plans';

    this.router.navigate(['/account'], { queryParams });
  }

  dismiss(id: number) {
    this.errors.dismiss(id);
  }
}
