import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { ApiService } from '../../services/api.service';

/**
 * Reads back with secrets masked: the API only ever returns a hint plus a
 * "…Set" flag, never the stored value.
 */
interface ConfigView {
  configured: boolean;
  paymentEnabled: boolean;
  amountPerStudent: number;
  razorpayKeyId: string | null;
  keySecretSet: boolean;
  keySecretHint?: string | null;
  webhookSecretSet: boolean;
  webhookSecretHint?: string | null;
}

/** One vendor's masked config, as returned per-gateway by /api/org-payment-gateway-config. */
interface GatewayConfigView {
  configured: boolean;
  enabled: boolean;
  amountPerStudent: number | null;
  credentialHints: Record<string, string | null>;
}

type OtherGateway = 'PAYU' | 'CASHFREE';

/**
 * The tenant's own Razorpay account.
 *
 * <p>Multi-account by design — fees land in this institute's bank, not the
 * platform's — so the credentials belong to the organization and are entered here
 * rather than being baked into the deployment.
 */
@Component({
  selector: 'app-payment-settings',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  template: `
    <div class="page-head">
      <h1>⚙️ Payment Settings</h1>
      <a routerLink="/payments" class="btn btn-secondary">← Back to Payments</a>
    </div>

    <div class="card gateway-picker">
      <div class="gateway-tabs">
        <button type="button" class="tab-btn" [class.active]="activeTab === 'RAZORPAY'" (click)="activeTab = 'RAZORPAY'">Razorpay</button>
        <button type="button" class="tab-btn" [class.active]="activeTab === 'PAYU'" (click)="activeTab = 'PAYU'">PayU</button>
        <button type="button" class="tab-btn" [class.active]="activeTab === 'CASHFREE'" (click)="activeTab = 'CASHFREE'">Cashfree</button>
      </div>
      <div class="active-gateway-row">
        <label for="activeGateway">Active gateway for student payments</label>
        <select id="activeGateway" [(ngModel)]="activeGateway" name="activeGatewaySelect" (ngModelChange)="saveActiveGateway($event)">
          <option value="RAZORPAY">Razorpay</option>
          <option value="PAYU">PayU</option>
          <option value="CASHFREE">Cashfree</option>
        </select>
        <span class="status-hint" *ngIf="activeGatewaySaved">Saved.</span>
      </div>
    </div>

    <div class="card settings-card" *ngIf="activeTab === 'RAZORPAY'">
      <div class="status-row">
        <span class="badge"
              [style.background]="config?.paymentEnabled ? '#DCFCE7' : '#F1F5F9'"
              [style.color]="config?.paymentEnabled ? '#166534' : '#475569'">
          {{config?.paymentEnabled ? 'Online collection ON' : 'Online collection OFF'}}
        </span>
        <span class="status-hint" *ngIf="config?.configured && !config?.paymentEnabled">
          Keys saved — switch it on below to start collecting.
        </span>
      </div>

      <p class="intro">
        Fees are collected into <strong>your own Razorpay account</strong>, so payouts reach your
        bank directly. Find these values in the Razorpay Dashboard under
        <em>Settings → API Keys</em>, and the webhook secret under <em>Settings → Webhooks</em>.
      </p>

      <form (ngSubmit)="save()">
        <div class="form-grid">
          <div class="field wide">
            <label for="keyId">Razorpay Key ID</label>
            <input id="keyId" type="text" [(ngModel)]="form.razorpayKeyId" name="razorpayKeyId"
                   placeholder="rzp_live_XXXXXXXXXXXX">
            <small>Public identifier for your account — safe to share.</small>
          </div>

          <div class="field wide">
            <label for="keySecret">
              Key Secret
              <span class="saved" *ngIf="config?.keySecretSet">saved · {{config?.keySecretHint}}</span>
            </label>
            <input id="keySecret" type="password" [(ngModel)]="form.razorpayKeySecret" name="razorpayKeySecret"
                   autocomplete="new-password"
                   [placeholder]="config?.keySecretSet ? 'Leave blank to keep the saved secret' : 'Paste your key secret'">
          </div>

          <div class="field wide">
            <label for="webhookSecret">
              Webhook Secret
              <span class="saved" *ngIf="config?.webhookSecretSet">saved · {{config?.webhookSecretHint}}</span>
            </label>
            <input id="webhookSecret" type="password" [(ngModel)]="form.razorpayWebhookSecret" name="razorpayWebhookSecret"
                   autocomplete="new-password"
                   [placeholder]="config?.webhookSecretSet ? 'Leave blank to keep the saved secret' : 'Paste your webhook secret'">
          </div>

          <div class="field">
            <label for="fee">Fee per student</label>
            <input id="fee" type="text" value="Set per subscription plan" disabled>
            <small>The amount charged is each student's subscription plan price (Manage Plans) — not a fixed fee here.</small>
          </div>

          <div class="field">
            <label for="enabled">Online collection</label>
            <select id="enabled" [(ngModel)]="form.paymentEnabled" name="paymentEnabled">
              <option [ngValue]="false">Off — everyone pays cash</option>
              <option [ngValue]="true">On — offer online at enrolment</option>
            </select>
            <small>Turning this on adds the Online option when adding a student.</small>
          </div>
        </div>

        <!-- The webhook is what actually confirms a payment; without it a student can pay
             and still be stuck at the gate, so the URL is spelled out rather than assumed. -->
        <div class="webhook-panel">
          <div class="webhook-title">One-time Razorpay setup</div>
          <p>
            Add this webhook URL in your Razorpay Dashboard and subscribe it to <strong>payment.captured</strong>:
          </p>
          <div class="webhook-row">
            <code>{{webhookUrl}}</code>
            <button type="button" class="btn btn-secondary" (click)="copyWebhook()">
              {{copied ? '✓ Copied' : 'Copy'}}
            </button>
          </div>
        </div>

        <div class="actions">
          <button type="submit" class="btn btn-accent" [disabled]="saving">{{saving ? 'Saving…' : 'Save Settings'}}</button>
        </div>
      </form>

      <div class="alert alert-error" *ngIf="error">{{error}}</div>
      <div class="alert alert-ok" *ngIf="saved">Settings saved.</div>
    </div>

    <div class="card settings-card" *ngIf="activeTab === 'PAYU'">
      <div class="status-row">
        <span class="badge"
              [style.background]="gatewayConfig?.PAYU?.enabled ? '#DCFCE7' : '#F1F5F9'"
              [style.color]="gatewayConfig?.PAYU?.enabled ? '#166534' : '#475569'">
          {{gatewayConfig?.PAYU?.enabled ? 'Online collection ON' : 'Online collection OFF'}}
        </span>
      </div>

      <p class="intro">
        Fees are collected into <strong>your PayU merchant account</strong>. Find your Merchant Key
        and Salt in the PayU Dashboard under <em>Settings → My Account</em>.
      </p>

      <form (ngSubmit)="saveOther('PAYU')">
        <div class="form-grid">
          <div class="field wide">
            <label for="payuKey">Merchant Key</label>
            <input id="payuKey" type="text" [(ngModel)]="otherForms.PAYU.key" name="payuKey" placeholder="gtKFFx">
          </div>

          <div class="field wide">
            <label for="payuSalt">
              Salt
              <span class="saved" *ngIf="gatewayConfig?.PAYU?.credentialHints?.salt">saved · {{gatewayConfig?.PAYU?.credentialHints?.salt}}</span>
            </label>
            <input id="payuSalt" type="password" [(ngModel)]="otherForms.PAYU.salt" name="payuSalt" autocomplete="new-password"
                   [placeholder]="gatewayConfig?.PAYU?.credentialHints?.salt ? 'Leave blank to keep the saved salt' : 'Paste your salt'">
          </div>

          <div class="field">
            <label for="payuMode">Mode</label>
            <select id="payuMode" [(ngModel)]="otherForms.PAYU.mode" name="payuMode">
              <option value="TEST">Test</option>
              <option value="LIVE">Live</option>
            </select>
          </div>

          <div class="field">
            <label for="payuFee">Fee per student</label>
            <input id="payuFee" type="text" value="Set per subscription plan" disabled>
            <small>Charged amount = the student's subscription plan price.</small>
          </div>

          <div class="field">
            <label for="payuEnabled">Online collection</label>
            <select id="payuEnabled" [(ngModel)]="otherForms.PAYU.enabled" name="payuEnabled">
              <option [ngValue]="false">Off</option>
              <option [ngValue]="true">On</option>
            </select>
          </div>
        </div>

        <div class="actions">
          <button type="submit" class="btn btn-accent" [disabled]="saving">{{saving ? 'Saving…' : 'Save Settings'}}</button>
        </div>
      </form>

      <div class="alert alert-error" *ngIf="error">{{error}}</div>
      <div class="alert alert-ok" *ngIf="saved">Settings saved.</div>
    </div>

    <div class="card settings-card" *ngIf="activeTab === 'CASHFREE'">
      <div class="status-row">
        <span class="badge"
              [style.background]="gatewayConfig?.CASHFREE?.enabled ? '#DCFCE7' : '#F1F5F9'"
              [style.color]="gatewayConfig?.CASHFREE?.enabled ? '#166534' : '#475569'">
          {{gatewayConfig?.CASHFREE?.enabled ? 'Online collection ON' : 'Online collection OFF'}}
        </span>
      </div>

      <p class="intro">
        Fees are collected into <strong>your Cashfree account</strong>. Find your App ID and Secret
        Key in the Cashfree Dashboard under <em>Developers → API Keys</em>.
      </p>

      <form (ngSubmit)="saveOther('CASHFREE')">
        <div class="form-grid">
          <div class="field wide">
            <label for="cfAppId">App ID</label>
            <input id="cfAppId" type="text" [(ngModel)]="otherForms.CASHFREE.appId" name="cfAppId">
          </div>

          <div class="field wide">
            <label for="cfSecret">
              Secret Key
              <span class="saved" *ngIf="gatewayConfig?.CASHFREE?.credentialHints?.secretKey">saved · {{gatewayConfig?.CASHFREE?.credentialHints?.secretKey}}</span>
            </label>
            <input id="cfSecret" type="password" [(ngModel)]="otherForms.CASHFREE.secretKey" name="cfSecret" autocomplete="new-password"
                   [placeholder]="gatewayConfig?.CASHFREE?.credentialHints?.secretKey ? 'Leave blank to keep the saved secret' : 'Paste your secret key'">
          </div>

          <div class="field">
            <label for="cfMode">Mode</label>
            <select id="cfMode" [(ngModel)]="otherForms.CASHFREE.mode" name="cfMode">
              <option value="TEST">Test (sandbox)</option>
              <option value="LIVE">Live</option>
            </select>
          </div>

          <div class="field">
            <label for="cfFee">Fee per student</label>
            <input id="cfFee" type="text" value="Set per subscription plan" disabled>
            <small>Charged amount = the student's subscription plan price.</small>
          </div>

          <div class="field">
            <label for="cfEnabled">Online collection</label>
            <select id="cfEnabled" [(ngModel)]="otherForms.CASHFREE.enabled" name="cfEnabled">
              <option [ngValue]="false">Off</option>
              <option [ngValue]="true">On</option>
            </select>
          </div>
        </div>

        <div class="actions">
          <button type="submit" class="btn btn-accent" [disabled]="saving">{{saving ? 'Saving…' : 'Save Settings'}}</button>
        </div>
      </form>

      <div class="alert alert-error" *ngIf="error">{{error}}</div>
      <div class="alert alert-ok" *ngIf="saved">Settings saved.</div>
    </div>
  `,
  // The design system only styles labels and inputs inside `.modal-overlay fieldset`,
  // so a plain routed page like this one has to bring its own form styling rather
  // than reusing `.popup-form-grid`, which alone leaves labels inline and inputs bare.
  styles: [`
    .page-head{display:flex;justify-content:space-between;align-items:center;gap:16px;margin-bottom:24px}
    .page-head h1{font-size:24px;font-weight:700;margin:0}

    .settings-card{max-width:720px}

    .gateway-picker{max-width:720px;padding:16px 18px}
    .gateway-tabs{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:14px}
    .tab-btn{
      padding:8px 16px;border-radius:8px;border:1px solid #CBD5E1;background:#fff;
      font-size:13px;font-weight:600;color:#475569;cursor:pointer;
    }
    .tab-btn.active{background:#0D9488;border-color:#0D9488;color:#fff}
    .active-gateway-row{display:flex;align-items:center;gap:10px;flex-wrap:wrap}
    .active-gateway-row label{font-size:13px;font-weight:600;color:#134E4A}
    .active-gateway-row select{
      padding:8px 12px;border:1px solid #CBD5E1;border-radius:8px;
      font-size:13px;font-family:inherit;color:#134E4A;background:#fff;
    }

    .status-row{display:flex;align-items:center;gap:12px;flex-wrap:wrap;margin-bottom:16px}
    .status-hint{color:#64748B;font-size:13px}

    .intro{color:#64748B;font-size:13px;line-height:1.65;margin:0 0 24px}

    .form-grid{display:grid;grid-template-columns:1fr 1fr;gap:20px}
    .field{display:flex;flex-direction:column;min-width:0}
    .field.wide{grid-column:1/-1}

    /* flex, not block, so the "saved" pill can sit beside the label text */
    .field label{
      display:flex;align-items:center;gap:8px;flex-wrap:wrap;
      font-weight:600;font-size:13px;color:#134E4A;margin-bottom:6px;
    }
    .field .saved{
      font-weight:600;font-size:11px;color:#166534;background:#DCFCE7;
      padding:2px 8px;border-radius:999px;letter-spacing:.2px;
    }
    .field input,.field select{
      width:100%;box-sizing:border-box;padding:10px 14px;
      border:1px solid #CBD5E1;border-radius:8px;
      font-size:14px;font-family:inherit;color:#134E4A;background:#fff;
    }
    .field input:focus,.field select:focus{
      outline:none;border-color:#0D9488;box-shadow:0 0 0 3px rgba(13,148,136,.12);
    }
    .field input::placeholder{color:#94A3B8}
    .field small{margin-top:6px;font-size:12px;color:#94A3B8;line-height:1.5}

    .webhook-panel{
      margin-top:24px;background:#F0FDFA;border:1px solid #5EEAD4;
      border-radius:12px;padding:16px 18px;
    }
    .webhook-title{font-weight:700;font-size:13px;color:#134E4A;margin-bottom:6px}
    .webhook-panel p{margin:0;font-size:13px;color:#134E4A;line-height:1.6}
    .webhook-row{display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin-top:12px}
    .webhook-row code{
      flex:1;min-width:260px;background:#fff;border:1px solid #5EEAD4;border-radius:8px;
      padding:9px 12px;font-size:12px;color:#134E4A;
      overflow-wrap:anywhere;
    }
    .webhook-row .btn{padding:8px 16px;font-size:12px;white-space:nowrap}

    .actions{display:flex;justify-content:flex-end;margin-top:24px}
    .actions .btn{min-width:160px}

    .alert{margin-top:16px;padding:12px 14px;border-radius:8px;font-size:14px}
    .alert-error{background:#FEE2E2;color:#991B1B}
    .alert-ok{background:#DCFCE7;color:#166534}

    @media(max-width:720px){
      .form-grid{grid-template-columns:1fr}
      .page-head{flex-direction:column;align-items:flex-start}
      .actions .btn{width:100%}
    }
  `]
})
export class PaymentSettingsComponent implements OnInit {
  private api = inject(ApiService);

