import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { ApiService } from '../../services/api.service';
import { ApiErrorService } from '../../services/api-error.service';
import { formatDateTimeDisplay } from '../../utils/date.util';
import { ConfirmService } from '../../services/confirm.service';

/** One student's enrolment fee. Cash rows have no gateway ids. */
interface Txn {
  studentId: number;
  studentName: string;
  studentEmail?: string | null;
  paymentMethod: string;
  paymentStatus: string;
  amountDue: number;
  paidAt?: string | null;
  notes?: string | null;
  razorpayOrderId?: string | null;
  razorpayPaymentId?: string | null;
  attemptCount?: number | null;
  lastError?: string | null;
}

interface Summary {
  totalCollected: number;
  pendingAmount: number;
  refundedAmount: number;
  cashCount: number;
  onlineCount: number;
  paidCount: number;
  pendingCount: number;
}

@Component({
  selector: 'app-payments',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  template: `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;flex-wrap:wrap;gap:12px;">
      <h1 style="font-size:24px;font-weight:700;margin:0;">💳 Payments</h1>
      <a routerLink="/payment-settings" class="btn btn-secondary">⚙️ Payment Settings</a>
    </div>

    <!-- Nothing can be collected online until the tenant's own Razorpay keys are in. -->
    <div *ngIf="gatewayOff" class="card"
         style="margin-bottom:20px;background:#FEF3C7;border:1px solid #FCD34D;color:#78350F;padding:14px 18px;">
      Online collection is switched off, so every student is on cash.
      <a routerLink="/payment-settings" style="color:#78350F;font-weight:700;">Set up Razorpay</a> to collect fees in the app.
    </div>

    <div class="grid-4" style="margin-bottom:20px;">
      <div class="card">
        <div style="color:#64748B;font-size:14px;">Collected</div>
        <div style="font-size:24px;font-weight:700;">{{money(summary?.totalCollected)}}</div>
        <div style="color:#94A3B8;font-size:12px;">{{summary?.paidCount || 0}} student{{summary?.paidCount === 1 ? '' : 's'}}</div>
      </div>
      <div class="card">
        <div style="color:#64748B;font-size:14px;">Outstanding</div>
        <div style="font-size:24px;font-weight:700;color:#B91C1C;">{{money(summary?.pendingAmount)}}</div>
        <div style="color:#94A3B8;font-size:12px;">{{summary?.pendingCount || 0}} unpaid</div>
      </div>
      <div class="card">
        <div style="color:#64748B;font-size:14px;">Refunded</div>
        <div style="font-size:24px;font-weight:700;">{{money(summary?.refundedAmount)}}</div>
      </div>
      <div class="card">
        <div style="color:#64748B;font-size:14px;">Split</div>
        <div style="font-size:24px;font-weight:700;">{{summary?.onlineCount || 0}} / {{summary?.cashCount || 0}}</div>
        <div style="color:#94A3B8;font-size:12px;">online / cash</div>
      </div>
    </div>

    <div class="card" style="margin-bottom:20px;display:flex;gap:12px;align-items:center;flex-wrap:wrap;">
      <div style="display:flex;align-items:center;gap:8px;flex:1;min-width:min(100%, 200px);">
        <label style="font-weight:600;font-size:14px;white-space:nowrap;">Show:</label>
        <select [(ngModel)]="filter" name="filter" style="width:100%;padding:8px;border:1px solid #E2E8F0;border-radius:8px;">
          <option value="all">All students</option>
          <option value="due">Outstanding only</option>
          <option value="paid">Paid only</option>
          <option value="cash">Cash only</option>
          <option value="online">Online only</option>
        </select>
      </div>
      <input type="text" [(ngModel)]="search" name="search" placeholder="Search name or email"
             style="padding:8px 12px;border:1px solid #E2E8F0;border-radius:8px;flex:2;min-width:min(100%, 200px);">
      <span style="color:#64748B;font-size:13px;white-space:nowrap;">{{filtered.length}} of {{transactions.length}}</span>
    </div>

    <!-- Mobile View (< 992px) -->
    <div class="mobile-only" style="margin-bottom:20px;">
      <div class="mobile-card-list">
        <div class="mobile-data-card" *ngFor="let t of filtered">
          <div class="mobile-card-header">
            <div style="min-width:0;">
              <div class="mobile-card-title">{{t.studentName}}</div>
              <div class="mobile-card-sub">{{t.studentEmail || '—'}}</div>
            </div>
            <span class="badge"
                  [class.badge-success]="isPaid(t)"
                  [class.badge-warning]="!isPaid(t) && t.paymentMethod === 'ONLINE'"
                  [class.badge-danger]="!isPaid(t) && t.paymentMethod !== 'ONLINE'">
              {{isPaid(t) ? 'Paid' : 'Pending'}}
            </span>
          </div>

          <div class="mobile-card-chips">
            <span class="badge" style="font-size:14px;font-weight:700;background:#F1F5F9;color:#0F172A;">
              {{money(t.amountDue)}}
            </span>
            <span class="badge"
                  [style.background]="t.paymentMethod === 'ONLINE' ? '#EEF2FF' : '#F1F5F9'"
                  [style.color]="t.paymentMethod === 'ONLINE' ? '#4338CA' : '#475569'">
              {{t.paymentMethod === 'ONLINE' ? '🌐 Online' : '💵 Cash'}}
            </span>
          </div>

          <div class="mobile-card-meta">
            <span class="mobile-card-meta-item" *ngIf="t.paidAt">🗓️ Paid: {{formatDate(t.paidAt)}}</span>
            <span class="mobile-card-meta-item" *ngIf="t.razorpayPaymentId">Ref: {{t.razorpayPaymentId}}</span>
            <span class="mobile-card-meta-item" *ngIf="t.notes">Note: {{t.notes}}</span>
          </div>

          <div *ngIf="t.lastError && !isPaid(t)" style="color:#B91C1C;font-size:12px;background:#FEE2E2;padding:6px 10px;border-radius:6px;">
            ⚠️ Last attempt failed: {{t.lastError}}
          </div>

          <div class="mobile-card-actions" *ngIf="!isPaid(t)">
            <button class="btn btn-primary btn-sm" (click)="markPaid(t)" [disabled]="busyId === t.studentId">
              {{busyId === t.studentId ? 'Saving...' : '✓ Mark Paid (Cash)'}}
            </button>
          </div>
        </div>

        <div *ngIf="!loading && filtered.length === 0" class="empty-state">
          <span class="empty-icon">💳</span>
          <h3>{{transactions.length === 0 ? 'No fee records yet' : 'No students match this filter'}}</h3>
          <p *ngIf="transactions.length === 0">Fee records are automatically created when you add a student.</p>
        </div>

        <div *ngIf="loading" style="text-align:center;padding:32px;color:#64748B;">
          Loading…
        </div>
      </div>
    </div>

    <!-- Desktop View (>= 992px) -->
    <div class="card desktop-only">
      <table>
        <thead>
          <tr>
            <th>Student</th>
            <th>Method</th>
            <th>Amount</th>
            <th>Paid On</th>
            <th>Reference</th>
            <th>Status</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr *ngFor="let t of filtered">
            <td>
              <div style="font-weight:600;">{{t.studentName}}</div>
              <div style="color:#94A3B8;font-size:12px;">{{t.studentEmail || '—'}}</div>
            </td>
            <td>
              <span class="badge"
                    [style.background]="t.paymentMethod === 'ONLINE' ? '#EEF2FF' : '#F1F5F9'"
                    [style.color]="t.paymentMethod === 'ONLINE' ? '#4338CA' : '#475569'">
                {{t.paymentMethod === 'ONLINE' ? 'Online' : 'Cash'}}
              </span>
            </td>
            <td style="font-weight:600;">{{money(t.amountDue)}}</td>
            <td>{{t.paidAt ? formatDate(t.paidAt) : '—'}}</td>
            <td style="max-width:200px;">
              <span *ngIf="t.razorpayPaymentId" style="font-family:monospace;font-size:12px;">{{t.razorpayPaymentId}}</span>
              <span *ngIf="!t.razorpayPaymentId && t.notes" style="font-size:12px;color:#64748B;">{{t.notes}}</span>
              <span *ngIf="!t.razorpayPaymentId && !t.notes" style="color:#94A3B8;">—</span>
              <!-- A failed attempt is the single most useful thing to surface here:
                   it tells the admin why the student is still locked out. -->
              <div *ngIf="t.lastError && !isPaid(t)" style="color:#B91C1C;font-size:11px;margin-top:2px;">
                Last attempt failed: {{t.lastError}}
              </div>
            </td>
            <td>
              <span class="badge"
                    [class.badge-success]="isPaid(t)"
                    [class.badge-warning]="!isPaid(t) && t.paymentMethod === 'ONLINE'"
                    [class.badge-danger]="!isPaid(t) && t.paymentMethod !== 'ONLINE'">
                {{isPaid(t) ? 'Paid' : 'Pending'}}
              </span>
            </td>
            <td style="white-space:nowrap;">
              <button *ngIf="!isPaid(t)" class="btn btn-primary" style="padding:6px 12px;font-size:12px;"
                      (click)="markPaid(t)" [disabled]="busyId === t.studentId">
                {{busyId === t.studentId ? 'Saving...' : 'Mark Paid'}}
              </button>
              <span *ngIf="isPaid(t)" style="color:#94A3B8;font-size:12px;">—</span>
            </td>
          </tr>
          <tr *ngIf="!loading && filtered.length === 0">
            <td colspan="7" style="text-align:center;padding:32px;color:#64748B;">
              {{transactions.length === 0 ? 'No fee records yet. They are created when you add a student.' : 'No students match this filter.'}}
            </td>
          </tr>
          <tr *ngIf="loading">
            <td colspan="7" style="text-align:center;padding:32px;color:#64748B;">Loading…</td>
          </tr>
        </tbody>
      </table>
    </div>
  `
})
export class PaymentsComponent implements OnInit {
  private api = inject(ApiService);
  private confirm = inject(ConfirmService);
  private errors = inject(ApiErrorService);

