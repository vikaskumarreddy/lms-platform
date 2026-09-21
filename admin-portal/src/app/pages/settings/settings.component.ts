import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';

interface SystemConfigItem {
  id: number;
  configKey: string;
  configValue: string;
  category: string;
  description?: string;
  isSecret?: boolean;
}

/** One channel's vendor config, read back with secrets masked to a last-4-chars hint. */
interface MessagingChannelView {
  configured: boolean;
  enabled: boolean;
  vendor: string | null;
  credentialHints: Record<string, string | null>;
}

interface MessagingChannelDef {
  channel: 'SMS' | 'WHATSAPP';
  label: string;
  icon: string;
  fields: { key: string; label: string; placeholder: string }[];
}

/** Mirrors backend OrgFeatureSettings — one boolean per notification category / visibility flag. */
interface OrgFeatureSettingsView {
  notifyPlacements: boolean;
  notifyExams: boolean;
  notifyAssignments: boolean;
  notifyGrading: boolean;
  notifyClasses: boolean;
  notifyCertificates: boolean;
  attendanceNotificationsEnabled: boolean;
  parentAttendanceVisible: boolean;
  parentGradingVisible: boolean;
  parentFeePaymentsVisible: boolean;
}

interface FeatureToggleDef {
  key: keyof OrgFeatureSettingsView;
  label: string;
}