  config: ConfigView | null = null;
  saving = false;
  saved = false;
  copied = false;
  error = '';

  activeTab: 'RAZORPAY' | OtherGateway = 'RAZORPAY';
  activeGateway: 'RAZORPAY' | OtherGateway = 'RAZORPAY';
  activeGatewaySaved = false;
  gatewayConfig: Record<OtherGateway, GatewayConfigView | null> | null = null;

  // Rupees in the form, paise on the wire — the backend stores the smallest unit.
  form: any = {
    razorpayKeyId: '',
    razorpayKeySecret: '',
    razorpayWebhookSecret: '',
    amountRupees: 0,
    paymentEnabled: false
  };

  otherForms: Record<OtherGateway, any> = {
    PAYU: { key: '', salt: '', mode: 'TEST', amountRupees: 0, enabled: false },
    CASHFREE: { appId: '', secretKey: '', mode: 'TEST', amountRupees: 0, enabled: false }
  };

  get webhookUrl(): string {
    return `${window.location.origin}/api/payments/webhook`;
  }

  ngOnInit() {
    this.load();
    this.loadOtherGateways();
  }

  load() {
    this.api.get<ConfigView>('/api/org-razorpay-config').subscribe({
      next: (data) => {
        this.config = data;
        this.form.razorpayKeyId = data?.razorpayKeyId || '';
        this.form.amountRupees = (data?.amountPerStudent || 0) / 100;
        this.form.paymentEnabled = !!data?.paymentEnabled;
        // Secrets are never echoed back, so the inputs stay empty and a blank
        // submission is understood by the API as "keep what you have".
        this.form.razorpayKeySecret = '';
        this.form.razorpayWebhookSecret = '';
      },
      error: (err) => {
        console.error('Failed to load payment settings', err);
        this.error = 'Could not load your payment settings.';
      }
    });
  }