  transactions: Txn[] = [];
  summary: Summary | null = null;
  gatewayOff = false;
  loading = true;
  busyId: number | null = null;
  filter: 'all' | 'due' | 'paid' | 'cash' | 'online' = 'all';
  search = '';

  ngOnInit() {
    this.load();
    this.api.get<any>('/api/org-razorpay-config').subscribe({
      next: (c) => { this.gatewayOff = !c?.paymentEnabled; },
      error: () => { this.gatewayOff = true; }
    });
  }

  load() {
    this.loading = true;
    this.api.get<Txn[]>('/api/payments/transactions').subscribe({
      next: (data) => { this.transactions = data || []; this.loading = false; },
      error: (err) => { console.error('Failed to load payments', err); this.transactions = []; this.loading = false; }
    });
    this.api.get<Summary>('/api/payments/summary').subscribe({
      next: (data) => { this.summary = data; },
      error: () => { this.summary = null; }
    });
  }

  get filtered(): Txn[] {
    const term = this.search.trim().toLowerCase();
    return this.transactions.filter(t => {
      if (this.filter === 'due' && this.isPaid(t)) return false;
      if (this.filter === 'paid' && !this.isPaid(t)) return false;
      if (this.filter === 'cash' && t.paymentMethod === 'ONLINE') return false;
      if (this.filter === 'online' && t.paymentMethod !== 'ONLINE') return false;
      if (!term) return true;
      return (t.studentName || '').toLowerCase().includes(term)
          || (t.studentEmail || '').toLowerCase().includes(term);
    });
  }

  isPaid(t: Txn): boolean {
    return t.paymentStatus === 'COMPLETED';
  }

  /** Amounts travel in paise so no float ever touches the ledger. */
  money(paise?: number | null): string {
    const rupees = (paise || 0) / 100;
    return '₹' + rupees.toLocaleString('en-IN', { minimumFractionDigits: 0, maximumFractionDigits: 2 });
  }

  formatDate(value?: string | null): string {
    return formatDateTimeDisplay(value || undefined);
  }

  /** Records an offline settlement; this is what unlocks a gated ONLINE student. */
  async markPaid(t: Txn) {
    if (!(await this.confirm.confirm(`Mark ${t.studentName}'s fee as received?`))) return;
    this.busyId = t.studentId;
    this.api.post(`/api/payments/mark-paid/${t.studentId}`, { notes: 'Marked received by admin' }).subscribe({
      next: () => { this.busyId = null; this.load(); },
      error: (err) => {
        this.busyId = null;
        this.errors.show(err, 'Could not record the payment');
      }
    });
  }
}
