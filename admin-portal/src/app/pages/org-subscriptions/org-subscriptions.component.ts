import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';
import { ApiErrorService } from '../../services/api-error.service';
import { ConfirmService } from '../../services/confirm.service';

/**
 * Platform plan catalog editor — Platform, Platform Plus, Managed Academy, Enterprise
 * and the assisted Pilot.
 *
 * <p>Editing a plan here changes what NEW business is sold on. It deliberately does not
 * touch existing customers: their subscription froze the limits, entitlements and price
 * at purchase, so a price rise reaches them only at renewal. The editor says so, because
 * the opposite assumption is the natural one to make.
 *
 * <p>Limits and entitlements come from the server's own enum vocabulary
 * (`/api/org-subscriptions/schema`), so the editor cannot offer a feature key that
 * enforcement does not understand.
 */
@Component({
  selector: 'app-org-subscriptions',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="page-header">
      <div>
        <h1>Platform Plans</h1>
        <p class="muted">
          What we sell to academies. Changes apply to new subscriptions and renewals —
          organizations already on a plan keep the terms they agreed until they renew.
        </p>
      </div>
      <button class="btn btn-primary" (click)="openCreate()">+ New plan</button>
    </div>

    <div class="card">
      <table>
        <thead>
          <tr>
            <th>Plan</th><th>Monthly</th><th>Annual</th><th>Per student</th>
            <th>Limits</th><th>In use</th><th>Status</th><th></th>
          </tr>
        </thead>
        <tbody>
          @for (plan of plans; track plan.id) {
            <tr>
              <td>
                <div class="name">
                  {{ plan.name }}
                  @if (plan.isPopular) { <span class="badge badge-warning">Recommended</span> }
                </div>
                <div class="muted small">{{ plan.code }}</div>
              </td>
              <td>{{ plan.priceMonthly != null ? ('₹' + (plan.priceMonthly | number:'1.0-0')) : 'Custom' }}</td>
              <td>
                @if (plan.priceYearly != null) {
                  ₹{{ plan.priceYearly | number:'1.0-0' }}
                  <div class="muted small"
                       [class.warn]="plan.annualDiscountOutOfBand">
                    {{ plan.annualDiscountPct }}% off
                    @if (plan.annualDiscountOutOfBand) { — outside the 15–20% band }
                  </div>
                } @else { <span class="muted">—</span> }
              </td>
              <td>
                @if (plan.effectivePricePerStudent != null) {
                  ₹{{ plan.effectivePricePerStudent | number:'1.0-2' }}
                  @if (plan.overageStudentPrice != null) {
                    <div class="muted small">overage ₹{{ plan.overageStudentPrice | number:'1.0-0' }}</div>
                  }
                } @else { <span class="muted">—</span> }
              </td>
              <td class="small">
                {{ plan.maxActiveStudents ?? '∞' }} students ·
                {{ plan.maxFacultyAccounts ?? '∞' }} faculty ·
                {{ plan.storageGb ?? '∞' }} GB
              </td>
              <td>{{ plan.organizationsUsing ?? 0 }}</td>
              <td>
                <span class="badge" [class.badge-success]="plan.isActive" [class.badge-secondary]="!plan.isActive">
                  {{ plan.isActive ? 'Active' : 'Retired' }}
                </span>
                @if (!plan.isPublic) { <span class="badge badge-secondary">Hidden</span> }
              </td>
              <td class="actions">
                <button class="btn btn-sm btn-secondary" (click)="openEdit(plan)">Edit</button>
                <button class="btn btn-sm btn-danger"
                        [disabled]="plan.organizationsUsing > 0"
                        [title]="plan.organizationsUsing > 0 ? 'In use by ' + plan.organizationsUsing + ' organization(s)' : ''"
                        (click)="remove(plan)">Delete</button>
              </td>
            </tr>
          }
        </tbody>
      </table>
    </div>

    @if (showModal) {
      <div class="modal-backdrop" (click)="close()">
        <div class="modal modal-wide" (click)="$event.stopPropagation()">
          <h2>{{ editingId ? ('Edit ' + form.name) : 'New plan' }}</h2>

          <div class="tabs">
            <button [class.active]="tab === 'basics'" (click)="tab = 'basics'">Basics</button>
            <button [class.active]="tab === 'pricing'" (click)="tab = 'pricing'">Pricing &amp; GST</button>
            <button [class.active]="tab === 'limits'" (click)="tab = 'limits'">Limits</button>
            <button [class.active]="tab === 'features'" (click)="tab = 'features'">Features</button>
          </div>

          <!-- ===== BASICS ===== -->
          @if (tab === 'basics') {
            <label>Name <input [(ngModel)]="form.name"></label>
            <label>Tagline <input [(ngModel)]="form.tagline" placeholder="Run your academy on our platform"></label>
            <label>Description <textarea [(ngModel)]="form.description" rows="2"></textarea></label>

            <div class="form-grid">
              <label>Tier rank
                <input type="number" [(ngModel)]="form.tierRank">
                <span class="hint">Higher = more senior. Decides upgrade vs downgrade.</span>
              </label>
              <label>Display order <input type="number" [(ngModel)]="form.displayOrder"></label>
            </div>

            <div class="checkboxes">
              <label class="inline"><input type="checkbox" [(ngModel)]="form.isActive"> Active</label>
              <label class="inline"><input type="checkbox" [(ngModel)]="form.isPublic"> Show on the Account page</label>
              <label class="inline"><input type="checkbox" [(ngModel)]="form.isPopular"> Recommended badge</label>
              <label class="inline"><input type="checkbox" [(ngModel)]="form.requiresQuote"> Needs a quote</label>
            </div>

            <label class="inline block">
              <input type="checkbox" [(ngModel)]="form.selfServeUpgradeEnabled">
              Allow tenants to switch to this plan themselves
              <span class="hint">
                Off by default. With no payment gateway, self-serve would grant the plan
                before any money is collected.
              </span>
            </label>

            <label>Delivery notes (internal)
              <textarea [(ngModel)]="form.fulfilmentNotes" rows="3"></textarea>
            </label>
          }

          <!-- ===== PRICING ===== -->
          @if (tab === 'pricing') {
            <label class="inline block">
              <input type="checkbox" [(ngModel)]="form.isCustomPriced"> Custom priced (quoted per organization)
            </label>

            @if (!form.isCustomPriced) {
              <div class="form-grid">
                <label>Monthly price (₹) <input type="number" [(ngModel)]="form.priceMonthly"></label>
                <label>Annual price (₹) <input type="number" [(ngModel)]="form.priceYearly"></label>
              </div>

              @if (discountPreview() !== null) {
                <div class="callout" [class.callout-warn]="discountOutOfBand()">
                  Annual discount: <strong>{{ discountPreview() }}%</strong>
                  ({{ savingPreview() | number:'1.0-0' }} off ₹{{ listPreview() | number:'1.0-0' }})
                  @if (discountOutOfBand()) {
                    — outside the intended 15–20% band.
                  }
                </div>
              }

              <div class="form-grid">
                <label>Overage students allowed
                  <input type="number" [(ngModel)]="form.overageStudentsAllowed">
                  <span class="hint">Extra seats buyable before an upgrade is required.</span>
                </label>
                <label>Overage price per student (₹)
                  <input type="number" [(ngModel)]="form.overageStudentPrice">
                  <span class="hint">
                    Must be at or above this plan's own per-student rate
                    @if (effectiveRate() !== null) { (₹{{ effectiveRate() | number:'1.0-2' }}) }
                    — pricing it lower makes stacking seats cheaper than upgrading.
                  </span>
                </label>
              </div>

              @if (overageUndercuts()) {
                <div class="callout callout-warn">
                  This overage price is below the plan's own per-student rate, so nobody on
                  it would ever have a reason to move up a tier.
                </div>
              }
            }

            <div class="form-grid">
              <label>SAC code <input [(ngModel)]="form.hsnSacCode" placeholder="997331"></label>
              <label>GST % <input type="number" [(ngModel)]="form.gstRatePct"></label>
            </div>
            <label class="inline block">
              <input type="checkbox" [(ngModel)]="form.taxInclusive"> Prices include GST
              <span class="hint">Off by default — prices are stored exclusive of tax.</span>
            </label>

            <div class="form-grid">
              <label>Trial days <input type="number" [(ngModel)]="form.trialDays"></label>
              <label>Grace days
                <input type="number" [(ngModel)]="form.graceDays">
                <span class="hint">Full access after expiry before the portal goes read-only.</span>
              </label>
            </div>
          }

          <!-- ===== LIMITS ===== -->
          @if (tab === 'limits') {
            <p class="hint block">Leave a field empty for unlimited.</p>
            <div class="form-grid">
              <label>Active students <input type="number" [(ngModel)]="form.maxActiveStudents"></label>
              <label>Faculty seats <input type="number" [(ngModel)]="form.maxFacultyAccounts"></label>
              <label>Branches <input type="number" [(ngModel)]="form.maxBranches"></label>
              <label>Organizations <input type="number" [(ngModel)]="form.maxOrganizations"></label>
              <label>Storage (GB) <input type="number" [(ngModel)]="form.storageGb"></label>
              <label>Included training hours / month
                <input type="number" [(ngModel)]="form.includedTrainingHours">
                <span class="hint">
                  Hours the base fee already covers. Purchased hours only start billing beyond this.
                </span>
              </label>
            </div>
            <label class="inline block">
              <input type="checkbox" [(ngModel)]="form.limitsConfigurable">
              Limits can be negotiated per organization
            </label>
          }

          <!-- ===== FEATURES ===== -->
          @if (tab === 'features') {
            <p class="hint block">
              What the plan actually unlocks. These drive enforcement; the bullet list below is
              only marketing copy.
            </p>
            @for (group of entitlementGroups(); track group.key) {
              <div class="ent-group">
                <h4>{{ group.label }}</h4>
                @for (ent of group.items; track ent.key) {
                  <div class="ent-row">
                    @if (ent.valueType === 'BOOLEAN') {
                      <label class="inline">
                        <input type="checkbox"
                               [checked]="!!entitlements[ent.key]"
                               (change)="toggleEntitlement(ent.key, $event)">
                        {{ ent.label }}
                        @if (ent.salesQualified) {
                          <span class="badge badge-warning" title="Cannot be self-provisioned">manual</span>
                        }
                      </label>
                    } @else {
                      <label class="inline numeric">
                        {{ ent.label }}
                        <input type="number" [ngModel]="entitlements[ent.key]"
                               (ngModelChange)="setEntitlementValue(ent.key, $event)"
                               placeholder="0">
                      </label>
                    }
                  </div>
                }
              </div>
            }

            <label>Marketing bullets (one per line)
              <textarea [(ngModel)]="featuresText" rows="6"></textarea>
            </label>
          }

          <div class="modal-actions">
            <button class="btn btn-primary" [disabled]="saving" (click)="save()">
              {{ saving ? 'Saving…' : 'Save plan' }}
            </button>
            <button class="btn btn-secondary" (click)="close()">Cancel</button>
          </div>
        </div>
      </div>
    }
  `,
  // Shared primitives (page header, tabs, modals, form fields, callouts, text
  // utilities) come from the global styles.css. Only plan-editor specifics are here.
  styles: [`
    .name { font-weight:600; display:flex; align-items:center; gap:8px; }
    .actions { display:flex; gap:6px; }
    .warn { color:#B45309; font-weight:600; }

    /* Numeric entitlements pair a label with a narrow input. */
    .modal label.inline.numeric { display:grid; grid-template-columns:1fr 100px;
      align-items:center; gap:10px; font-weight:500; }

    .ent-group { margin-bottom:16px; }
    .ent-group h4 { font-size:12px; font-weight:700; text-transform:uppercase; letter-spacing:.04em;
      color:var(--text-secondary); margin-bottom:8px; }
    .ent-row { padding:3px 0; }
    .ent-row .badge { font-size:10px; }

    /* The editor is tall enough to scroll, so keep the save action visible. */
    .modal-actions { position:sticky; bottom:0; background:var(--surface); padding-top:14px; }
  `]
})
export class OrgSubscriptionsComponent implements OnInit {
  private api = inject(ApiService);
  private confirm = inject(ConfirmService);
  private errors = inject(ApiErrorService);

  plans: any[] = [];
  schema: any = null;

  showModal = false;
  editingId: number | null = null;
  saving = false;
  tab: 'basics' | 'pricing' | 'limits' | 'features' = 'basics';

  form: any = this.blankForm();
  featuresText = '';
  /** Entitlement key -> true or a number. Only granted keys are sent. */
  entitlements: Record<string, any> = {};

  ngOnInit() {
    this.load();
    this.api.get<any>('/api/org-subscriptions/schema').subscribe({
      next: s => (this.schema = s),
      error: err => this.errors.show(err, 'Could not load the plan schema')
    });
  }

  load() {
    this.api.get<any[]>('/api/org-subscriptions').subscribe({
      next: data => (this.plans = data),
      error: err => this.errors.show(err, 'Could not load plans')
    });
  }

  openCreate() {
    this.editingId = null;
    this.form = this.blankForm();
    this.featuresText = '';
    this.entitlements = {};
    this.tab = 'basics';
    this.showModal = true;
  }

  openEdit(plan: any) {
    this.editingId = plan.id;
    this.form = { ...plan };
    this.featuresText = (plan.features || []).join('\n');
    this.entitlements = { ...(plan.entitlements || {}) };
    this.tab = 'basics';
    this.showModal = true;
  }

  close() {
    this.showModal = false;
  }

  save() {
    this.saving = true;
    const payload = {
      ...this.form,
      features: this.featuresText.split('\n').map(s => s.trim()).filter(s => s.length > 0),
      entitlements: this.entitlements
    };
    const request = this.editingId
      ? this.api.put(`/api/org-subscriptions/${this.editingId}`, payload)
      : this.api.post('/api/org-subscriptions', payload);

    request.subscribe({
      next: () => {
        this.saving = false;
        this.showModal = false;
        this.errors.success('Plan saved. Existing subscriptions keep their agreed terms until renewal.');
        this.load();
      },
      error: err => {
        this.saving = false;
        this.errors.show(err, 'Could not save that plan');
      }
    });
  }

  async remove(plan: any) {
    if (!(await this.confirm.confirm(`Delete "${plan.name}"? Retiring it instead keeps history intact.`))) {
      return;
    }
    this.api.delete(`/api/org-subscriptions/${plan.id}`).subscribe({
      next: () => {
        this.errors.success('Plan deleted.');
        this.load();
      },
      error: err => this.errors.show(err, 'Could not delete that plan')
    });
  }

  // ---- Entitlement editing -------------------------------------------

  entitlementGroups(): { key: string; label: string; items: any[] }[] {
    const groups = new Map<string, { key: string; label: string; items: any[] }>();
    for (const e of this.schema?.entitlements ?? []) {
      if (!groups.has(e.category)) {
        groups.set(e.category, { key: e.category, label: e.categoryLabel, items: [] });
      }
      groups.get(e.category)!.items.push(e);
    }
    return Array.from(groups.values());
  }

  toggleEntitlement(key: string, event: Event) {
    const checked = (event.target as HTMLInputElement).checked;
    if (checked) {
      this.entitlements[key] = true;
    } else {
      // Removed rather than set false: absent means "not included", which keeps the
      // stored JSON to only what a plan actually grants.
      delete this.entitlements[key];
    }
  }

  setEntitlementValue(key: string, value: any) {
    const num = Number(value);
    if (!value || Number.isNaN(num) || num === 0) {
      delete this.entitlements[key];
    } else {
      this.entitlements[key] = num;
    }
  }

  // ---- Pricing previews ----------------------------------------------

  listPreview(): number | null {
    return this.form.priceMonthly ? this.form.priceMonthly * 12 : null;
  }

  savingPreview(): number | null {
    const list = this.listPreview();
    return list && this.form.priceYearly ? list - this.form.priceYearly : null;
  }

  discountPreview(): number | null {
    const list = this.listPreview();
    const saving = this.savingPreview();
    if (!list || saving == null) {
      return null;
    }
    return Math.round((saving / list) * 10000) / 100;
  }

  discountOutOfBand(): boolean {
    const pct = this.discountPreview();
    return pct !== null && (pct < 15 || pct > 20);
  }

  /** This plan's own price per student per month — the floor for overage pricing. */
  effectiveRate(): number | null {
    if (!this.form.priceMonthly || !this.form.maxActiveStudents) {
      return null;
    }
    return Math.round((this.form.priceMonthly / this.form.maxActiveStudents) * 100) / 100;
  }

  overageUndercuts(): boolean {
    const rate = this.effectiveRate();
    return rate !== null && this.form.overageStudentPrice != null
      && this.form.overageStudentPrice < rate;
  }

  private blankForm() {
    return {
      name: '',
      tagline: '',
      description: '',
      tierRank: 10,
      displayOrder: 10,
      isActive: true,
      isPublic: true,
      isPopular: false,
      isCustomPriced: false,
      requiresQuote: false,
      selfServeUpgradeEnabled: false,
      priceMonthly: null,
      priceYearly: null,
      overageStudentsAllowed: 0,
      overageStudentPrice: null,
      hsnSacCode: '997331',
      gstRatePct: 18,
      taxInclusive: false,
      trialDays: 0,
      graceDays: 15,
      maxActiveStudents: null,
      maxFacultyAccounts: null,
      maxBranches: null,
      maxOrganizations: 1,
      storageGb: null,
      includedTrainingHours: 0,
      limitsConfigurable: false,
      fulfilmentNotes: ''
    };
  }
}