  save() {
    this.saving = true;
    this.saved = false;
    this.error = '';

    const payload = {
      razorpayKeyId: this.form.razorpayKeyId?.trim() || null,
      razorpayKeySecret: this.form.razorpayKeySecret?.trim() || null,
      razorpayWebhookSecret: this.form.razorpayWebhookSecret?.trim() || null,
      amountPerStudent: Math.round(Number(this.form.amountRupees || 0) * 100),
      paymentEnabled: !!this.form.paymentEnabled
    };

    this.api.put<ConfigView>('/api/org-razorpay-config', payload).subscribe({
      next: (data) => {
        this.saving = false;
        this.saved = true;
        this.config = data;
        this.form.razorpayKeySecret = '';
        this.form.razorpayWebhookSecret = '';
        setTimeout(() => this.saved = false, 4000);
      },
      error: (err) => {
        this.saving = false;
        this.error = err.error?.error || 'Could not save the settings.';
      }
    });
  }

  loadOtherGateways() {
    this.api.get<any>('/api/org-payment-gateway-config').subscribe({
      next: (data) => {
        this.gatewayConfig = { PAYU: data?.PAYU || null, CASHFREE: data?.CASHFREE || null };
        this.activeGateway = data?.activeGateway || 'RAZORPAY';

        const payu = data?.PAYU;
        this.otherForms.PAYU.enabled = !!payu?.enabled;
        this.otherForms.PAYU.amountRupees = (payu?.amountPerStudent || 0) / 100;

        const cashfree = data?.CASHFREE;
        this.otherForms.CASHFREE.enabled = !!cashfree?.enabled;
        this.otherForms.CASHFREE.amountRupees = (cashfree?.amountPerStudent || 0) / 100;
      },
      error: (err) => console.error('Failed to load payment gateway settings', err)
    });
  }

