import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { HttpClient } from '@angular/common/http';
import { AuthService } from '../../services/auth.service';
import { ThemeService } from '../../services/theme.service';
import { environment } from '../../../environments/environment';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  template: `
    <div class="login-wrapper">
      <div class="login-card">
        <div class="login-header">
          <div class="brand-logo-container">
            <img *ngIf="orgLogoUrl" [src]="resolveLogoUrl(orgLogoUrl)" class="login-brand-logo" alt="Organization Logo" />
            <div *ngIf="!orgLogoUrl" class="brand-fallback-badge">
              <span>🎓</span>
            </div>
          </div>
          <h1 class="org-display-name">{{ isPlatform ? 'Axisora Platform' : (orgName || portalTitle) }}</h1>
          <div class="portal-badge-chip">{{ isPlatform ? '🛡️ Platform Admin' : '🏛️ Academy Admin' }}</div>
          <p class="sign-in-sub">{{ isPlatform ? 'Sign in to manage organizations & subscriptions' : 'Sign in to manage your institution' }}</p>
        </div>

        <form (ngSubmit)="onSubmit()" #loginForm="ngForm">
          <div class="form-group" *ngIf="!isPlatform">
            <label>Organization</label>
            <input
              type="text"
              [(ngModel)]="orgSlug"
              name="orgSlug"
              [disabled]="isSubdomainLocked"
              required
              placeholder="axisora"
              (blur)="fetchOrgInfo()"
            />
            <p class="field-hint">
              {{ isSubdomainLocked ? 'Locked to this organization subdomain.' : "Your organization's slug. Saved on this browser." }}
            </p>
          </div>
          <div class="form-group">
            <label>Email</label>
            <input type="email" [(ngModel)]="email" name="email" required placeholder="admin@domain.com" />
          </div>
          <div class="form-group">
            <label>Password</label>
            <input type="password" [(ngModel)]="password" name="password" required placeholder="••••••••" />
          </div>
          <button type="submit" class="btn btn-primary" style="width:100%;" [disabled]="loading">
            {{ loading ? 'Signing in...' : 'Sign In' }}
          </button>
          <p class="register-link">New learner? <a routerLink="/register">Create an account</a></p>
          <div *ngIf="errorMsg" class="error-msg">{{ errorMsg }}</div>
        </form>
      </div>
    </div>
  `,
  styles: [`
    .login-wrapper {
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      background: var(--bg, #F0FDFA);
      padding: 20px;
    }
    .login-card {
      background: var(--surface, #FFFFFF);
      border-radius: 20px;
      padding: 40px;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.08);
      width: 100%;
      max-width: 420px;
      border: 1px solid var(--border-light, #E2E8F0);
    }
    .login-header {
      text-align: center;
      margin-bottom: 24px;
      display: flex;
      flex-direction: column;
      align-items: center;
    }
    .brand-logo-container {
      margin-bottom: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .login-brand-logo {
      max-height: 64px;
      max-width: 180px;
      object-fit: contain;
      border-radius: 8px;
    }
    .brand-fallback-badge {
      width: 60px;
      height: 60px;
      border-radius: 50%;
      background: linear-gradient(135deg, var(--primary, #0D9488), var(--secondary, #2DD4BF));
      color: white;
      font-size: 28px;
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 4px 14px rgba(13, 148, 136, 0.25);
    }
    .org-display-name {
      font-size: 22px;
      font-weight: 700;
      color: var(--text, #134E4A);
      margin: 4px 0 6px;
      line-height: 1.25;
      text-align: center;
    }
    .portal-badge-chip {
      display: inline-block;
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.06em;
      background: rgba(13, 148, 136, 0.12);
      color: var(--primary, #0D9488);
      padding: 3px 10px;
      border-radius: 12px;
      margin-bottom: 6px;
    }
    .sign-in-sub {
      color: var(--text-secondary, #475569);
      font-size: 13px;
      margin: 0;
    }
    .form-group {
      margin-bottom: 18px;
    }
    .form-group label {
      display: block;
      font-size: 13px;
      font-weight: 600;
      color: var(--text, #134E4A);
      margin-bottom: 6px;
    }
    .form-group input {
      width: 100%;
      box-sizing: border-box;
      padding: 12px 14px;
      border: 1px solid var(--border, #5EEAD4);
      border-radius: 10px;
      font-size: 14px;
      font-family: inherit;
      background: var(--surface, #FFFFFF);
      color: var(--text, #134E4A);
      transition: all 0.2s;
    }
    .form-group input:focus {
      outline: none;
      border-color: var(--primary, #0D9488);
      box-shadow: 0 0 0 3px rgba(13, 148, 136, 0.18);
    }
    .form-group input:disabled {
      background: var(--surface-alt, #F8FAFA);
      color: var(--text-muted, #64748B);
      cursor: not-allowed;
    }
    .field-hint {
      font-size: 11px;
      color: var(--text-muted, #64748B);
      margin: 5px 0 0;
    }
    .btn-primary {
      background: var(--primary, #0D9488);
      color: white;
      border: none;
      border-radius: 10px;
      padding: 12px;
      font-size: 15px;
      font-weight: 600;
      cursor: pointer;
      transition: background 0.2s;
    }
    .btn-primary:hover:not(:disabled) {
      background: var(--primary-hover, #0C8A7E);
    }
    .btn-primary:disabled {
      opacity: 0.6;
      cursor: not-allowed;
    }
    .error-msg {
      color: #EF4444;
      font-size: 13px;
      text-align: center;
      margin-top: 12px;
    }
    .register-link {
      text-align: center;
      font-size: 13px;
      color: var(--text-secondary, #475569);
      margin: 16px 0 0;
    }
    .register-link a {
      color: var(--primary, #0D9488);
      font-weight: 700;
      text-decoration: none;
    }
  `]
})
export class LoginComponent implements OnInit {
  private auth = inject(AuthService);
  private router = inject(Router);
  private http = inject(HttpClient);
  private themeService = inject(ThemeService);

