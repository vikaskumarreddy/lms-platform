import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';
import { ApiErrorService } from '../../services/api-error.service';

/**
 * Platform add-on catalog editor.
 *
 * <p>The two fields that matter most are "raises limit" and "grants feature": they are
 * what connect a priced SKU to actual enforcement. Both are chosen from server-supplied
 * lists rather than typed freehand, because an add-on pointing at a limit the platform
 * does not enforce would be sold, invoiced, and silently grant the customer nothing.
 */
@Component({
  selector: 'app-platform-addons',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="page-header">
      <div>
        <h1>Add-ons</h1>
        <p class="muted">Everything that can be sold alongside a plan.</p>
      </div>
      <button class="btn btn-primary" (click)="openCreate()">+ New add-on</button>
    </div>

    @for (group of grouped(); track group.key) {
      <div class="card">
        <h2>{{ group.label }}</h2>
        <table>
          <thead>
            <tr>
              <th>Add-on</th><th>Pricing</th><th>Default</th><th>Band</th>
              <th>Raises / grants</th><th>Status</th><th></th>
            </tr>
          </thead>
          <tbody>
            @for (addon of group.items; track addon.id) {
              <tr>
                <td>
                  <div class="name">{{ addon.name }}</div>
                  <div class="muted small">{{ addon.code }}</div>
                </td>
                <td>
                  {{ addon.pricingModelLabel }}
                  @if (addon.unitLabel) { <div class="muted small">per {{ addon.unitLabel }}</div> }
                </td>
                <td>{{ addon.defaultUnitPrice != null ? ('₹' + (addon.defaultUnitPrice | number:'1.0-2')) : '—' }}</td>
                <td class="muted small">
                  @if (addon.unitPriceMin != null) {
                    ₹{{ addon.unitPriceMin | number:'1.0-2' }} – ₹{{ addon.unitPriceMax | number:'1.0-2' }}
                  } @else { — }
                </td>
                <td class="small">
                  @if (addon.incrementsLimitLabel) {
                    <span class="badge badge-info">+ {{ addon.incrementsLimitLabel }}</span>
                  }
                  @if (addon.grantsEntitlementLabel) {
                    <span class="badge badge-secondary">{{ addon.grantsEntitlementLabel }}</span>
                  }
                  @if (!addon.incrementsLimitLabel && !addon.grantsEntitlementLabel) {
                    <span class="muted">Billing only</span>
                  }
                </td>
                <td>
                  <span class="badge" [class.badge-success]="addon.isActive" [class.badge-secondary]="!addon.isActive">
                    {{ addon.isActive ? 'Active' : 'Inactive' }}
                  </span>
                  @if (addon.requiresQuote) { <span class="badge badge-warning">Quoted</span> }
                </td>
                <td><button class="btn btn-sm btn-secondary" (click)="openEdit(addon)">Edit</button></td>
              </tr>
            }
          </tbody>
        </table>
      </div>
    }

    @if (showModal) {
      <div class="modal-backdrop" (click)="close()">
        <div class="modal modal-wide" (click)="$event.stopPropagation()">
          <h2>{{ editingId ? 'Edit' : 'New' }} add-on</h2>

          <div class="form-grid">
            <label>Name
              <input [(ngModel)]="form.name" placeholder="Additional active students">
            </label>
            <label>Category
              <select [(ngModel)]="form.category">
                @for (c of schema?.categories; track c.key) {
                  <option [value]="c.key">{{ c.label }}</option>
                }
              </select>
            </label>
          </div>

          <label>Description
            <textarea [(ngModel)]="form.description" rows="2"></textarea>
          </label>

          <div class="form-grid">
            <label>Pricing model
              <select [(ngModel)]="form.pricingModel">
                @for (m of schema?.pricingModels; track m.key) {
                  <option [value]="m.key">{{ m.label }}</option>
                }
              </select>
            </label>
            <label>Unit label
              <input [(ngModel)]="form.unitLabel" placeholder="active student">
            </label>
          </div>

          <div class="form-grid-3">
            <label>Min price <input type="number" [(ngModel)]="form.unitPriceMin"></label>
            <label>Default <input type="number" [(ngModel)]="form.defaultUnitPrice"></label>
            <label>Max price <input type="number" [(ngModel)]="form.unitPriceMax"></label>
          </div>

          <div class="form-grid-3">
            <label>Min qty <input type="number" [(ngModel)]="form.minQty"></label>
            <label>Block size <input type="number" [(ngModel)]="form.qtyIncrement"></label>
            <label>Max qty <input type="number" [(ngModel)]="form.maxQty"></label>
          </div>

          <div class="form-grid">
            <label>Raises limit
              <select [(ngModel)]="form.incrementsLimitKey">
                <option [ngValue]="null">— none —</option>
                @for (l of planSchema?.limits; track l.key) {
                  <option [value]="l.key">{{ l.label }}</option>
                }
              </select>
            </label>
            <label>Grants feature
              <select [(ngModel)]="form.grantsEntitlementKey">
                <option [ngValue]="null">— none —</option>
                @for (e of planSchema?.entitlements; track e.key) {
                  <option [value]="e.key">{{ e.label }}</option>
                }
              </select>
            </label>
          </div>

          <div class="form-grid">
            <label>SAC code <input [(ngModel)]="form.hsnSacCode" placeholder="997331"></label>
            <label>GST % <input type="number" [(ngModel)]="form.gstRatePct"></label>
          </div>

          <label>Only on these plans (blank = all)
            <input [(ngModel)]="appliesToText" placeholder="PLATFORM_PLUS, MANAGED_ACADEMY, ENTERPRISE">
          </label>

          <label>Delivery notes (internal — never shown to tenants)
            <textarea [(ngModel)]="form.fulfilmentNotes" rows="3"
                      placeholder="How this is actually delivered, and anything that must be scoped first."></textarea>
          </label>

          <div class="checkboxes">
            <label class="inline"><input type="checkbox" [(ngModel)]="form.isActive"> Active</label>
            <label class="inline"><input type="checkbox" [(ngModel)]="form.requiresQuote"> Needs a quote</label>
            <label class="inline"><input type="checkbox" [(ngModel)]="form.taxInclusive"> Price includes GST</label>
          </div>

          <div class="modal-actions">
            <button class="btn btn-primary" [disabled]="saving" (click)="save()">
              {{ saving ? 'Saving…' : 'Save' }}
            </button>
            <button class="btn btn-secondary" (click)="close()">Cancel</button>
          </div>
        </div>
      </div>
    }
  `,
  // Shared primitives (page header, modals, form grids, text utilities) come from
  // the global styles.css. Only add-on catalog specifics are here.
  styles: [`
    .name { font-weight:600; }
    h2 { font-size:16px; font-weight:700; margin-bottom:12px; }
    .badge { margin-right:4px; }
  `]
})
export class PlatformAddonsComponent implements OnInit {
  private api = inject(ApiService);
  private errors = inject(ApiErrorService);

  addons: any[] = [];
  schema: any = null;
  /** Reused from the plan endpoint: the limit and entitlement vocabulary. */
  planSchema: any = null;

  showModal = false;
  editingId: number | null = null;
  saving = false;
  appliesToText = '';
  form: any = this.blankForm();

  ngOnInit() {
    this.load();
    this.api.get<any>('/api/plan-addons/schema').subscribe({
      next: s => (this.schema = s),
      error: () => {}
    });
    this.api.get<any>('/api/org-subscriptions/schema').subscribe({
      next: s => (this.planSchema = s),
      error: () => {}
    });
  }

  load() {
    this.api.get<any[]>('/api/plan-addons').subscribe({
      next: data => (this.addons = data),
      error: err => this.errors.show(err, 'Could not load add-ons')
    });
  }

  grouped(): { key: string; label: string; items: any[] }[] {
    const groups = new Map<string, { key: string; label: string; items: any[] }>();
    for (const a of this.addons) {
      const key = a.category || 'OTHER';
      if (!groups.has(key)) {
        groups.set(key, { key, label: a.categoryLabel || 'Other', items: [] });
      }
      groups.get(key)!.items.push(a);
    }
    return Array.from(groups.values());
  }

  openCreate() {
    this.editingId = null;
    this.form = this.blankForm();
    this.appliesToText = '';
    this.showModal = true;
  }

  openEdit(addon: any) {
    this.editingId = addon.id;
    this.form = { ...addon };
    this.appliesToText = (addon.appliesToPlanCodes || []).join(', ');
    this.showModal = true;
  }

  close() {
    this.showModal = false;
  }

  save() {
    this.saving = true;
    const payload = {
      ...this.form,
      appliesToPlanCodes: this.appliesToText
        .split(',')
        .map(s => s.trim())
        .filter(s => s.length > 0)
    };
    const request = this.editingId
      ? this.api.put(`/api/plan-addons/${this.editingId}`, payload)
      : this.api.post('/api/plan-addons', payload);

    request.subscribe({
      next: () => {
        this.saving = false;
        this.showModal = false;
        this.errors.success('Add-on saved.');
        this.load();
      },
      error: err => {
        this.saving = false;
        this.errors.show(err, 'Could not save that add-on');
      }
    });
  }

  private blankForm() {
    return {
      name: '',
      description: '',
      category: 'CAPACITY',
      pricingModel: 'PER_UNIT_MONTH',
      unitLabel: '',
      unitPriceMin: null,
      unitPriceMax: null,
      defaultUnitPrice: null,
      minQty: 1,
      qtyIncrement: 1,
      maxQty: null,
      incrementsLimitKey: null,
      grantsEntitlementKey: null,
      hsnSacCode: '997331',
      gstRatePct: 18,
      taxInclusive: false,
      requiresQuote: false,
      isActive: true,
      fulfilmentNotes: ''
    };
  }
}
