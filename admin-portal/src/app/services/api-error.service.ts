import { Injectable, signal } from '@angular/core';
import { HttpErrorResponse } from '@angular/common/http';

/**
 * The error envelope the backend returns for every failure
 * (see GlobalExceptionHandler / ErrorResponse).
 */
export interface ApiError {
  /** Machine-readable code, e.g. QUOTA_ACTIVE_STUDENTS_EXCEEDED. */
  code: string;
  status: number;
  message: string;
  details: Record<string, any>;
  /** True for quota breaches, which carry an upgrade path in details. */
  isQuota: boolean;
  /** True when the plan lacks a feature. */
  isEntitlement: boolean;
  /** True when the subscription has expired, been suspended or cancelled. */
  isSubscriptionState: boolean;
  /** A concrete next step the UI can offer, when one exists. */
  resolution?: ApiErrorResolution;
}

export interface ApiErrorResolution {
  kind: 'UPGRADE' | 'ADDON' | 'RENEW' | 'CONTACT';
  label: string;
  planCode?: string;
  planName?: string;
  addonCode?: string;
  addonName?: string;
}

export interface Toast {
  id: number;
  severity: 'success' | 'info' | 'warning' | 'error';
  title: string;
  message: string;
  resolution?: ApiErrorResolution;
  code?: string;
}

/**
 * Turns backend errors into something a person can act on.
 *
 * <p>This replaces the previous pattern of `console.error` plus a bare `alert()`,
 * which told an administrator that something had failed but never what limit they
 * had hit or what to do about it. Quota and entitlement errors carry an upgrade
 * path in `details`, and this service surfaces it as a button.
 */
@Injectable({ providedIn: 'root' })
export class ApiErrorService {
  /** Active toasts, rendered by ToastHostComponent in the layout. */
  readonly toasts = signal<Toast[]>([]);

  private nextId = 1;

  /** Parses an HttpErrorResponse into the typed envelope, tolerating older shapes. */
  parse(err: unknown): ApiError {
    const httpErr = err as HttpErrorResponse;
    const body = httpErr?.error ?? {};

    // `error` is the legacy alias of `message`; older endpoints only send that one.
    const message: string =
      body.message || body.error || httpErr?.message || 'Something went wrong.';
    const code: string = body.code || this.codeFromStatus(httpErr?.status);
    const status: number = body.status || httpErr?.status || 0;
    const details: Record<string, any> = body.details || {};

    const isQuota = code.startsWith('QUOTA_') || code === 'OVERAGE_CAP_REACHED';
    const isEntitlement = code === 'ENTITLEMENT_REQUIRED';
    const isSubscriptionState = code.startsWith('SUBSCRIPTION_');

    return {
      code,
      status,
      message,
      details,
      isQuota,
      isEntitlement,
      isSubscriptionState,
      resolution: this.resolutionFrom(code, details, isQuota, isEntitlement, isSubscriptionState)
    };
  }

  /**
   * Derives the call to action from the error details.
   *
   * Prefers upgrading over buying an add-on: where both are offered, moving up a
   * tier is priced to be the cheaper route, so leading with the add-on would push
   * customers toward the worse deal.
   */
  private resolutionFrom(
    code: string,
    details: Record<string, any>,
    isQuota: boolean,
    isEntitlement: boolean,
    isSubscriptionState: boolean
  ): ApiErrorResolution | undefined {
    if (isSubscriptionState) {
      return { kind: 'RENEW', label: 'View account' };
    }
    if (details['requiresQuote']) {
      return { kind: 'CONTACT', label: 'Contact sales' };
    }
    if ((isQuota || isEntitlement) && details['upgradeToPlanCode']) {
      return {
        kind: 'UPGRADE',
        label: `Upgrade to ${details['upgradeToPlanName'] || details['upgradeToPlanCode']}`,
        planCode: details['upgradeToPlanCode'],
        planName: details['upgradeToPlanName']
      };
    }
    if (isEntitlement && details['requiredPlanCode']) {
      return {
        kind: 'UPGRADE',
        label: `Upgrade to ${details['requiredPlanName'] || details['requiredPlanCode']}`,
        planCode: details['requiredPlanCode'],
        planName: details['requiredPlanName']
      };
    }
    if ((isQuota || isEntitlement) && details['addonCode']) {
      return {
        kind: 'ADDON',
        label: `Add ${details['addonName'] || details['addonCode']}`,
        addonCode: details['addonCode'],
        addonName: details['addonName']
      };
    }
    return undefined;
  }

  private codeFromStatus(status?: number): string {
    switch (status) {
      case 401: return 'UNAUTHORIZED';
      case 403: return 'FORBIDDEN';
      case 404: return 'RESOURCE_NOT_FOUND';
      case 409: return 'DUPLICATE_RESOURCE';
      case 0: return 'NETWORK_ERROR';
      default: return 'BAD_REQUEST';
    }
  }

  /** Parses and shows an error, returning it so callers can branch on the code. */
  show(err: unknown, fallbackTitle = 'That did not work'): ApiError {
    const parsed = this.parse(err);
    this.push({
      id: this.nextId++,
      severity: parsed.isQuota || parsed.isEntitlement || parsed.isSubscriptionState ? 'warning' : 'error',
      title: this.titleFor(parsed, fallbackTitle),
      message: parsed.message,
      resolution: parsed.resolution,
      code: parsed.code
    });
    return parsed;
  }

  success(message: string, title = 'Done') {
    this.push({ id: this.nextId++, severity: 'success', title, message });
  }

  info(message: string, title = 'Note') {
    this.push({ id: this.nextId++, severity: 'info', title, message });
  }

  dismiss(id: number) {
    this.toasts.update(list => list.filter(t => t.id !== id));
  }

  private push(toast: Toast) {
    this.toasts.update(list => [...list, toast]);
    // Errors stay until dismissed — a limit message with an upgrade button should not
    // vanish while the administrator is still reading it.
    if (toast.severity === 'success' || toast.severity === 'info') {
      setTimeout(() => this.dismiss(toast.id), 4000);
    }
  }

  private titleFor(parsed: ApiError, fallback: string): string {
    if (parsed.isQuota) {
      const label = parsed.details['unitLabel'] || 'plan limit';
      return `You've reached your ${label} limit`;
    }
    if (parsed.isEntitlement) {
      return `${parsed.details['featureName'] || 'That feature'} isn't in your plan`;
    }
    if (parsed.isSubscriptionState) {
      return 'Subscription needs attention';
    }
    if (parsed.code === 'DUPLICATE_RESOURCE') {
      return 'That already exists';
    }
    if (parsed.code === 'FORBIDDEN') {
      return 'Not allowed';
    }
    if (parsed.code === 'NETWORK_ERROR') {
      return 'Cannot reach the server';
    }
    return fallback;
  }
}
