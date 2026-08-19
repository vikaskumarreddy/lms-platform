import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';
import { ApiErrorService } from '../../services/api-error.service';

/**
 * The platform team's subscription desk: the queue of tenant requests awaiting a
 * decision, and per-organization subscription control.
 *
 * <p>The queue exists because plan changes and add-ons are requested, not self-applied.
 * With no payment gateway collecting money at the moment a tenant clicks Upgrade,
 * granting the higher plan is a commercial decision someone has to take — this is
 * where they take it.
 */
@Component({
  selector: 'app-platform-billing',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="page-header">
      <div>
        <h1>Subscriptions</h1>
        <p class="muted">Tenant requests, plans in force, and per-organization controls.</p>
      </div>
    </div>

    <!-- ===== Pending plan changes ===== -->
    <div class="card">
      <h2>
        Plan change requests
        @if (planRequests.length) { <span class="badge badge-warning">{{ planRequests.length }}</span> }
      </h2>

      @if (planRequests.length) {
        <table>
          <thead>
            <tr><th>Organization</th><th>Requested</th><th>Current usage</th><th>Raised</th><th></th></tr>
          </thead>
          <tbody>
            @for (item of planRequests; track item.request.id) {
              <tr>
                <td>
                  <div class="name">{{ item.organizationName }}</div>
                  <div class="muted small">{{ item.organizationSlug }}</div>
                </td>
                <td>
                  <span class="badge"
                        [class.badge-success]="item.request.requestKind === 'UPGRADE'"
                        [class.badge-warning]="item.request.requestKind !== 'UPGRADE'">
                    {{ item.request.requestKind | titlecase }}
                  </span>
                  <div>{{ item.request.requestedPlanCode }}</div>
                  <div class="muted small">{{ item.request.requestedBillingCycle | titlecase }}</div>
                  @if (item.request.requestedNote) {
                    <div class="muted small note">"{{ item.request.requestedNote }}"</div>
                  }
                </td>
                <td class="muted small">
                  {{ item.currentUsage?.MAX_ACTIVE_STUDENTS }} active students,
                  {{ item.currentUsage?.MAX_FACULTY_ACCOUNTS }} faculty,
                  {{ item.currentUsage?.MAX_BRANCHES }} branches
                </td>
                <td class="muted small">
                  {{ item.request.createdAt | date:'MMM d, y' }}
                  <div>{{ item.request.requestedByEmail }}</div>
                </td>
                <td class="actions">
                  <button class="btn btn-sm btn-primary" (click)="approve(item.request.id)">Approve</button>
                  <button class="btn btn-sm btn-danger" (click)="reject(item.request.id)">Decline</button>
                </td>
              </tr>
            }
          </tbody>
        </table>
      } @else {
        <p class="muted">Nothing waiting.</p>
      }
    </div>

    <!-- ===== Pending add-on requests ===== -->
    <div class="card">
      <h2>
        Add-on requests
        @if (addonRequests.length) { <span class="badge badge-warning">{{ addonRequests.length }}</span> }
      </h2>

      @if (addonRequests.length) {
        <table>
          <thead>
            <tr><th>Add-on</th><th>Org</th><th>Quantity</th><th>Price</th><th>Requested by</th><th></th></tr>
          </thead>
          <tbody>
            @for (addon of addonRequests; track addon.id) {
              <tr>
                <td>
                  <div class="name">{{ addon.addonName }}</div>
                  <span class="badge" [class.badge-warning]="addon.status === 'PENDING_QUOTE'">
                    {{ addon.status === 'PENDING_QUOTE' ? 'Needs a quote' : 'Awaiting approval' }}
                  </span>
                </td>
                <td>{{ addon.organizationId }}</td>
                <td>{{ addon.qty }} {{ addon.unitLabel }}</td>
                <td>
                  <!-- A quoted add-on has no list price, so the figure has to be entered
                       here before it can be approved and invoiced. -->
                  <input type="number" class="price-input"
                         [(ngModel)]="addonPrices[addon.id]"
                         [placeholder]="addon.unitPrice ?? 'Enter price'">
                </td>
                <td class="muted small">{{ addon.requestedBy }}</td>
                <td class="actions">
                  <button class="btn btn-sm btn-primary" (click)="approveAddon(addon)">Approve</button>
                  <button class="btn btn-sm btn-danger" (click)="removeAddon(addon)">Decline</button>
                </td>
              </tr>
            }
          </tbody>
        </table>
      } @else {
        <p class="muted">Nothing waiting.</p>
      }
    </div>

    <!-- ===== Per-organization inspector ===== -->
    <div class="card">
      <h2>Organization subscriptions</h2>
      <table>
        <thead>
          <tr><th>Organization</th><th>Plan</th><th>Status</th><th>Active students</th><th>Renews</th><th></th></tr>
        </thead>
        <tbody>
          @for (org of organizations; track org.id) {
            <tr>
              <td>
                <div class="name">{{ org.name }}</div>
                <div class="muted small">{{ org.slug }}</div>
              </td>
              <td>{{ org.orgSubscriptionName || '—' }}</td>
              <td>
                <span class="badge"
                      [class.badge-success]="org.status === 'ACTIVE'"
                      [class.badge-danger]="org.status !== 'ACTIVE'">
                  {{ org.status }}
                </span>
              </td>
              <td>
                @if (details[org.id]) {
                  {{ details[org.id].usage?.MAX_ACTIVE_STUDENTS }}
                  <span class="muted">/ {{ details[org.id].limits?.MAX_ACTIVE_STUDENTS ?? '∞' }}</span>
                } @else { <span class="muted">—</span> }
              </td>
              <td class="muted small">{{ org.expiryDate | date:'MMM d, y' }}</td>
              <td class="actions">
                <button class="btn btn-sm btn-secondary" (click)="inspect(org)">
                  {{ details[org.id] ? 'Hide' : 'Inspect' }}
                </button>
                <button class="btn btn-sm btn-primary" (click)="renew(org)">Renew</button>
                @if (org.status === 'ACTIVE') {
                  <button class="btn btn-sm btn-danger" (click)="suspend(org)">Suspend</button>
                } @else {
                  <button class="btn btn-sm btn-primary" (click)="resume(org)">Resume</button>
                }
              </td>
            </tr>

            @if (details[org.id]; as detail) {
              <tr class="detail-row">
                <td colspan="6">
                  <div class="detail-grid">
                    <div>
                      <h4>Effective limits</h4>
                      <ul>
                        @for (entry of limitEntries(detail); track entry.key) {
                          <li>
                            <span>{{ entry.key }}</span>
                            <strong>{{ entry.value ?? 'Unlimited' }}</strong>
                            <span class="muted small">used {{ detail.usage[entry.key] }}</span>
                          </li>
                        }
                      </ul>
                    </div>
                    <div>
                      <h4>Add-ons</h4>
                      @if (detail.addons?.length) {
                        <ul>
                          @for (addon of detail.addons; track addon.id) {
                            <li>
                              <span>{{ addon.addonName }} ×{{ addon.qty }}</span>
                              <span class="badge badge-secondary">{{ addon.status }}</span>
                            </li>
                          }
                        </ul>
                      } @else { <p class="muted small">None.</p> }
                    </div>
                    <div>
                      <h4>Term history</h4>
                      <ul>
                        @for (term of detail.history; track term.id) {
                          <li>
                            <span>{{ term.planName }}</span>
                            <span class="muted small">
                              {{ term.periodStart | date:'MMM y' }} · {{ term.changeReason }}
                            </span>
                          </li>
                        }
                      </ul>
                    </div>
                  </div>
                </td>
              </tr>
            }
          }
        </tbody>
      </table>
    </div>
  `,
  styles: [`
    .page-header { margin-bottom:20px; }
    .page-header h1 { font-size:24px; font-weight:700; }
    .muted { color: var(--text-secondary); }
    .small { font-size:12px; }
    .name { font-weight:600; }
    .note { font-style:italic; margin-top:4px; }
    h2 { font-size:16px; font-weight:700; margin-bottom:12px; display:flex; align-items:center; gap:8px; }
    h4 { font-size:12px; font-weight:700; text-transform:uppercase; letter-spacing:.04em;
      color:var(--text-secondary); margin-bottom:8px; }
    .btn-sm { padding:6px 12px; font-size:12px; }
    .actions { white-space:nowrap; display:flex; gap:6px; flex-wrap:wrap; }
    .price-input { width:110px; padding:6px 10px; border:1px solid var(--border); border-radius:6px; }
    .detail-row td { background:var(--bg); }
    .detail-grid { display:grid; grid-template-columns:repeat(3,1fr); gap:24px; padding:8px 0; }
    .detail-grid ul { list-style:none; }
    .detail-grid li { display:flex; justify-content:space-between; gap:10px; align-items:center;
      font-size:13px; padding:4px 0; border-bottom:1px solid var(--border); }
    .detail-grid li:last-child { border-bottom:none; }
    @media (max-width:900px) { .detail-grid { grid-template-columns:1fr; } }
  `]
})
export class PlatformBillingComponent implements OnInit {
  private api = inject(ApiService);
  private errors = inject(ApiErrorService);

  planRequests: any[] = [];
  addonRequests: any[] = [];
  organizations: any[] = [];
  details: Record<number, any> = {};
  addonPrices: Record<number, number> = {};

  ngOnInit() {
    this.loadRequests();
    this.loadOrganizations();
  }

  loadRequests() {
    this.api.get<any[]>('/api/platform/subscriptions/change-requests').subscribe({
      next: data => (this.planRequests = data),
      error: err => this.errors.show(err, 'Could not load plan change requests')
    });
    this.api.get<any[]>('/api/platform/subscriptions/addon-requests').subscribe({
      next: data => (this.addonRequests = data),
      error: () => {}
    });
  }

  loadOrganizations() {
    this.api.get<any[]>('/api/organizations').subscribe({
      next: data => (this.organizations = data),
      error: err => this.errors.show(err, 'Could not load organizations')
    });
  }

  approve(requestId: number) {
    this.api.post(`/api/platform/subscriptions/change-requests/${requestId}/approve`, {}).subscribe({
      next: () => {
        this.errors.success('Plan change applied.');
        this.loadRequests();
        this.loadOrganizations();
      },
      error: err => this.errors.show(err, 'Could not approve that request')
    });
  }

  reject(requestId: number) {
    const note = prompt('Why are you declining this request?') ?? '';
    this.api.post(`/api/platform/subscriptions/change-requests/${requestId}/reject`, { note }).subscribe({
      next: () => {
        this.errors.success('Request declined.');
        this.loadRequests();
      },
      error: err => this.errors.show(err, 'Could not decline that request')
    });
  }

  approveAddon(addon: any) {
    const price = this.addonPrices[addon.id] ?? addon.unitPrice;
    if (price == null) {
      this.errors.info('Enter an agreed price first — a quoted add-on cannot be invoiced without one.');
      return;
    }
    this.api.post(`/api/platform/subscriptions/addons/${addon.id}/approve`, { unitPrice: price }).subscribe({
      next: () => {
        this.errors.success('Add-on approved.');
        this.loadRequests();
      },
      error: err => this.errors.show(err, 'Could not approve that add-on')
    });
  }

  removeAddon(addon: any) {
    this.api.delete(`/api/platform/subscriptions/addons/${addon.id}`).subscribe({
      next: () => {
        this.errors.success('Add-on removed.');
        this.loadRequests();
      },
      error: err => this.errors.show(err, 'Could not remove that add-on')
    });
  }

  inspect(org: any) {
    if (this.details[org.id]) {
      delete this.details[org.id];
      return;
    }
    this.api.get<any>(`/api/platform/subscriptions/${org.id}`).subscribe({
      next: data => (this.details[org.id] = data),
      error: err => this.errors.show(err, 'Could not load that subscription')
    });
  }

  renew(org: any) {
    this.api.post(`/api/platform/subscriptions/${org.id}/renew`, {}).subscribe({
      next: () => {
        this.errors.success(`${org.name} renewed.`);
        this.loadOrganizations();
        delete this.details[org.id];
      },
      error: err => this.errors.show(err, 'Could not renew that subscription')
    });
  }

  suspend(org: any) {
    const reason = prompt(`Why are you suspending ${org.name}?`) ?? '';
    this.api.post(`/api/platform/subscriptions/${org.id}/suspend`, { reason }).subscribe({
      next: () => {
        this.errors.success(`${org.name} suspended.`);
        this.loadOrganizations();
      },
      error: err => this.errors.show(err, 'Could not suspend that organization')
    });
  }

  resume(org: any) {
    this.api.post(`/api/platform/subscriptions/${org.id}/resume`, {}).subscribe({
      next: () => {
        this.errors.success(`${org.name} resumed.`);
        this.loadOrganizations();
      },
      error: err => this.errors.show(err, 'Could not resume that organization')
    });
  }

  limitEntries(detail: any): { key: string; value: any }[] {
    return Object.entries(detail.limits || {}).map(([key, value]) => ({ key, value }));
  }
}