  saveOther(gateway: OtherGateway) {
    this.saving = true;
    this.saved = false;
    this.error = '';

    const form = this.otherForms[gateway];
    const credentials = gateway === 'PAYU'
      ? { key: form.key?.trim() || null, salt: form.salt?.trim() || null, mode: form.mode }
      : { appId: form.appId?.trim() || null, secretKey: form.secretKey?.trim() || null, mode: form.mode };

    const payload = {
      credentials,
      amountPerStudent: Math.round(Number(form.amountRupees || 0) * 100),
      enabled: !!form.enabled
    };

    this.api.put<any>(`/api/org-payment-gateway-config/${gateway}`, payload).subscribe({
      next: (data) => {
        this.saving = false;
        this.saved = true;
        this.gatewayConfig = { PAYU: data?.PAYU || null, CASHFREE: data?.CASHFREE || null };
        if (gateway === 'PAYU') { this.otherForms.PAYU.salt = ''; }
        if (gateway === 'CASHFREE') { this.otherForms.CASHFREE.secretKey = ''; }
        setTimeout(() => this.saved = false, 4000);
      },
      error: (err) => {
        this.saving = false;
        this.error = err.error?.error || 'Could not save the settings.';
      }
    });
  }

  saveActiveGateway(gateway: string) {
    this.api.put<any>('/api/org-payment-gateway-config/active-gateway', { activeGateway: gateway }).subscribe({
      next: () => {
        this.activeGatewaySaved = true;
        setTimeout(() => this.activeGatewaySaved = false, 3000);
      },
      error: (err) => {
        this.error = err.error?.error || 'Could not update the active gateway.';
      }
    });
  }

  copyWebhook() {
    navigator.clipboard?.writeText(this.webhookUrl).then(() => {
      this.copied = true;
      setTimeout(() => this.copied = false, 2000);
    }).catch(() => {});
  }
}