@Component({
  selector: 'app-settings',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="page-head">
      <div>
        <h1>Settings</h1>
        <p class="intro">
          Manage credentials and environment configuration (Firebase, Razorpay, JWT, etc.) without
          redeploying the backend or mobile app.
        </p>
      </div>
      <button class="btn btn-secondary" *ngIf="categories.length > 1" (click)="toggleAll()">
        {{ allOpen ? 'Collapse all' : 'Expand all' }}
      </button>
    </div>

    <div class="alert alert-ok" *ngIf="successMessage">{{ successMessage }}</div>

    <div class="accordion">
      <section class="panel" *ngFor="let category of categories" [class.open]="isOpen(category)">
        <!-- A button, not a div, so the section is reachable by keyboard and screen readers. -->
        <button type="button" class="panel-head" (click)="toggle(category)"
                [attr.aria-expanded]="isOpen(category)">
          <span class="chevron" [class.rotated]="isOpen(category)">›</span>
          <span class="panel-icon">{{ categoryIcon(category) }}</span>
          <span class="panel-title">{{ categoryLabel(category) }}</span>

          <span class="spacer"></span>

          <!-- Collapsed sections still have to answer "is this configured?", otherwise
               hiding them just buries the thing the admin came here to check. -->
          <span class="pill"
                [class.pill-done]="filledCount(category) === totalCount(category)"
                [class.pill-partial]="filledCount(category) > 0 && filledCount(category) < totalCount(category)"
                [class.pill-empty]="filledCount(category) === 0">
            {{ filledCount(category) }}/{{ totalCount(category) }} set
          </span>
          <span class="pill pill-secret" *ngIf="secretCount(category) > 0">
            🔒 {{ secretCount(category) }}
          </span>
        </button>

        <div class="panel-body" *ngIf="isOpen(category)">
          <div class="field" *ngFor="let cfg of configsByCategory(category)">
            <label [attr.for]="'cfg-' + cfg.id">
              {{ cfg.description || cfg.configKey }}
              <span class="secret-tag" *ngIf="cfg.isSecret">🔒 secret</span>
            </label>

            <div class="input-row" *ngIf="!isLongField(cfg)">
              <input
                [id]="'cfg-' + cfg.id"
                [type]="cfg.isSecret && !revealed[cfg.id] ? 'password' : 'text'"
                [(ngModel)]="cfg.configValue"
                [name]="'cfg-' + cfg.id"
                [placeholder]="cfg.configKey">
              <button *ngIf="cfg.isSecret" type="button" class="btn btn-secondary reveal"
                      (click)="revealed[cfg.id] = !revealed[cfg.id]">
                {{ revealed[cfg.id] ? 'Hide' : 'Show' }}
              </button>
            </div>

            <textarea *ngIf="isLongField(cfg)"
              [id]="'cfg-' + cfg.id"
              [(ngModel)]="cfg.configValue"
              [name]="'cfg-' + cfg.id"
              [placeholder]="cfg.configKey === 'firebase.serviceAccountJson' ? 'Paste the full Firebase service-account JSON here...' : cfg.configKey"
              rows="6"></textarea>

            <small class="key-hint">{{ cfg.configKey }}</small>
          </div>

          <div class="alert alert-error" *ngIf="errorByCategory[category]">
            {{ errorByCategory[category] }}
          </div>

          <div class="panel-actions">
            <button class="btn btn-primary" [disabled]="savingCategory === category"
                    (click)="saveCategory(category)">
              {{ savingCategory === category ? 'Saving…' : 'Save ' + categoryLabel(category) }}
            </button>
          </div>
        </div>
      </section>

      <div class="card empty" *ngIf="loaded && categories.length === 0">
        No configuration entries found.
      </div>
    </div>

    <div class="messaging-section">
      <h2 class="section-title">💬 Messaging (SMS / WhatsApp)</h2>
      <p class="intro">
        Configure a vendor per channel to notify parents/students by SMS or WhatsApp — e.g. daily-attendance
        absentee alerts — instead of (or alongside) app push notifications.
      </p>

      <div class="accordion">
        <section class="panel" *ngFor="let def of messagingChannelDefs" [class.open]="isMessagingOpen(def.channel)">
          <button type="button" class="panel-head" (click)="toggleMessaging(def.channel)"
                  [attr.aria-expanded]="isMessagingOpen(def.channel)">
            <span class="chevron" [class.rotated]="isMessagingOpen(def.channel)">›</span>
            <span class="panel-icon">{{def.icon}}</span>
            <span class="panel-title">{{def.label}}</span>

            <span class="spacer"></span>

            <span class="pill" [class.pill-done]="messagingConfig[def.channel]?.configured"
                  [class.pill-empty]="!messagingConfig[def.channel]?.configured">
              {{messagingConfig[def.channel]?.configured ? 'Configured' : 'Not set up'}}
            </span>
            <span class="pill" [class.pill-done]="messagingConfig[def.channel]?.enabled"
                  [class.pill-empty]="!messagingConfig[def.channel]?.enabled">
              {{messagingConfig[def.channel]?.enabled ? 'Enabled' : 'Disabled'}}
            </span>
          </button>

          <div class="panel-body" *ngIf="isMessagingOpen(def.channel)">
            <div class="field">
              <label>Vendor</label>
              <select [(ngModel)]="messagingForm[def.channel].vendor" [name]="'vendor-' + def.channel">
                <option value="TWILIO">Twilio</option>
              </select>
            </div>

            <div class="field" *ngFor="let f of def.fields">
              <label>
                {{f.label}}
                <span class="secret-tag" *ngIf="messagingConfig[def.channel]?.credentialHints?.[f.key]">
                  🔒 saved · {{messagingConfig[def.channel].credentialHints[f.key]}}
                </span>
              </label>
              <input type="password"
                     [(ngModel)]="messagingForm[def.channel].credentials[f.key]"
                     [name]="f.key + '-' + def.channel"
                     autocomplete="new-password"
                     [placeholder]="messagingConfig[def.channel]?.credentialHints?.[f.key] ? 'Leave blank to keep the saved value' : f.placeholder">
            </div>

            <div class="field">
              <label>Status</label>
              <select [(ngModel)]="messagingForm[def.channel].enabled" [name]="'enabled-' + def.channel">
                <option [ngValue]="false">Off</option>
                <option [ngValue]="true">On</option>
              </select>
            </div>

            <div class="alert alert-error" *ngIf="messagingErrorByChannel[def.channel]">
              {{messagingErrorByChannel[def.channel]}}
            </div>

            <div class="panel-actions">
              <button class="btn btn-primary" [disabled]="savingMessagingChannel === def.channel"
                      (click)="saveMessagingChannel(def)">
                {{savingMessagingChannel === def.channel ? 'Saving…' : 'Save ' + def.label}}
              </button>
            </div>
          </div>
        </section>
      </div>
    </div>

    <div class="messaging-section" *ngIf="featureSettingsLoaded">
      <h2 class="section-title">🔔 Notifications &amp; Parent Visibility</h2>
      <p class="intro">
        Turn push-notification categories on or off for this organization's students, control the
        daily-attendance absentee alert, and set what a future parent view is allowed to show.
      </p>

      <div class="toggle-card">
        <h3 class="toggle-group-title">Push notification categories</h3>
        <label class="toggle-row" *ngFor="let t of notificationToggleDefs">
          <span>{{t.label}}</span>
          <input type="checkbox" [(ngModel)]="featureSettings[t.key]" [name]="t.key">
        </label>

        <h3 class="toggle-group-title">Daily attendance</h3>
        <label class="toggle-row">
          <span>Notify parent when a student is marked absent</span>
          <input type="checkbox" [(ngModel)]="featureSettings.attendanceNotificationsEnabled" name="attendanceNotificationsEnabled">
        </label>

        <h3 class="toggle-group-title">Parent visibility</h3>
        <label class="toggle-row" *ngFor="let t of visibilityToggleDefs">
          <span>{{t.label}}</span>
          <input type="checkbox" [(ngModel)]="featureSettings[t.key]" [name]="t.key">
        </label>

        <div class="alert alert-error" *ngIf="featureSettingsError">{{featureSettingsError}}</div>

        <div class="panel-actions">
          <button class="btn btn-primary" [disabled]="savingFeatureSettings" (click)="saveFeatureSettings()">
            {{savingFeatureSettings ? 'Saving…' : 'Save Notification Settings'}}
          </button>
        </div>
      </div>
    </div>
  `,
  // The design system scopes its label/input rules to `.modal-overlay fieldset`, so a
  // routed page has to supply its own form styling rather than inherit it.
  styles: [`
    .page-head{display:flex;justify-content:space-between;align-items:flex-start;gap:24px;margin-bottom:24px}
    .page-head h1{font-size:24px;font-weight:700;margin:0 0 8px}
    .intro{color:var(--text-secondary);margin:0;max-width:640px;line-height:1.6}

    .accordion{display:flex;flex-direction:column;gap:12px;max-width:860px}

    .panel{background:var(--surface);color:var(--text);border:1px solid var(--border-light);border-radius:14px;overflow:hidden}
    .panel.open{border-color:var(--border);box-shadow:0 1px 3px rgba(13,148,136,.08)}

    .panel-head{
      width:100%;display:flex;align-items:center;gap:12px;
      padding:16px 18px;background:transparent;border:0;cursor:pointer;
      font-family:inherit;font-size:15px;text-align:left;color:var(--text);
    }
    .panel-head:hover{background:var(--surface-alt)}
    .panel.open .panel-head{background:var(--bg)}

    .chevron{
      display:inline-block;font-size:20px;line-height:1;color:var(--primary);
      transition:transform .18s ease;transform:rotate(0deg);
    }
    .chevron.rotated{transform:rotate(90deg)}

    .panel-icon{font-size:16px}
    .panel-title{font-weight:700}
    .spacer{flex:1}

    .pill{font-size:11px;font-weight:700;padding:3px 9px;border-radius:999px;white-space:nowrap}
    .pill-done{background:#DCFCE7;color:#166534}
    .pill-partial{background:#FEF3C7;color:#92400E}
    .pill-empty{background:#F1F5F9;color:#64748B}
    .pill-secret{background:#FEF3C7;color:#92400E}

    .panel-body{padding:4px 18px 18px;display:flex;flex-direction:column;gap:18px;border-top:1px solid var(--border-light)}

    .field{display:flex;flex-direction:column}
    .field label{
      display:flex;align-items:center;gap:8px;flex-wrap:wrap;
      font-weight:600;font-size:13px;color:var(--text);margin-bottom:6px;
    }
    .secret-tag{font-size:11px;font-weight:600;color:var(--warning-text)}

    .input-row{display:flex;gap:8px;align-items:stretch}
    .field input,.field textarea,.field select{
      flex:1;width:100%;box-sizing:border-box;padding:10px 14px;
      border:1px solid var(--border-light);border-radius:8px;
      font-size:14px;font-family:inherit;color:var(--text);background:var(--surface);
    }
    .field textarea{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:12px;resize:vertical}
    .field input:focus,.field textarea:focus,.field select:focus{
      outline:none;border-color:var(--primary);box-shadow:0 0 0 3px rgba(13,148,136,.12);
    }
    .field input::placeholder,.field textarea::placeholder{color:var(--text-muted)}
    .reveal{padding:0 14px;white-space:nowrap}

    .key-hint{margin-top:6px;font-size:11px;color:#94A3B8;font-family:ui-monospace,SFMono-Regular,Menlo,monospace}

    .panel-actions{display:flex;justify-content:flex-end}
    .panel-actions .btn{min-width:180px}

    .alert{padding:12px 14px;border-radius:8px;font-size:14px}
    .alert-ok{background:#DCFCE7;color:#166534;margin-bottom:16px;max-width:860px}
    .alert-error{background:#FEE2E2;color:#991B1B}

    .empty{color:#64748B;text-align:center;padding:32px}

    .messaging-section{max-width:860px;margin-top:32px}
    .section-title{font-size:18px;font-weight:700;margin:0 0 8px;color:var(--text)}

    .toggle-card{background:var(--surface);color:var(--text);border:1px solid var(--border-light);border-radius:14px;padding:18px;display:flex;flex-direction:column;gap:4px}
    .toggle-group-title{font-size:13px;font-weight:700;color:var(--primary);margin:14px 0 4px;text-transform:uppercase;letter-spacing:.04em}
    .toggle-group-title:first-child{margin-top:0}
    .toggle-row{display:flex;justify-content:space-between;align-items:center;gap:12px;padding:8px 0;border-bottom:1px solid var(--border-light);font-size:14px;color:var(--text)}
    .toggle-row:last-of-type{border-bottom:0}
    .toggle-row input[type="checkbox"]{width:18px;height:18px;flex-shrink:0}

    @media(max-width:720px){
      .page-head{flex-direction:column}
      .panel-head{flex-wrap:wrap}
      .panel-actions .btn{width:100%}
    }
  `]
})
export class SettingsComponent implements OnInit {
  configs: SystemConfigItem[] = [];
  categories: string[] = [];
  loaded = false;
  successMessage = '';
  revealed: Record<number, boolean> = {};

  /** Which category is mid-save, so one section saving doesn't disable the others. */
  savingCategory: string | null = null;
  errorByCategory: Record<string, string> = {};

  /** Sections start closed; the header pills carry enough to decide what to open. */
  private openCategories = new Set<string>();

  messagingChannelDefs: MessagingChannelDef[] = [
    {
      channel: 'SMS', label: 'SMS', icon: '📱',
      fields: [
        { key: 'accountSid', label: 'Account SID', placeholder: 'ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' },
        { key: 'authToken', label: 'Auth Token', placeholder: 'Your Twilio auth token' },
        { key: 'fromNumber', label: 'From Number', placeholder: '+1XXXXXXXXXX' }
      ]
    },
    {
      channel: 'WHATSAPP', label: 'WhatsApp', icon: '💬',
      fields: [
        { key: 'accountSid', label: 'Account SID', placeholder: 'ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' },
        { key: 'authToken', label: 'Auth Token', placeholder: 'Your Twilio auth token' },
        { key: 'fromWhatsAppNumber', label: 'From WhatsApp Number', placeholder: '+1XXXXXXXXXX' }
      ]
    }
  ];
  messagingConfig: Record<string, MessagingChannelView> = {};
  messagingForm: Record<string, { vendor: string; enabled: boolean; credentials: Record<string, string> }> = {
    SMS: { vendor: 'TWILIO', enabled: false, credentials: {} },
    WHATSAPP: { vendor: 'TWILIO', enabled: false, credentials: {} }
  };
  savingMessagingChannel: string | null = null;
  messagingErrorByChannel: Record<string, string> = {};
  private openMessagingChannels = new Set<string>();

  notificationToggleDefs: FeatureToggleDef[] = [
    { key: 'notifyPlacements', label: 'Placements' },
    { key: 'notifyExams', label: 'Exams' },
    { key: 'notifyAssignments', label: 'Assignments' },
    { key: 'notifyGrading', label: 'Grading' },
    { key: 'notifyClasses', label: 'Classes / Events' },
    { key: 'notifyCertificates', label: 'Certificates' }
  ];
  visibilityToggleDefs: FeatureToggleDef[] = [
    { key: 'parentAttendanceVisible', label: 'Attendance' },
    { key: 'parentGradingVisible', label: 'Grading' },
    { key: 'parentFeePaymentsVisible', label: 'Fee payments' }
  ];
  featureSettings: OrgFeatureSettingsView = {
    notifyPlacements: true, notifyExams: true, notifyAssignments: true,
    notifyGrading: true, notifyClasses: true, notifyCertificates: true,
    attendanceNotificationsEnabled: false,
    parentAttendanceVisible: true, parentGradingVisible: true, parentFeePaymentsVisible: true
  };
  featureSettingsLoaded = false;
  savingFeatureSettings = false;
  featureSettingsError = '';

  constructor(private apiService: ApiService) {}

  ngOnInit() {
    this.loadConfigs();
    this.loadMessagingConfig();
    this.loadFeatureSettings();
  }

  loadFeatureSettings() {
    this.apiService.get<OrgFeatureSettingsView>('/api/org-feature-settings').subscribe({
      next: (data) => {
        this.featureSettings = { ...this.featureSettings, ...data };
        this.featureSettingsLoaded = true;
      },
      error: (err) => {
        console.error('Failed to load notification/visibility settings', err);
        this.featureSettingsLoaded = true;
      }
    });
  }

  saveFeatureSettings() {
    this.savingFeatureSettings = true;
    this.featureSettingsError = '';
    this.apiService.put<OrgFeatureSettingsView>('/api/org-feature-settings', this.featureSettings).subscribe({
      next: (data) => {
        this.featureSettings = { ...this.featureSettings, ...data };
        this.savingFeatureSettings = false;
      },
      error: (err) => {
        this.savingFeatureSettings = false;
        this.featureSettingsError = err?.error?.error || 'Failed to save notification settings.';
      }
    });
  }

  loadMessagingConfig() {
    this.apiService.get<Record<string, MessagingChannelView>>('/api/org-messaging-config').subscribe({
      next: (data) => {
        this.messagingConfig = data || {};
        for (const def of this.messagingChannelDefs) {
          const cfg = this.messagingConfig[def.channel];
          this.messagingForm[def.channel] = {
            vendor: cfg?.vendor || 'TWILIO',
            enabled: !!cfg?.enabled,
            credentials: {}
          };
        }
      },
      error: (err) => {
        console.error('Failed to load messaging config', err);
        this.messagingConfig = {};
      }
    });
  }

  isMessagingOpen(channel: string): boolean {
    return this.openMessagingChannels.has(channel);
  }

  toggleMessaging(channel: string) {
    if (this.openMessagingChannels.has(channel)) {
      this.openMessagingChannels.delete(channel);
    } else {
      this.openMessagingChannels.add(channel);
    }
  }

  saveMessagingChannel(def: MessagingChannelDef) {
    const form = this.messagingForm[def.channel];
    this.savingMessagingChannel = def.channel;
    this.messagingErrorByChannel[def.channel] = '';

    const payload = {
      vendor: form.vendor,
      enabled: form.enabled,
      credentials: form.credentials
    };

    this.apiService.put<Record<string, MessagingChannelView>>(`/api/org-messaging-config/${def.channel}`, payload).subscribe({
      next: (data) => {
        this.savingMessagingChannel = null;
        this.messagingConfig = data || {};
        this.messagingForm[def.channel] = { vendor: form.vendor, enabled: form.enabled, credentials: {} };
        this.successMessage = `${def.label} messaging settings saved successfully.`;
        setTimeout(() => (this.successMessage = ''), 3000);
      },
      error: (err) => {
        this.savingMessagingChannel = null;
        console.error('Failed to save messaging config', def.channel, err);
        this.messagingErrorByChannel[def.channel] = err.error?.error || 'Could not save the messaging settings.';
      }
    });
  }

  loadConfigs() {
    this.apiService.get<SystemConfigItem[]>('/api/system-config').subscribe({
      next: (data) => {
        this.configs = data || [];
        this.categories = [...new Set(this.configs.map(c => c.category))];
        // With a single section there is nothing to scan, so collapsing it is just
        // an extra click between the admin and the only thing on the page.
        if (this.categories.length === 1) this.openCategories.add(this.categories[0]);
        this.loaded = true;
      },
      error: (err) => {
        console.error('Failed to load system config', err);
        this.configs = [];
        this.categories = [];
        this.loaded = true;
      }
    });
  }

  isOpen(category: string): boolean {
    return this.openCategories.has(category);
  }

  toggle(category: string) {
    if (this.openCategories.has(category)) {
      this.openCategories.delete(category);
    } else {
      this.openCategories.add(category);
    }
  }

  get allOpen(): boolean {
    return this.categories.length > 0 && this.categories.every(c => this.openCategories.has(c));
  }

  toggleAll() {
    if (this.allOpen) {
      this.openCategories.clear();
    } else {
      this.categories.forEach(c => this.openCategories.add(c));
    }
  }

  configsByCategory(category: string): SystemConfigItem[] {
    return this.configs.filter(c => c.category === category);
  }

  totalCount(category: string): number {
    return this.configsByCategory(category).length;
  }

  /** How many entries actually hold a value — the "is this configured?" signal. */
  filledCount(category: string): number {
    return this.configsByCategory(category).filter(c => (c.configValue || '').trim().length > 0).length;
  }

  secretCount(category: string): number {
    return this.configsByCategory(category).filter(c => c.isSecret).length;
  }

  categoryIcon(category: string): string {
    const icons: Record<string, string> = {
      FIREBASE: '🔥',
      PAYMENTS: '💳',
      SECURITY: '🔐',
      PUSH_NOTIFICATIONS: '🔔',
      GENERAL: '⚙️'
    };
    return icons[category] || '📋';
  }

  categoryLabel(category: string): string {
    const labels: Record<string, string> = {
      FIREBASE: 'Firebase Configuration',
      PAYMENTS: 'Payment Settings (Razorpay)',
      SECURITY: 'Security (JWT)',
      PUSH_NOTIFICATIONS: 'Push Notifications',
      GENERAL: 'General'
    };
    return labels[category] || category;
  }

  isLongField(cfg: SystemConfigItem): boolean {
    return cfg.configKey === 'firebase.serviceAccountJson';
  }

  saveCategory(category: string) {
    const items = this.configsByCategory(category);
    if (items.length === 0) return;

    this.savingCategory = category;
    this.successMessage = '';
    this.errorByCategory[category] = '';

    let remaining = items.length;
    let failed = 0;

    // Each entry is its own PUT, so the section is only "saved" once every request
    // has come back. Counting failures separately means one bad key reports an error
    // instead of leaving the button stuck on "Saving…" forever.
    const settle = () => {
      remaining--;
      if (remaining > 0) return;
      this.savingCategory = null;
      if (failed > 0) {
        this.errorByCategory[category] =
          `${failed} of ${items.length} setting${failed === 1 ? '' : 's'} could not be saved. Please retry.`;
        return;
      }
      this.successMessage = `${this.categoryLabel(category)} saved successfully.`;
      setTimeout(() => (this.successMessage = ''), 3000);
    };

    items.forEach(cfg => {
      this.apiService.put(`/api/system-config/${cfg.id}`, { configValue: cfg.configValue }).subscribe({
        next: () => settle(),
        error: (err) => {
          console.error('Failed to save config', cfg.configKey, err);
          failed++;
          settle();
        }
      });
    });
  }
}
