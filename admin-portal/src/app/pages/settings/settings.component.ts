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

    <!-- AI Model & Intelligence Section -->
    <div class="messaging-section" style="margin-top:28px;">
      <h2 class="section-title">🤖 AI Model & Intelligence (Google Gemini)</h2>
      <p class="intro">
        Configure the generative AI engine for instant doubt resolution, MCQ auto-generation for faculty, and student daily challenges.
      </p>

      <div class="toggle-card" style="padding:20px;">
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-bottom:16px;">
          <div>
            <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px;">
              <label style="font-size:13px;font-weight:600;">AI Model</label>
              <button type="button" (click)="fetchAvailableModels()" [disabled]="fetchingModels"
                      style="background:none;border:none;font-size:11px;color:#4F46E5;cursor:pointer;font-weight:600;padding:0;">
                {{ fetchingModels ? 'Detecting models...' : '🔍 Auto-Detect Models' }}
              </button>
            </div>
            <select [(ngModel)]="aiConfig.modelName" (ngModelChange)="onModelSelectChange($event)" name="aiModelName"
                    style="width:100%;padding:10px 12px;border:1px solid #CBD5E1;border-radius:8px;font-size:14px;background:#FFF;">
              <option value="gemini-3.6-flash">Gemini 3.6 Flash (Recommended - Latest & Fast)</option>
              <option value="gemini-3.5-flash">Gemini 3.5 Flash (High Speed)</option>
              <option value="gemini-flash-latest">Gemini Flash Latest</option>
              <option *ngFor="let m of availableModels" [value]="m.id">{{ m.name }}</option>
              <option value="CUSTOM">Custom Model Name...</option>
            </select>
            <!-- Custom Model Input if selected -->
            <div *ngIf="useCustomModel" style="margin-top:8px;">
              <input type="text" [(ngModel)]="customModelInput" (ngModelChange)="onCustomModelChange($event)"
                     placeholder="Enter model name e.g. gemini-3.6-flash"
                     style="width:100%;padding:8px 12px;border:1px solid #6366F1;border-radius:6px;font-size:13px;box-sizing:border-box;">
            </div>
            <!-- Clickable chips if detected -->
            <div *ngIf="availableModels.length > 0" style="margin-top:8px;display:flex;flex-wrap:wrap;gap:6px;align-items:center;">
              <span style="font-size:11px;color:#64748B;">Detected:</span>
              <button type="button" *ngFor="let m of availableModels" (click)="selectModelChip(m.id)"
                      [style.background]="aiConfig.modelName === m.id ? '#4F46E5' : '#EEF2FF'"
                      [style.color]="aiConfig.modelName === m.id ? '#FFF' : '#4338CA'"
                      style="border:none;border-radius:12px;padding:3px 10px;font-size:11px;font-weight:600;cursor:pointer;">
                {{ m.id }}
              </button>
            </div>
          </div>
          <div>
            <label style="display:block;font-size:13px;font-weight:600;margin-bottom:6px;">Engine Status</label>
            <select [(ngModel)]="aiConfig.enabled" name="aiEnabled" style="width:100%;padding:10px 12px;border:1px solid #CBD5E1;border-radius:8px;font-size:14px;background:#FFF;">
              <option [ngValue]="true">🟢 Enabled (Active in mobile app &amp; admin portal)</option>
              <option [ngValue]="false">🔴 Disabled</option>
            </select>
          </div>
        </div>

        <div style="margin-bottom:16px;">
          <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px;">
            <label style="font-size:13px;font-weight:600;">
              Google Gemini API Key
              <span class="secret-tag" *ngIf="aiConfigMaskedKey" style="background:#EEF2FF;color:#4338CA;padding:2px 8px;border-radius:6px;font-size:11px;margin-left:8px;">
                🔒 Saved: {{ aiConfigMaskedKey }}
              </span>
            </label>
            <button type="button" (click)="showAiApiKey = !showAiApiKey" style="background:none;border:none;font-size:12px;color:#4F46E5;cursor:pointer;font-weight:600;">
              {{ showAiApiKey ? 'Hide Key' : 'Show Key' }}
            </button>
          </div>
          <input [type]="showAiApiKey ? 'text' : 'password'"
                 [(ngModel)]="aiConfig.apiKey"
                 name="aiApiKey"
                 style="width:100%;padding:10px 12px;border:1px solid #CBD5E1;border-radius:8px;font-size:14px;box-sizing:border-box;"
                 [placeholder]="aiConfigMaskedKey ? 'Leave blank to keep current saved key' : 'Paste AIzaSy... API key here'">
          <div style="font-size:12px;color:#64748B;margin-top:4px;">
            Obtain your API key from the <a href="https://aistudio.google.com" target="_blank" style="color:#4F46E5;text-decoration:underline;">Google AI Studio</a>.
          </div>
        </div>

        <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:16px;margin-bottom:16px;">
          <div>
            <label style="display:block;font-size:13px;font-weight:600;margin-bottom:6px;">Lesson AI Tutor Limit (questions/lesson)</label>
            <input type="number" [(ngModel)]="aiConfig.lessonAiQuestionLimit" name="aiLessonLimit" min="1" max="1000" style="width:100%;padding:10px 12px;border:1px solid #CBD5E1;border-radius:8px;font-size:14px;box-sizing:border-box;">
          </div>
          <div>
            <label style="display:block;font-size:13px;font-weight:600;margin-bottom:6px;">Daily Doubt Resolution Limit</label>
            <input type="number" [(ngModel)]="aiConfig.dailyQuestionLimit" name="aiDailyLimit" min="1" max="100" style="width:100%;padding:10px 12px;border:1px solid #CBD5E1;border-radius:8px;font-size:14px;box-sizing:border-box;">
          </div>
          <div>
            <label style="display:block;font-size:13px;font-weight:600;margin-bottom:6px;">Daily Challenges Allowed</label>
            <input type="number" [(ngModel)]="aiConfig.dailyChallengeLimit" name="aiChallengeLimit" min="1" max="10" style="width:100%;padding:10px 12px;border:1px solid #CBD5E1;border-radius:8px;font-size:14px;box-sizing:border-box;">
          </div>
        </div>

        <!-- Connection Test Result -->
        <div *ngIf="aiTestResult"
             [style.background]="aiTestResult.success ? '#ECFDF5' : '#FEF2F2'"
             [style.border-color]="aiTestResult.success ? '#10B981' : '#EF4444'"
             [style.color]="aiTestResult.success ? '#065F46' : '#991B1B'"
             style="border:1px solid;border-radius:8px;padding:12px 16px;font-size:13px;margin-bottom:16px;display:flex;align-items:center;gap:8px;">
          <span>{{ aiTestResult.success ? '✅' : '❌' }}</span>
          <span>{{ aiTestResult.message || aiTestResult.error }}</span>
        </div>

        <div *ngIf="aiSaveMessage" style="background:#ECFDF5;border:1px solid #10B981;border-radius:8px;padding:12px 16px;font-size:13px;color:#065F46;margin-bottom:16px;">
          ✅ {{ aiSaveMessage }}
        </div>

        <div style="display:flex;gap:12px;justify-content:flex-end;">
          <button type="button" class="btn btn-secondary" [disabled]="testingAiConnection" (click)="testAiConnection()">
            {{ testingAiConnection ? 'Testing...' : '⚡ Test Connection' }}
          </button>
          <button type="button" class="btn btn-primary" [disabled]="savingAiConfig" (click)="saveAiConfig()">
            {{ savingAiConfig ? 'Saving...' : 'Save AI Configuration' }}
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

  // AI Configuration properties
  aiConfig = {
    modelName: 'gemini-3.6-flash',
    apiKey: '',
    enabled: true,
    dailyQuestionLimit: 10,
    dailyChallengeLimit: 1,
    lessonAiQuestionLimit: 100
  };
  aiConfigMaskedKey: string | null = null;
  showAiApiKey = false;
  loadingAiConfig = false;
  testingAiConnection = false;
  savingAiConfig = false;
  fetchingModels = false;
  useCustomModel = false;
  customModelInput = '';
  availableModels: { id: string; name: string }[] = [];
  aiTestResult: { success: boolean; message?: string; error?: string; availableModels?: any[] } | null = null;
  aiSaveMessage = '';

  constructor(private apiService: ApiService) {}

  ngOnInit() {
    this.loadConfigs();
    this.loadMessagingConfig();
    this.loadFeatureSettings();
    this.loadAiConfig();
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

  loadAiConfig() {
    this.loadingAiConfig = true;
    this.apiService.get<any>('/api/ai/config').subscribe({
      next: (data) => {
        if (data) {
          const model = data.modelName || 'gemini-3.6-flash';
          this.aiConfig.modelName = model;
          const knownStandard = ['gemini-3.6-flash', 'gemini-3.5-flash', 'gemini-flash-latest', 'gemini-3.7-flash', 'gemini-3.8-flash'];
          if (!knownStandard.includes(model)) {
            this.useCustomModel = true;
            this.customModelInput = model;
          }
          this.aiConfig.enabled = data.enabled !== false;
          this.aiConfig.dailyQuestionLimit = data.dailyQuestionLimit || 10;
          this.aiConfig.dailyChallengeLimit = data.dailyChallengeLimit || 1;
          this.aiConfig.lessonAiQuestionLimit = data.lessonAiQuestionLimit || 100;
          if (data.isConfigured) {
            this.aiConfigMaskedKey = data.apiKeyHint || data.maskedApiKey;
          }
        }
        this.loadingAiConfig = false;
        this.fetchAvailableModels();
      },
      error: () => {
        this.loadingAiConfig = false;
      }
    });
  }

  fetchAvailableModels() {
    this.fetchingModels = true;
    const query = this.aiConfig.apiKey ? `?apiKey=${encodeURIComponent(this.aiConfig.apiKey)}` : '';
    this.apiService.get<any>(`/api/ai/models${query}`).subscribe({
      next: (res) => {
        this.fetchingModels = false;
        if (res && res.models && res.models.length > 0) {
          this.availableModels = res.models;
        }
      },
      error: () => {
        this.fetchingModels = false;
      }
    });
  }

  onModelSelectChange(val: string) {
    if (val === 'CUSTOM') {
      this.useCustomModel = true;
      this.customModelInput = this.aiConfig.modelName !== 'CUSTOM' ? this.aiConfig.modelName : '';
    } else {
      this.useCustomModel = false;
    }
  }

  onCustomModelChange(val: string) {
    if (val && val.trim()) {
      this.aiConfig.modelName = val.trim();
    }
  }

  selectModelChip(modelId: string) {
    this.aiConfig.modelName = modelId;
    this.useCustomModel = false;
  }

  testAiConnection() {
    this.testingAiConnection = true;
    this.aiTestResult = null;
    const modelToTest = this.useCustomModel && this.customModelInput.trim()
        ? this.customModelInput.trim()
        : this.aiConfig.modelName;

    this.apiService.post<any>('/api/ai/config/test', {
      modelName: modelToTest,
      apiKey: this.aiConfig.apiKey
    }).subscribe({
      next: (res) => {
        this.aiTestResult = res;
        if (res && res.availableModels && res.availableModels.length > 0) {
          this.availableModels = res.availableModels;
        }
        this.testingAiConnection = false;
      },
      error: (err) => {
        this.aiTestResult = {
          success: false,
          error: err?.error?.error || 'Connection failed. Please check your Gemini API key.'
        };
        this.testingAiConnection = false;
      }
    });
  }

  saveAiConfig() {
    this.savingAiConfig = true;
    this.aiSaveMessage = '';
    this.aiTestResult = null;
    if (this.useCustomModel && this.customModelInput.trim()) {
      this.aiConfig.modelName = this.customModelInput.trim();
    }
    this.apiService.post<any>('/api/ai/config', this.aiConfig).subscribe({
      next: (res) => {
        this.savingAiConfig = false;
        this.aiSaveMessage = 'AI configuration saved successfully!';
        if (res && (res.apiKeyHint || res.maskedApiKey)) {
          this.aiConfigMaskedKey = res.apiKeyHint || res.maskedApiKey;
          this.aiConfig.apiKey = '';
        }
        setTimeout(() => this.aiSaveMessage = '', 4000);
      },
      error: (err) => {
        this.savingAiConfig = false;
        this.aiTestResult = {
          success: false,
          error: err?.error?.message || 'Failed to save AI configuration'
        };
      }
    });
  }
}
