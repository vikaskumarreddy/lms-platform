import { CommonModule } from '@angular/common';
import { Component, OnInit, OnDestroy, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { AuthService } from '../../services/auth.service';
import { ApiService } from '../../services/api.service';
import { ThemeService, ThemeColors } from '../../services/theme.service';
import { environment } from '../../../environments/environment';

interface SubscriptionPlan {
  id: number;
  name: string;
  description?: string;
  price: number;
  period?: string;
  features?: string;
  isPopular?: boolean;
  isActive?: boolean;
}

interface FormFieldConfig {
  key: string;
  label: string;
  type: 'text' | 'email' | 'tel' | 'password' | 'plan' | 'select' | 'date';
  required: boolean;
  enabled: boolean;
  isPrebuilt: boolean;
  options?: string[];
  placeholder?: string;
}

interface PublicOrgInfo {
  id: number;
  name: string;
  slug: string;
  logoUrl?: string;
  theme?: ThemeColors;
  settings?: any;
}

const DEFAULT_REGISTRATION_FIELDS: FormFieldConfig[] = [
  { key: 'name', label: 'Full Name', type: 'text', required: true, enabled: true, isPrebuilt: true, placeholder: 'Enter your full name' },
  { key: 'email', label: 'Email Address', type: 'email', required: true, enabled: true, isPrebuilt: true, placeholder: 'you@example.com' },
  { key: 'phone', label: 'Mobile Number', type: 'tel', required: true, enabled: true, isPrebuilt: true, placeholder: '+91 98765 43210' },
  { key: 'password', label: 'Password', type: 'password', required: true, enabled: true, isPrebuilt: true, placeholder: 'Create strong password' },
  { key: 'planId', label: 'Choose Subscription Plan', type: 'plan', required: true, enabled: true, isPrebuilt: true, placeholder: 'Select a plan' },
  { key: 'linkedin', label: 'LinkedIn Profile', type: 'text', required: false, enabled: false, isPrebuilt: true, placeholder: 'linkedin.com/in/username' },
  { key: 'github', label: 'GitHub Profile', type: 'text', required: false, enabled: false, isPrebuilt: true, placeholder: 'github.com/username' },
  { key: 'parentName', label: 'Parent / Guardian Name', type: 'text', required: false, enabled: false, isPrebuilt: true, placeholder: 'Parent or guardian name' },
  { key: 'parentPhone', label: 'Parent Phone Number', type: 'tel', required: false, enabled: false, isPrebuilt: true, placeholder: '+91 98765 43210' },
  { key: 'parentEmail', label: 'Parent Email', type: 'email', required: false, enabled: false, isPrebuilt: true, placeholder: 'parent@example.com' },
  { key: 'notifyMedium', label: 'Notify Parent Via', type: 'select', required: false, enabled: false, isPrebuilt: true, options: ['PUSH', 'SMS', 'WHATSAPP'] },
];

@Component({
  selector: 'app-register',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  template: `
    <main class="register-page" [style.--org-primary]="primaryColor" [style.--org-secondary]="secondaryColor">
      <!-- Left Intro Panel (dynamic org branding & theme) -->
      <section class="intro-panel">
        <a class="brand" routerLink="/login" [attr.aria-label]="orgName + ' login'">
          <div *ngIf="resolvedLogoUrl && !logoFailed" class="brand-logo-wrap">
            <img [src]="resolvedLogoUrl" [alt]="orgName" class="brand-logo" (error)="onLogoError()" />
          </div>
          <ng-container *ngIf="!resolvedLogoUrl || logoFailed">
            <span class="brand-mark">{{ orgInitial }}</span>
            <span class="brand-text">{{ orgName }}</span>
          </ng-container>
        </a>

        <p class="eyebrow">{{ orgTagline }}</p>
        <h1>Your learning<br />journey starts here</h1>
        <p class="intro-copy">{{ orgDescription }}</p>

        <div class="benefits">
          <div>
            <span class="benefit-icon p-badge">▶</span>
            <p><b>Expert-led courses</b><small>Structured lessons crafted for maximum retention and success.</small></p>
          </div>
          <div>
            <span class="benefit-icon g-badge">▣</span>
            <p><b>Interactive assessments</b><small>Test your knowledge and track your performance in real time.</small></p>
          </div>
          <div>
            <span class="benefit-icon o-badge">▥</span>
            <p><b>Progress & certification</b><small>Unlock achievements, track rank, and gain verifiable credentials.</small></p>
          </div>
          <div>
            <span class="benefit-icon v-badge">◉</span>
            <p><b>Anywhere, anytime access</b><small>Learn uninterrupted across both web and mobile experiences.</small></p>
          </div>
        </div>

        <small class="tagline">{{ orgTaglineFooter }}</small>
      </section>

      <!-- Right Form / Success Panel -->
      <section class="form-panel">
        <!-- ── STATE 1: Registration & Payment Checkout ── -->
        <div class="form-card" *ngIf="!paymentCompleted">
          <header>
            <h2>Create your account</h2>
            <p>Complete registration to enroll and unlock access immediately.</p>
          </header>

          <form #registrationForm="ngForm" (ngSubmit)="submit()" novalidate>
            <!-- Dynamic Fields configured in Admin Theme settings -->
            <ng-container *ngFor="let field of activeFields">
              
              <!-- 1. Full Name -->
              <label *ngIf="field.key === 'name'">
                {{ field.label }} <em *ngIf="field.required">*</em>
                <div class="input-wrap">
                  <span class="input-ico">♙</span>
                  <input name="name" [(ngModel)]="form.name" [required]="field.required" [placeholder]="field.placeholder || 'Enter your full name'" />
                </div>
              </label>

              <!-- 2. Email Address -->
              <label *ngIf="field.key === 'email'">
                {{ field.label }} <em *ngIf="field.required">*</em>
                <div class="input-wrap">
                  <span class="input-ico">✉</span>
                  <input type="email" name="email" [(ngModel)]="form.email" [required]="field.required" email [placeholder]="field.placeholder || 'you@example.com'" />
                </div>
              </label>

              <!-- 3. Phone Number -->
              <label *ngIf="field.key === 'phone'">
                {{ field.label }} <em *ngIf="field.required">*</em>
                <div class="input-wrap">
                  <span class="input-ico">⌕</span>
                  <input name="phone" [(ngModel)]="form.phone" [required]="field.required" [placeholder]="field.placeholder || '+91 98765 43210'" />
                </div>
              </label>

              <!-- 4. Password -->
              <label *ngIf="field.key === 'password'">
                {{ field.label }} <em *ngIf="field.required">*</em>
                <div class="input-wrap">
                  <span class="input-ico">▣</span>
                  <input [type]="showPassword ? 'text' : 'password'" name="password" [(ngModel)]="form.password" [required]="field.required" minlength="6" [placeholder]="field.placeholder || 'Create strong password'" />
                  <button type="button" class="eye" (click)="showPassword = !showPassword" [attr.aria-label]="showPassword ? 'Hide password' : 'Show password'">
                    {{ showPassword ? '◉' : '◎' }}
                  </button>
                </div>
              </label>

              <!-- 5. Subscription Plan Dropdown -->
              <label *ngIf="field.key === 'planId'">
                {{ field.label }} <em *ngIf="field.required">*</em>
                <select name="plan" [(ngModel)]="selectedPlanId" [required]="field.required" [disabled]="loadingPlans">
                  <option [ngValue]="null">{{ loadingPlans ? 'Loading available plans…' : 'Select a subscription plan' }}</option>
                  <option *ngFor="let plan of plans" [ngValue]="plan.id">
                    {{ plan.name }} — {{ plan.price | currency:'INR':'symbol':'1.0-0' }}{{ plan.period ? ' / ' + plan.period : '' }}
                  </option>
                </select>
              </label>

              <!-- 6. Pre-built Notify Medium dropdown -->
              <label *ngIf="field.isPrebuilt && field.key === 'notifyMedium'">
                {{ field.label }} <em *ngIf="field.required">*</em>
                <select [name]="field.key" [(ngModel)]="prebuiltValues[field.key]" [required]="field.required">
                  <option value="" disabled>Select parent notification channel</option>
                  <option value="PUSH">App Push Notification</option>
                  <option value="SMS">SMS</option>
                  <option value="WHATSAPP">WhatsApp</option>
                </select>
              </label>

              <!-- 7. Pre-built extra inputs (e.g. linkedin, github, parentName, parentPhone, parentEmail) -->
              <label *ngIf="field.isPrebuilt && !['name', 'email', 'phone', 'password', 'planId', 'notifyMedium'].includes(field.key)">
                {{ field.label }} <em *ngIf="field.required">*</em>
                <div class="input-wrap">
                  <input [type]="field.type === 'email' ? 'email' : (field.type === 'tel' ? 'tel' : 'text')"
                         [name]="field.key"
                         [(ngModel)]="prebuiltValues[field.key]"
                         [required]="field.required"
                         [placeholder]="field.placeholder || ('Enter ' + field.label)" />
                </div>
              </label>

              <!-- 8. Custom Field: Select / Dropdown -->
              <label *ngIf="!field.isPrebuilt && field.type === 'select'">
                {{ field.label }} <em *ngIf="field.required">*</em>
                <select [name]="'custom_' + field.key" [(ngModel)]="customFieldValues[field.key]" [required]="field.required">
                  <option value="" disabled>{{ field.placeholder || 'Select ' + field.label }}</option>
                  <option *ngFor="let opt of getCleanOptions(field.options)" [value]="opt">{{ opt }}</option>
                </select>
              </label>

              <!-- 9. Custom Field: Date Picker -->
              <label *ngIf="!field.isPrebuilt && field.type === 'date'">
                {{ field.label }} <em *ngIf="field.required">*</em>
                <div class="input-wrap">
                  <input type="date" [name]="'custom_' + field.key" [(ngModel)]="customFieldValues[field.key]" [required]="field.required" />
                </div>
              </label>

              <!-- 10. Custom Field: Text Input -->
              <label *ngIf="!field.isPrebuilt && field.type === 'text'">
                {{ field.label }} <em *ngIf="field.required">*</em>
                <div class="input-wrap">
                  <input type="text"
                         [name]="'custom_' + field.key"
                         [(ngModel)]="customFieldValues[field.key]"
                         [required]="field.required"
                         [placeholder]="field.placeholder || ('Enter ' + field.label)" />
                </div>
              </label>

            </ng-container>

            <!-- Selected Plan Summary Card -->
            <div class="plan-summary" *ngIf="selectedPlan as plan">
              <div class="plan-heading">
                <span class="crown">♛</span>
                <div>
                  <b>{{ plan.name }}</b>
                  <small>{{ plan.description || 'Full platform and course access' }}</small>
                </div>
                <strong>
                  {{ plan.price | currency:'INR':'symbol':'1.0-0' }}
                  <small *ngIf="plan.period">/ {{ plan.period }}</small>
                </strong>
              </div>
              <div class="features" *ngIf="plan.features">
                <span *ngFor="let feature of featureList(plan.features)">✓ {{ feature }}</span>
              </div>
            </div>

            <p class="error" *ngIf="errorMsg" role="alert">{{ errorMsg }}</p>

            <button class="register-btn" type="submit" [disabled]="loading || registrationForm.invalid || !selectedPlanId">
              <span *ngIf="!loading">Proceed to Pay ({{ selectedPlan?.price ? (selectedPlan!.price | currency:'INR':'symbol':'1.0-0') : 'Online' }})</span>
              <span *ngIf="loading" class="spinner-text">Setting up checkout…</span>
            </button>
          </form>

          <p class="login-link">Already have an account? <a routerLink="/login">Sign in</a></p>
        </div>

        <!-- ── STATE 2: Success Confirmation Screen ── -->
        <div class="form-card success-card" *ngIf="paymentCompleted">
          <div class="success-icon-wrap">
            <span class="success-checkmark">✓</span>
          </div>

          <h2>Registration Successful!</h2>
          <p class="success-subtitle">
            Welcome to <b>{{ orgName }}</b>! Your payment has been received and verified. Your student account is now fully active.
          </p>

          <div class="account-summary-box">
            <div class="summary-row">
              <span class="row-label">Student:</span>
              <span class="row-value">{{ form.name }}</span>
            </div>
            <div class="summary-row">
              <span class="row-label">Email:</span>
              <span class="row-value">{{ form.email }}</span>
            </div>
            <div class="summary-row" *ngIf="selectedPlan">
              <span class="row-label">Enrolled Plan:</span>
              <span class="row-value plan-badge">{{ selectedPlan.name }}</span>
            </div>
            <div class="summary-row">
              <span class="row-label">Status:</span>
              <span class="row-value status-badge">Active</span>
            </div>
          </div>

          <div class="action-options">
            <p class="options-title">How would you like to continue?</p>

            <!-- Option 1: Download Android App (Disabled / Coming Soon) -->
            <div class="option-btn-wrap">
              <button type="button" class="access-btn disabled-btn" disabled title="Android App is coming soon">
                <span class="btn-icon">📱</span>
                <div class="btn-text-block">
                  <span class="btn-main-text">Download Android App</span>
                  <span class="btn-sub-text">Native mobile experience</span>
                </div>
                <span class="coming-soon-pill">Coming Soon</span>
              </button>
            </div>

            <!-- Option 2: Continue in Web (Direct link to https://axisora.vercel.app) -->
            <div class="option-btn-wrap">
              <a href="https://axisora.vercel.app" class="access-btn web-btn" target="_blank" rel="noopener noreferrer">
                <span class="btn-icon">🌐</span>
                <div class="btn-text-block">
                  <span class="btn-main-text">Continue in Web</span>
                  <span class="btn-sub-text">Launch platform at axisora.vercel.app</span>
                </div>
                <span class="arrow-icon">→</span>
              </a>
            </div>
          </div>

          <p class="login-link">
            Prefer the standard portal? <a routerLink="/login">Go to Login</a>
          </p>
        </div>
      </section>
    </main>
  `,
  styles: [`
    :host {
      display: block;
      min-height: 100vh;
      --primary: var(--org-primary, #4F46E5);
      --secondary: var(--org-secondary, #2563EB);
    }
    .register-page {
      min-height: 100vh;
      display: grid;
      grid-template-columns: minmax(330px, 42%) 1fr;
      background: #f8fafc;
      color: #0f172a;
      font-family: Inter, system-ui, -apple-system, sans-serif;
    }
    .intro-panel {
      position: relative;
      overflow: hidden;
      padding: 46px 6vw 36px 5vw;
      background: linear-gradient(145deg, #ffffff, color-mix(in srgb, var(--primary) 8%, #f8fafc));
      border-right: 1px solid #e2e8f0;
      display: flex;
      flex-direction: column;
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 12px;
      color: #0f172a;
      text-decoration: none;
      font-size: 24px;
      font-weight: 800;
      letter-spacing: -0.02em;
    }
    .brand-logo-wrap {
      display: flex;
      align-items: center;
      max-height: 44px;
    }
    .brand-logo {
      height: 40px;
      max-width: 140px;
      object-fit: contain;
    }
    .brand-mark {
      display: grid;
      place-items: center;
      width: 42px;
      height: 42px;
      color: white;
      font-size: 24px;
      font-weight: 900;
      border-radius: 10px;
      background: linear-gradient(135deg, var(--primary), var(--secondary));
      box-shadow: 0 4px 12px color-mix(in srgb, var(--primary) 30%, transparent);
    }
    .eyebrow {
      margin: 18px 0 12px 0;
      font-size: 11px;
      font-weight: 800;
      letter-spacing: 0.14em;
      color: var(--primary);
    }
    .intro-panel h1 {
      font-size: 34px;
      font-weight: 900;
      line-height: 1.15;
      letter-spacing: -0.03em;
      margin: 0 0 14px 0;
      color: #0f172a;
    }
    .intro-copy {
      font-size: 13.5px;
      line-height: 1.55;
      color: #475569;
      margin: 0 0 24px 0;
      max-width: 440px;
    }
    .benefits {
      display: grid;
      gap: 16px;
      margin: 0 0 28px 0;
    }
    .benefits > div {
      display: flex;
      gap: 12px;
      align-items: flex-start;
    }
    .benefit-icon {
      flex-shrink: 0;
      width: 32px;
      height: 32px;
      border-radius: 8px;
      display: grid;
      place-items: center;
      font-size: 13px;
    }
    .p-badge { background: #ede9fe; color: #7c3aed; }
    .g-badge { background: #dcfce7; color: #16a34a; }
    .o-badge { background: #ffedd5; color: #ea580c; }
    .v-badge { background: #e0e7ff; color: #4338ca; }
    .benefits p {
      margin: 0;
      font-size: 13px;
      color: #1e293b;
      line-height: 1.35;
    }
    .benefits small {
      display: block;
      color: #64748b;
      font-size: 11.5px;
      margin-top: 2px;
    }
    .tagline {
      margin-top: auto;
      font-size: 11px;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      color: #94a3b8;
    }
    .form-panel {
      display: grid;
      place-items: center;
      padding: 36px 20px;
      overflow-y: auto;
    }
    .form-card {
      width: 100%;
      max-width: 490px;
      background: #ffffff;
      border: 1px solid #e2e8f0;
      border-radius: 18px;
      padding: 32px 30px;
      box-shadow: 0 10px 30px -10px rgba(0, 0, 0, 0.08);
    }
    header h2 {
      font-size: 22px;
      font-weight: 800;
      letter-spacing: -0.02em;
      margin: 0 0 6px 0;
    }
    header p {
      font-size: 13px;
      color: #64748b;
      margin: 0 0 20px 0;
    }
    form label {
      display: block;
      font-size: 11.5px;
      font-weight: 700;
      color: #334155;
      text-transform: uppercase;
      letter-spacing: 0.04em;
      margin: 0 0 14px 0;
    }
    form label em {
      color: #ef4444;
      font-style: normal;
    }
    .input-wrap {
      position: relative;
      margin-top: 6px;
    }
    .input-ico {
      position: absolute;
      left: 12px;
      top: 50%;
      transform: translateY(-50%);
      color: #94a3b8;
      font-size: 14px;
      pointer-events: none;
    }
    input, select {
      width: 100%;
      height: 42px;
      box-sizing: border-box;
      border: 1px solid #cbd5e1;
      border-radius: 8px;
      padding: 0 12px 0 36px;
      font-size: 13.5px;
      color: #0f172a;
      background: #ffffff;
      transition: border-color 0.15s;
    }
    select {
      padding-left: 12px;
      margin-top: 6px;
      appearance: auto;
    }
    input:focus, select:focus {
      outline: none;
      border-color: var(--primary);
    }
    .eye {
      position: absolute;
      right: 10px;
      top: 50%;
      transform: translateY(-50%);
      border: 0;
      background: transparent;
      cursor: pointer;
      color: #64748b;
      font-size: 15px;
    }
    .plan-summary {
      background: #f8fafc;
      border: 1px solid #e2e8f0;
      border-radius: 12px;
      padding: 14px;
      margin: 0 0 16px 0;
    }
    .plan-heading {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .crown {
      width: 32px;
      height: 32px;
      border-radius: 8px;
      display: grid;
      place-items: center;
      background: linear-gradient(135deg, var(--primary), var(--secondary));
      color: white;
      font-size: 14px;
      flex-shrink: 0;
    }
    .plan-heading > div { flex: 1; }
    .plan-heading b {
      display: block;
      font-size: 13.5px;
      color: #0f172a;
    }
    .plan-heading small {
      font-size: 11px;
      color: #64748b;
    }
    .plan-heading strong {
      font-size: 15px;
      color: var(--primary);
    }
    .plan-heading strong small {
      font-size: 11px;
      color: #64748b;
      font-weight: normal;
    }
    .features {
      margin-top: 10px;
      padding-top: 10px;
      border-top: 1px dashed #cbd5e1;
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 6px;
      font-size: 11.5px;
      color: #475569;
      background: #f8fafc;
    }
    .register-btn {
      width: 100%;
      height: 46px;
      border: 0;
      border-radius: 8px;
      color: #ffffff;
      font-size: 13.5px;
      font-weight: 700;
      cursor: pointer;
      background: linear-gradient(135deg, var(--primary), var(--secondary));
      box-shadow: 0 6px 18px color-mix(in srgb, var(--primary) 25%, transparent);
      transition: transform 0.1s, box-shadow 0.15s;
    }
    .register-btn:hover:not(:disabled) {
      transform: translateY(-1px);
      box-shadow: 0 8px 22px color-mix(in srgb, var(--primary) 35%, transparent);
    }
    .register-btn:disabled { opacity: 0.6; cursor: not-allowed; }
    .error {
      color: #b91c1c;
      background: #fef2f2;
      border: 1px solid #fecaca;
      border-radius: 8px;
      padding: 10px 12px;
      font-size: 12px;
      margin-bottom: 16px;
    }
    .login-link {
      text-align: center;
      margin: 22px 0 0;
      font-size: 12px;
      color: #64748b;
    }
    .login-link a {
      color: var(--primary);
      font-weight: 700;
      text-decoration: none;
    }
    /* ── Success Screen ── */
    .success-card {
      text-align: center;
    }
    .success-icon-wrap {
      width: 64px;
      height: 64px;
      border-radius: 50%;
      background: #dcfce7;
      border: 2px solid #86efac;
      display: grid;
      place-items: center;
      margin: 0 auto 16px;
    }
    .success-checkmark {
      font-size: 32px;
      color: #16a34a;
      font-weight: bold;
    }
    .success-card h2 {
      font-size: 24px;
      font-weight: 800;
      color: #0f172a;
      margin: 0 0 8px;
    }
    .success-subtitle {
      font-size: 13.5px;
      color: #475569;
      line-height: 1.5;
      margin: 0 0 24px;
    }
    .account-summary-box {
      background: #f8fafc;
      border: 1px solid #e2e8f0;
      border-radius: 12px;
      padding: 14px 18px;
      margin: 0 0 24px;
      text-align: left;
    }
    .summary-row {
      display: flex;
      justify-content: space-between;
      padding: 6px 0;
      font-size: 13px;
      border-bottom: 1px solid #f1f5f9;
    }
    .summary-row:last-child {
      border-bottom: none;
    }
    .row-label {
      color: #64748b;
      font-weight: 600;
    }
    .row-value {
      color: #0f172a;
      font-weight: 600;
    }
    .plan-badge {
      background: #ede9fe;
      color: #6d28d9;
      padding: 2px 8px;
      border-radius: 6px;
      font-size: 12px;
    }
    .status-badge {
      background: #dcfce7;
      color: #15803d;
      padding: 2px 8px;
      border-radius: 6px;
      font-size: 12px;
    }
    .action-options {
      display: flex;
      flex-direction: column;
      gap: 12px;
      margin-bottom: 16px;
    }
    .options-title {
      font-size: 13px;
      font-weight: 700;
      color: #334155;
      margin: 0 0 4px;
      text-align: left;
    }
    .option-btn-wrap {
      width: 100%;
    }
    .access-btn {
      width: 100%;
      display: flex;
      align-items: center;
      padding: 12px 16px;
      border-radius: 10px;
      text-decoration: none;
      box-sizing: border-box;
      transition: all 0.15s ease;
      cursor: pointer;
    }
    .btn-icon {
      font-size: 22px;
      margin-right: 12px;
    }
    .btn-text-block {
      display: flex;
      flex-direction: column;
      align-items: flex-start;
      flex: 1;
    }
    .btn-main-text {
      font-size: 13.5px;
      font-weight: 700;
    }
    .btn-sub-text {
      font-size: 11px;
      opacity: 0.8;
    }
    .web-btn {
      background: var(--primary);
      color: #ffffff;
      border: 1px solid var(--primary);
      box-shadow: 0 4px 14px color-mix(in srgb, var(--primary) 30%, transparent);
    }
    .web-btn:hover {
      transform: translateY(-1px);
      box-shadow: 0 6px 18px color-mix(in srgb, var(--primary) 40%, transparent);
    }
    .arrow-icon {
      font-size: 18px;
      font-weight: bold;
    }
    .disabled-btn {
      background: #f1f5f9;
      color: #94a3b8;
      border: 1px solid #e2e8f0;
      cursor: not-allowed;
    }
    .coming-soon-pill {
      font-size: 10px;
      font-weight: 700;
      background: #e2e8f0;
      color: #64748b;
      padding: 3px 8px;
      border-radius: 999px;
      text-transform: uppercase;
      letter-spacing: 0.04em;
    }
    @media (max-width: 850px) {
      .register-page { grid-template-columns: 1fr; }
      .intro-panel { padding: 30px 6vw; }
      .intro-panel h1 { font-size: 26px; }
      .benefits { grid-template-columns: 1fr 1fr; gap: 12px; }
      .form-panel { padding: 24px 16px; }
    }
    @media (max-width: 480px) {
      .benefits { grid-template-columns: 1fr; }
      .form-card { padding: 24px 20px; }
      .features { grid-template-columns: 1fr; }
    }
  `]
})
export class RegisterComponent implements OnInit, OnDestroy {
  private api = inject(ApiService);
  private auth = inject(AuthService);
  private router = inject(Router);
  private themeService = inject(ThemeService);

  org: PublicOrgInfo | null = null;
  orgName = 'Axisora';
  orgLogoUrl = '';
  logoFailed = false;
  orgInitial = 'A';
  orgTagline = 'LEARN · PRACTICE · GROW';
  orgDescription = 'Get access to premium courses, interactive assessments and personalised learning experiences designed for your success.';
  orgTaglineFooter = 'Better Learning  ·  Brighter Future';
  primaryColor = '#4F46E5';
  secondaryColor = '#2563EB';

  plans: SubscriptionPlan[] = [];
  selectedPlanId: number | null = null;
  loadingPlans = true;
  loading = false;
  showPassword = false;
  errorMsg = '';
  paymentCompleted = false;

  form = { name: '', email: '', phone: '', password: '' };
  prebuiltValues: Record<string, any> = {};
  customFieldValues: Record<string, any> = {};

  formFields: FormFieldConfig[] = JSON.parse(JSON.stringify(DEFAULT_REGISTRATION_FIELDS));

  private pollTimer: any = null;

  get resolvedLogoUrl(): string {
    if (!this.orgLogoUrl || this.logoFailed) return '';
    const trimmed = this.orgLogoUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://') || trimmed.startsWith('data:')) {
      return trimmed;
    }
    const backendOrigin = environment.apiUrl.replace(/\/api\/?$/, '');
    return backendOrigin + (trimmed.startsWith('/') ? '' : '/') + trimmed;
  }

  onLogoError() {
    this.logoFailed = true;
  }

  get activeFields(): FormFieldConfig[] {
    return this.formFields.filter(f => f.enabled);
  }

  ngOnInit() {
    this.loadOrgInfo();
    this.loadPlans();
  }

  ngOnDestroy() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer);
    }
  }

  private loadOrgInfo() {
    this.api.get<any>('/api/organizations/public-info').subscribe({
      next: (org) => {
        if (!org) return;
        this.org = org;
        this.orgName = org.name || 'Axisora';
        this.orgInitial = this.orgName.charAt(0).toUpperCase();
        this.orgLogoUrl = org.logoUrl || '';
        this.logoFailed = false;

        // 1. Direct subscription plans if returned in public-info
        if (org.subscriptionPlans && Array.isArray(org.subscriptionPlans) && org.subscriptionPlans.length > 0) {
          this.applyLoadedPlans(org.subscriptionPlans);
        }

        if (org.settings) {
          try {
            const settingsObj = typeof org.settings === 'string' ? JSON.parse(org.settings) : org.settings;
            if (settingsObj['tagline']) this.orgTagline = settingsObj['tagline'];
            if (settingsObj['description']) this.orgDescription = settingsObj['description'];
            if (settingsObj['footerTagline']) this.orgTaglineFooter = settingsObj['footerTagline'];

            if (settingsObj.registrationFormConfig?.fields && Array.isArray(settingsObj.registrationFormConfig.fields)) {
              this.formFields = settingsObj.registrationFormConfig.fields;

              // 2. Extract subscription plans copied into registration fields configuration!
              const planField = this.formFields.find(f => f.key === 'planId');
              if (planField && (planField as any).planOptions && (planField as any).planOptions.length > 0) {
                this.applyLoadedPlans((planField as any).planOptions);
              } else if (planField && planField.options && planField.options.length > 0 && this.plans.length === 0) {
                this.extractPlansFromFieldOptions(planField.options);
              }
            }
          } catch (e) {
            console.error('Error parsing org settings:', e);
          }
        }

        if (org.theme) {
          this.themeService.apply(org.theme);
          if (org.theme.primary) this.primaryColor = org.theme.primary;
          if (org.theme.secondary) this.secondaryColor = org.theme.secondary;
        }
      },
      error: () => {
        // Fallback to defaults gracefully
      }
    });
  }

  private applyLoadedPlans(plans: any[]) {
    const validPlans = (plans || []).filter((p: any) => p.isActive !== false);
    if (validPlans.length > 0) {
      this.plans = validPlans;
      this.loadingPlans = false;
      this.errorMsg = '';
      if (!this.selectedPlanId || !this.plans.some(p => p.id === this.selectedPlanId)) {
        const popular = this.plans.find((p) => p.isPopular);
        this.selectedPlanId = popular ? popular.id : this.plans[0].id;
      }
    }
  }

  private extractPlansFromFieldOptions(options: string[]) {
    const parsed: SubscriptionPlan[] = [];
    options.forEach((opt, idx) => {
      const match = opt.match(/(.*?)\s*—\s*₹?\s*([\d,]+)(?:\s*\/\s*(.*))?/);
      if (match) {
        const price = parseFloat(match[2].replace(/,/g, '')) || 0;
        parsed.push({
          id: idx + 1,
          name: match[1].trim(),
          price: price,
          period: match[3]?.trim()
        });
      } else {
        parsed.push({
          id: idx + 1,
          name: opt.trim(),
          price: 0
        });
      }
    });
    if (parsed.length > 0) {
      this.applyLoadedPlans(parsed);
    }
  }

  private loadPlans() {
    this.api.get<SubscriptionPlan[]>('/api/subscription-plans').subscribe({
      next: (plans) => {
        const active = (plans || []).filter((p) => p.isActive !== false);
        if (active.length > 0) {
          this.applyLoadedPlans(active);
        } else if (this.plans.length > 0) {
          this.loadingPlans = false;
        } else {
          this.loadingPlans = false;
        }
      },
      error: () => {
        this.loadingPlans = false;
        // Only show error if we haven't already loaded plans from registration field config
        if (this.plans.length === 0) {
          this.errorMsg = 'Unable to load subscription plans. Please try again later.';
        }
      }
    });
  }

  get selectedPlan(): SubscriptionPlan | undefined {
    return this.plans.find((p) => p.id === this.selectedPlanId);
  }

  featureList(features?: string): string[] {
    if (!features) return [];
    return features.split(/[,\n|]/).map((f) => f.trim()).filter(Boolean);
  }

  /**
   * Sanitizes dropdown options loaded from the org config:
   * - Splits any comma/newline-joined strings that were entered or stored.
   * - Deduplicates individual options.
   * - Filters out any composite option that is a space-separated combination
   *   of multiple other options (e.g. "MTIET MITS SITAMS" when "MTIET", "MITS",
   *   and "SITAMS" exist as separate options).
   */
  getCleanOptions(options?: string[]): string[] {
    if (!options || options.length === 0) return [];
    const cleaned: string[] = [];
    for (const opt of options) {
      const parts = opt.split(/[,\n]+/).map(s => s.trim()).filter(Boolean);
      for (const p of parts) {
        if (!cleaned.includes(p)) {
          cleaned.push(p);
        }
      }
    }
    // Remove composite/concatenated option that contains multiple other options
    return cleaned.filter(opt => {
      const words = opt.split(/\s+/).filter(Boolean);
      if (words.length > 1) {
        const others = cleaned.filter(o => o !== opt);
        const allWordsInOthers = words.every(w =>
          others.some(o => o.toLowerCase() === w.toLowerCase())
        );
        if (allWordsInOthers) {
          return false;
        }
      }
      return true;
    });
  }

  submit() {
    if (!this.selectedPlanId || this.loading) return;

    // Check mandatory fields
    for (const field of this.activeFields) {
      if (field.required) {
        if (field.key === 'name' && !this.form.name?.trim()) {
          this.errorMsg = `${field.label} is required.`;
          return;
        }
        if (field.key === 'email' && !this.form.email?.trim()) {
          this.errorMsg = `${field.label} is required.`;
          return;
        }
        if (field.key === 'password' && !this.form.password) {
          this.errorMsg = `${field.label} is required.`;
          return;
        }
        if (field.key === 'planId' && !this.selectedPlanId) {
          this.errorMsg = `${field.label} is required.`;
          return;
        }
        if (field.isPrebuilt && !['name', 'email', 'phone', 'password', 'planId'].includes(field.key)) {
          if (!this.prebuiltValues[field.key]) {
            this.errorMsg = `${field.label} is required.`;
            return;
          }
        }
        if (!field.isPrebuilt) {
          if (!this.customFieldValues[field.key]) {
            this.errorMsg = `${field.label} is required.`;
            return;
          }
        }
      }
    }

    this.loading = true;
    this.errorMsg = '';

    const customWithPlan = {
      ...this.customFieldValues,
      planId: this.selectedPlanId,
      planName: this.selectedPlan?.name || null
    };

    const payload: any = {
      name: this.form.name.trim(),
      email: this.form.email.trim(),
      phone: this.form.phone.trim(),
      password: this.form.password,
      planId: this.selectedPlanId,
      paymentMethod: 'ONLINE',
      linkedin: this.prebuiltValues['linkedin'] || null,
      github: this.prebuiltValues['github'] || null,
      parentName: this.prebuiltValues['parentName'] || null,
      parentPhone: this.prebuiltValues['parentPhone'] || null,
      parentEmail: this.prebuiltValues['parentEmail'] || null,
      notifyMedium: this.prebuiltValues['notifyMedium'] || null,
      customFields: customWithPlan
    };

    if (this.org?.id) {
      payload.organizationId = this.org.id;
    }

    this.auth.register(payload).subscribe({
      next: (authRes: any) => {
        if (authRes.accessToken) {
          localStorage.setItem('auth_token', authRes.accessToken);
        }
        const studentId = authRes.user?.id;
        if (authRes.paymentOrder) {
          this.launchCheckout(authRes.paymentOrder, studentId);
        } else if (studentId) {
          this.api.post<any>(`/api/payments/create-order/${studentId}`, {}).subscribe({
            next: (order) => this.launchCheckout(order, studentId),
            error: (err) => {
              this.loading = false;
              this.errorMsg = err.error?.message || err.error?.error || 'Account created, but payment order initialization failed.';
            }
          });
        } else {
          this.loading = false;
          this.paymentCompleted = true;
        }
      },
      error: (err) => {
        this.loading = false;
        this.errorMsg = err.error?.message || err.error?.error || 'Registration failed. Please check your details and try again.';
      }
    });
  }

  private launchCheckout(order: any, studentId: number) {
    const razorpayKey = order.keyId || order.razorpayKey;
    const orderId = order.orderId;
    const amount = order.amount;

    if (!razorpayKey || !orderId) {
      this.loading = false;
      this.errorMsg = 'Payment initialization response was incomplete. Please contact support.';
      return;
    }

    const script = document.createElement('script');
    script.src = 'https://checkout.razorpay.com/v1/checkout.js';
    script.onload = () => {
      const options = {
        key: razorpayKey,
        amount: amount,
        currency: 'INR',
        name: this.orgName || 'Axisora LMS',
        description: `Enrollment Fee: ${this.selectedPlan?.name || 'Student Access'}`,
        image: this.orgLogoUrl || undefined,
        order_id: orderId,
        handler: (response: any) => {
          this.verifyPayment(response, orderId);
        },
        prefill: {
          name: this.form.name,
          email: this.form.email,
          contact: this.form.phone
        },
        theme: {
          color: this.primaryColor || '#4F46E5'
        },
        modal: {
          ondismiss: () => {
            this.loading = false;
            this.errorMsg = 'Payment cancelled. You can retry when ready.';
          }
        }
      };

      const rzp = new (window as any).Razorpay(options);
      rzp.on('payment.failed', (response: any) => {
        this.loading = false;
        this.errorMsg = response.error?.description || 'Payment failed. Please try again or use another payment method.';
      });
      rzp.open();
    };
    script.onerror = () => {
      this.loading = false;
      this.errorMsg = 'Could not load payment checkout gateway. Please check your internet connection.';
    };
    document.body.appendChild(script);
  }

  private verifyPayment(rzpResponse: any, orderId: string) {
    this.pollPaymentStatus(orderId);
  }

  private pollPaymentStatus(orderId: string) {
    let attempts = 0;
    const maxAttempts = 15;

    this.pollTimer = setInterval(() => {
      attempts++;
      this.api.get<any>(`/api/payments/order-status/${orderId}`).subscribe({
        next: (statusRes) => {
          if (statusRes.paymentStatus === 'COMPLETED' || statusRes.status === 'COMPLETED' || statusRes.status === 'PAID') {
            clearInterval(this.pollTimer);
            this.loading = false;
            this.paymentCompleted = true;
          } else if (attempts >= maxAttempts) {
            clearInterval(this.pollTimer);
            this.loading = false;
            this.paymentCompleted = true;
          }
        },
        error: () => {
          if (attempts >= maxAttempts) {
            clearInterval(this.pollTimer);
            this.loading = false;
            this.paymentCompleted = true;
          }
        }
      });
    }, 2000);
  }
}
