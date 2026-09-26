import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  template: `
    <div class="login-wrapper">
      <div class="login-card">
        <div class="login-header">
          <h1>{{ portalTitle }}</h1>
          <p>Sign in to manage your application</p>
        </div>
        <form (ngSubmit)="onSubmit()" #loginForm="ngForm">
          <div class="form-group">
            <label>Organization</label>
            <input type="text" [(ngModel)]="orgSlug" name="orgSlug" [disabled]="isSubdomainLocked" required placeholder="axisora" />
            <p class="field-hint">{{ isSubdomainLocked ? 'Locked to this organization subdomain.' : "Your organization's slug. Saved on this browser." }}</p>
          </div>
          <div class="form-group">
            <label>Email</label>
            <input type="email" [(ngModel)]="email" name="email" required placeholder="admin@axisora.com" />
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
    .login-wrapper{display:flex;align-items:center;justify-content:center;height:100vh;background:var(--bg);}
    .login-card{background:var(--surface);border-radius:16px;padding:40px;box-shadow:0 4px 20px rgba(0,0,0,.1);width:100%;max-width:400px;}
    .login-header{text-align:center;margin-bottom:28px;}
    .login-header h1{font-size:24px;font-weight:700;color:var(--primary);}
    .login-header p{color:var(--text-secondary);font-size:14px;margin-top:4px;}
    .form-group{margin-bottom:20px;}
    .form-group label{display:block;font-size:13px;font-weight:600;color:var(--text);margin-bottom:6px;}
    .form-group input{width:100%;padding:12px 14px;border:1px solid var(--border);border-radius:8px;font-size:15px;font-family:inherit;transition:border-color .2s;}
    .form-group input:focus{outline:none;border-color:var(--secondary);box-shadow:0 0 0 3px rgba(234,179,8,0.2);}
    .field-hint{font-size:12px;color:var(--text-secondary);margin:6px 0 0;}
    .error-msg{color:#EF4444;font-size:13px;text-align:center;margin-top:12px;}
    .register-link{text-align:center;font-size:13px;color:var(--text-secondary);margin:16px 0 0}.register-link a{color:var(--primary);font-weight:700;text-decoration:none}
  `]
})
export class LoginComponent {
  email = '';
  password = '';
  orgSlug = '';
  isSubdomainLocked = false;
  portalTitle = 'Admin Portal';
  loading = false;
  errorMsg = '';

  constructor(private auth: AuthService, private router: Router) {
    this.initTenant();
  }

  private initTenant() {
    const hostname = window.location.hostname;
    if (hostname && hostname !== 'localhost' && hostname !== '127.0.0.1' && !/^\d+\.\d+\.\d+\.\d+$/.test(hostname)) {
      const parts = hostname.split('.');
      if (parts.length >= 3) {
        const sub = parts[0].toLowerCase();
        if (sub === 'admin' || sub === 'www') {
          this.orgSlug = 'axisora';
          this.portalTitle = 'Axisora Platform Admin';
          this.email = 'admin@axisora.com';
          this.password = 'admin123';
        } else {
          this.orgSlug = sub;
          this.isSubdomainLocked = true;
          this.portalTitle = sub.charAt(0).toUpperCase() + sub.slice(1) + ' Portal';
        }
        localStorage.setItem('tenant_slug', this.orgSlug);
        return;
      }
    }

    // Local dev or bare host fallback
    this.orgSlug = localStorage.getItem('tenant_slug') || 'axisora';
    if (this.orgSlug === 'axisora') {
      this.email = 'admin@axisora.com';
      this.password = 'admin123';
    }
  }

  onSubmit() {
    this.loading = true;
    this.errorMsg = '';
    const slug = (this.orgSlug || 'axisora').trim().toLowerCase();
    localStorage.setItem('tenant_slug', slug);
    // Remove stale tokens before authenticating anew
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
