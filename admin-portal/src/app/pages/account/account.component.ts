import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute } from '@angular/router';
import { ApiService } from '../../services/api.service';
import { ApiErrorService } from '../../services/api-error.service';

export interface UsageMeter {
  limitKey: string;
  label: string;
  used: number;
  limit: number | null;
  unlimited: boolean;
  fromAddons: number;
  percentUsed: number | null;
  state: 'OK' | 'WARNING' | 'AT_LIMIT' | 'OVER';
  meteredNotBlocked: boolean;
  note?: string;
}

export interface EntitlementView {
  key: string;
  label: string;
  category: string;
  categoryLabel: string;
  included: boolean;
  value: any;
  salesQualified: boolean;
}

export interface PlanCard {
  plan: any;
  isCurrent: boolean;
  action: 'CURRENT' | 'UPGRADE' | 'DOWNGRADE' | 'CONTACT_SALES';
  actionLabel: string;
  recommended: boolean;
  blocked: boolean;
  blockedReason?: string;
}

export interface AccountOverview {
  organization: any;
  subscription: any;
  usage: UsageMeter[];
  entitlements: EntitlementView[];
  addons: any[];
  pendingPlanChange: any;
  notice: {
    severity: 'INFO' | 'WARNING' | 'CRITICAL';
    title: string;
    message: string;
    actionLabel: string;
    code: string;
  } | null;
}

type TabId = 'overview' | 'plans' | 'addons' | 'billing';

/**
 * The institute admin's Account page.
 *
 * <p>Answers three questions in one place: what did we buy, how much of it are we
 * using, and what happens next. The plan cards show the applied plan with a disabled
 * "Current Plan" button and every other plan with a real action.
 *
 * <p>Reachable even when the subscription has expired — the whole `/api/account` path
 * is whitelisted server-side, because locking a tenant out of the page that explains
 * the lockout and carries the fix would be self-defeating.
 */
@Component({
  selector: 'app-account',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './account.component.html',
  styleUrls: ['./account.component.css']
})
export class AccountComponent implements OnInit {
  private api = inject(ApiService);
  private errors = inject(ApiErrorService);
  private route = inject(ActivatedRoute);

  overview: AccountOverview | null = null;
  planCards: PlanCard[] = [];
  availableAddons: any[] = [];
  billingEvents: any[] = [];
  subscriptionHistory: any[] = [];

  loading = true;
  activeTab: TabId = 'overview';
  /** Set from a toast action so the relevant card can be visually highlighted. */
  highlightPlan: string | null = null;
  highlightAddon: string | null = null;

  /** Annual vs monthly toggle on the plan cards. */
  showAnnual = false;

  confirmingPlan: PlanCard | null = null;
  requestNote = '';
  submitting = false;

  requestingAddon: any = null;
  addonQty = 1;

  ngOnInit() {
    const params = this.route.snapshot.queryParamMap;
    const tab = params.get('tab') as TabId | null;
    if (tab && ['overview', 'plans', 'addons', 'billing'].includes(tab)) {
      this.activeTab = tab;
    }
    this.highlightPlan = params.get('highlightPlan');
    this.highlightAddon = params.get('highlightAddon');

    this.loadOverview();
    this.loadPlans();
  }

  loadOverview() {
    this.loading = true;
    this.api.get<AccountOverview>('/api/account/overview').subscribe({
      next: data => {
        this.overview = data;
        this.loading = false;
      },
      error: err => {
        this.loading = false;
        this.errors.show(err, 'Could not load your account');
      }
    });
  }

  loadPlans() {
    this.api.get<PlanCard[]>('/api/account/plans').subscribe({
      next: data => (this.planCards = data),
      error: err => this.errors.show(err, 'Could not load plans')
    });
  }

  selectTab(tab: TabId) {
    this.activeTab = tab;
    if (tab === 'addons' && this.availableAddons.length === 0) {
      this.loadAddons();
    }
    if (tab === 'billing' && this.billingEvents.length === 0) {
      this.loadBilling();
    }
  }

  loadAddons() {
    this.api.get<any>('/api/account/addons').subscribe({
      next: data => (this.availableAddons = data.available || []),
      error: err => this.errors.show(err, 'Could not load add-ons')
    });
  }

  loadBilling() {
    this.api.get<any[]>('/api/account/billing-events').subscribe({
      next: data => (this.billingEvents = data),
      error: err => this.errors.show(err, 'Could not load billing history')
    });
    this.api.get<any[]>('/api/account/subscription-history').subscribe({
      next: data => (this.subscriptionHistory = data),
      error: () => { /* the timeline above is enough on its own */ }
    });
  }

  // ---- Plan changes --------------------------------------------------

  /** Opens the confirmation step. Current and blocked plans are not actionable. */
  choosePlan(card: PlanCard) {
    if (card.isCurrent || card.blocked) {
      return;
    }
    this.confirmingPlan = card;
    this.requestNote = '';
  }