  email = '';
  password = '';
  orgSlug = '';
  orgName = '';
  orgLogoUrl = '';
  isSubdomainLocked = false;
  portalTitle = 'Axisora Platform';
  loading = false;
  errorMsg = '';

  get isPlatform(): boolean {
    return this.auth.isPlatformDomain;
  }

  private get apiUrl(): string {
    return environment.production ? window.location.origin : 'http://localhost:8080';
  }

  ngOnInit(): void {
    this.initTenant();
  }

  private initTenant(): void {
    const hostname = window.location.hostname;
    // Check URL query parameters first (e.g., ?tenant=manyasree)
    const searchParams = new URLSearchParams(window.location.search);
    const querySlug = searchParams.get('tenant') || searchParams.get('tenantSlug') || searchParams.get('slug');

    if (querySlug && querySlug.trim()) {
      this.orgSlug = querySlug.trim().toLowerCase();
      localStorage.setItem('tenant_slug', this.orgSlug);
      this.fetchOrgInfo();
      return;
    }

    // Platform Root Domain (axisoraforge.in, www.axisoraforge.in)
    if (this.isPlatform && hostname !== 'localhost' && hostname !== '127.0.0.1') {
      this.orgSlug = 'axisora';
      this.portalTitle = 'Axisora Platform';
      this.email = 'admin@axisora.com';
      this.password = 'admin123';
      this.isSubdomainLocked = true;
      localStorage.setItem('tenant_slug', 'axisora');
      this.fetchOrgInfo();
      return;
    }

    if (hostname && hostname !== 'localhost' && hostname !== '127.0.0.1' && !/^\d+\.\d+\.\d+\.\d+$/.test(hostname)) {
      const parts = hostname.split('.');
      if (parts.length >= 3) {
        let sub = parts[0].toLowerCase();
        if (sub.startsWith('app-') && sub.length > 4) {
          sub = sub.substring(4);
        }
        if (sub === 'admin' || sub === 'app') {
          this.orgSlug = 'axisora';
          this.portalTitle = 'Axisora Academy Admin';
          this.email = 'admin@axisora.com';
          this.password = 'admin123';
          this.isSubdomainLocked = true;
        } else {
          this.orgSlug = sub;
          this.isSubdomainLocked = true;
          this.portalTitle = sub.charAt(0).toUpperCase() + sub.slice(1) + ' Portal';
        }
        localStorage.setItem('tenant_slug', this.orgSlug);
        this.fetchOrgInfo();
        return;
      }
    }

    // Local dev or bare host fallback
    this.orgSlug = localStorage.getItem('tenant_slug') || 'axisora';
    if (this.orgSlug === 'axisora') {
      this.email = 'admin@axisora.com';
      this.password = 'admin123';
    }
    this.fetchOrgInfo();
  }

  fetchOrgInfo(): void {
    const slug = (this.orgSlug || 'axisora').trim().toLowerCase();
    this.http.get<any>(`${this.apiUrl}/api/organizations/public-info?slug=${slug}`).subscribe({
      next: (data) => {
        if (data) {
          if (data.name) this.orgName = data.name;
          if (data.logoUrl) this.orgLogoUrl = data.logoUrl;
          if (data.theme) this.themeService.apply(data.theme);
        }
      },
      error: () => {}
    });
  }

  resolveLogoUrl(url: string | null | undefined): string {
    if (!url) return '';
    if (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('data:')) {
      return url;
    }
    return `${this.apiUrl}${url.startsWith('/') ? '' : '/'}${url}`;
  }

  onSubmit(): void {
    this.loading = true;
    this.errorMsg = '';
    const slug = (this.orgSlug || 'axisora').trim().toLowerCase();
    localStorage.setItem('tenant_slug', slug);
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');

    this.auth.login(this.email, this.password).subscribe({
      next: () => {
        this.loading = false;
        this.router.navigate(['/']);
      },
      error: (err) => {
        this.errorMsg = err.error?.message || 'Invalid email or password';
        this.loading = false;
      },
    });
  }
}
