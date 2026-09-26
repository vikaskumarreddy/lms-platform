import { Injectable, signal, inject } from '@angular/core';
import { Router } from '@angular/router';
import { AuthService } from './auth.service';

export interface QuotaModalData {
  title: string;
  reason: string;
  limitKey?: string;
  limit?: number;
  current?: number;
  isOrgAdmin: boolean;
  upgradeLabel?: string;
  upgradeRoute?: string;
}

/**
 * Manages the global modal popup shown when an organization hits a plan limit
 * (e.g. students, faculty seats, storage space).
 *
 * For Organization Administrators, it shows the reason and an "Upgrade Plan" CTA.
 * For Faculty members, it informs them that the limit is reached and asks them
 * to contact their organization administrator.
 */
@Injectable({ providedIn: 'root' })
export class QuotaModalService {
  private auth = inject(AuthService);
  private router = inject(Router);

  readonly pending = signal<QuotaModalData | null>(null);

  open(data: QuotaModalData) {
    this.pending.set(data);
  }

  close() {
    this.pending.set(null);
  }

  upgrade() {
    const data = this.pending();
    this.close();
    if (data?.upgradeRoute) {
      this.router.navigate([data.upgradeRoute]);
    } else {
      this.router.navigate(['/account']);
    }
  }

  /**
   * Evaluates an error from an HTTP request or service call.
   * If it represents a quota/plan limit breach, it opens the modal and returns true.
   */
  handleError(err: unknown, fallbackTitle?: string): boolean {
    const isOrgAdmin = !this.auth.isInstructor && (this.auth.isAdmin || this.auth.isInstituteAdmin);

    let status = 0;
    let code = '';
    let message = '';
    let details: Record<string, any> = {};

    if (err && typeof err === 'object') {
      const e = err as any;
      status = e.status || e.error?.status || 0;
      code = e.code || e.error?.code || '';
      message = e.error?.message || e.message || e.error?.error || '';
      details = e.error?.details || e.details || {};
    }

    const isQuota = code.startsWith('QUOTA_') ||
                    code === 'OVERAGE_CAP_REACHED' ||
                    message.toLowerCase().includes('quota') ||
                    message.toLowerCase().includes('limit') ||
                    message.toLowerCase().includes('exceed');

    if (!isQuota && status !== 409 && status !== 402) {
      return false;
    }

    let title = fallbackTitle || 'Plan Limit Reached';
    if (code === 'QUOTA_STORAGE_EXCEEDED' || message.toLowerCase().includes('storage')) {
      title = 'Storage Limit Reached';
    } else if (code === 'QUOTA_ACTIVE_STUDENTS_EXCEEDED' || message.toLowerCase().includes('student')) {
      title = 'Student Limit Reached';
    } else if (code === 'QUOTA_FACULTY_ACCOUNTS_EXCEEDED' || message.toLowerCase().includes('faculty')) {
      title = 'Faculty Seat Limit Reached';
    }

    let reason = message;
    if (!reason || reason === 'Something went wrong.') {
      reason = `Your organization's resource allowance has been reached on the current plan.`;
    }

    this.open({
      title,
      reason,
      limitKey: details['limitKey'] || code,
      limit: details['limit'],
      current: details['current'],
      isOrgAdmin,
      upgradeLabel: isOrgAdmin ? (details['upgradeToPlanName'] ? `Upgrade to ${details['upgradeToPlanName']}` : 'Upgrade Plan') : undefined,
      upgradeRoute: isOrgAdmin ? '/account' : undefined
    });

    return true;
  }
}
