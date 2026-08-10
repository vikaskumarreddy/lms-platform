import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="login-wrapper">
      <div class="login-card">
        <div class="login-header">
          <h1>Axisora Admin</h1>
          <p>Sign in to manage your application</p>
        </div>
        <form (ngSubmit)="onSubmit()" #loginForm="ngForm">
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
    .error-msg{color:#EF4444;font-size:13px;text-align:center;margin-top:12px;}
  `]
})
export class LoginComponent {
  email = 'admin@axisora.com';
  password = 'admin123';
  loading = false;
  errorMsg = '';

  constructor(private auth: AuthService, private router: Router) {}

  onSubmit() {
    this.loading = true;
    this.errorMsg = '';
    this.auth.login(this.email, this.password).subscribe({
      next: () => this.router.navigate(['/']),
      error: (err) => {
        this.errorMsg = err.error?.message || 'Invalid email or password';
        this.loading = false;
      },
    });
  }
}