  cancelPlanChoice() {
    this.confirmingPlan = null;
    this.requestNote = '';
  }

  confirmPlanChange() {
    if (!this.confirmingPlan) {
      return;
    }
    this.submitting = true;
    const payload = {
      planCode: this.confirmingPlan.plan.code,
      billingCycle: this.showAnnual ? 'YEARLY' : 'MONTHLY',
      note: this.requestNote
    };
    this.api.post<any>('/api/account/plan-change-request', payload).subscribe({
      next: res => {
        this.submitting = false;
        this.confirmingPlan = null;
        this.errors.success(res.message || 'Request submitted.');
        this.loadOverview();
        this.loadPlans();
      },
      error: err => {
        this.submitting = false;
        this.errors.show(err, 'Could not submit that request');
      }
    });
  }

  withdrawPendingChange() {
    const pending = this.overview?.pendingPlanChange;
    if (!pending) {
      return;
    }
    this.api.delete<any>(`/api/account/plan-change-request/${pending.id}`).subscribe({
      next: () => {
        this.errors.success('Request withdrawn.');
        this.loadOverview();
      },
      error: err => this.errors.show(err, 'Could not withdraw that request')
    });
  }

  // ---- Add-ons -------------------------------------------------------

  chooseAddon(addon: any) {
    this.requestingAddon = addon;
    this.addonQty = addon.minQty || 1;
  }

  cancelAddonChoice() {
    this.requestingAddon = null;
  }

  confirmAddonRequest() {
    if (!this.requestingAddon) {
      return;
    }
    this.submitting = true;
    this.api.post<any>('/api/account/addon-request', {
      addonCode: this.requestingAddon.code,
      qty: this.addonQty
    }).subscribe({
      next: res => {
        this.submitting = false;
        this.requestingAddon = null;
        this.errors.success(res.message || 'Request submitted.');
        this.loadOverview();
      },
      error: err => {
        this.submitting = false;
        this.errors.show(err, 'Could not request that add-on');
      }
    });
  }

  // ---- Display helpers -----------------------------------------------

  /** Entitlement categories in display order, for the grouped feature list. */
  entitlementCategories(): { key: string; label: string; items: EntitlementView[] }[] {
    const groups = new Map<string, { key: string; label: string; items: EntitlementView[] }>();
    for (const e of this.overview?.entitlements ?? []) {
      if (!groups.has(e.category)) {
        groups.set(e.category, { key: e.category, label: e.categoryLabel, items: [] });
      }
      groups.get(e.category)!.items.push(e);
    }
    return Array.from(groups.values());
  }

  meterColour(meter: UsageMeter): string {
    switch (meter.state) {
      case 'OVER': return meter.meteredNotBlocked ? '#EAB308' : '#DC2626';
      case 'AT_LIMIT': return '#DC2626';
      case 'WARNING': return '#EAB308';
      default: return '#16A34A';
    }
  }

  meterWidth(meter: UsageMeter): string {
    if (meter.unlimited) {
      return '100%';
    }
    return `${meter.percentUsed ?? 0}%`;
  }

  noticeClass(): string {
    switch (this.overview?.notice?.severity) {
      case 'CRITICAL': return 'notice-critical';
      case 'WARNING': return 'notice-warning';
      default: return 'notice-info';
    }
  }

  /** Price to show on a card, honouring the annual/monthly toggle. */
  priceFor(plan: any): number | null {
    if (plan.isCustomPriced) {
      return null;
    }
    return this.showAnnual ? plan.priceYearly : plan.priceMonthly;
  }

  priceSuffix(): string {
    return this.showAnnual ? '/year' : '/month';
  }

  /** Annual saving in rupees, so the discount is concrete rather than a percentage. */
  annualSaving(plan: any): number | null {
    if (!plan.priceMonthly || !plan.priceYearly) {
      return null;
    }
    return plan.priceMonthly * 12 - plan.priceYearly;
  }

  /** Limits summarised for a card, with null rendered as "Unlimited". */
  limitLine(plan: any): string[] {
    const lines: string[] = [];
    lines.push(this.limitText(plan.maxActiveStudents, 'active students'));
    lines.push(this.limitText(plan.maxFacultyAccounts, 'faculty seats'));
    if (plan.maxBranches && plan.maxBranches > 1) {
      lines.push(this.limitText(plan.maxBranches, 'branches'));
    }
    lines.push(this.limitText(plan.storageGb, 'GB storage'));
    if (plan.includedTrainingHours > 0) {
      lines.push(`${plan.includedTrainingHours} training hours/month included`);
    }
    return lines;
  }

  private limitText(value: number | null, label: string): string {
    return value == null ? `Unlimited ${label}` : `${value.toLocaleString('en-IN')} ${label}`;
  }

  isHighlighted(card: PlanCard): boolean {
    return this.highlightPlan === card.plan.code;
  }
}
