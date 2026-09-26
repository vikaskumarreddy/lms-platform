import { Injectable, inject } from '@angular/core';
import { Router } from '@angular/router';
import { HttpClient } from '@angular/common/http';
import { tap } from 'rxjs';
import { environment } from '../../environments/environment';

export interface LoginResponse {
  accessToken: string;
  refreshToken: string;
  tokenType: string;
  expiresIn: number;
  user: {
    id: number;
    email: string;
    fullName: string;
    role: string;
    roles: string[];
  };
}

/**
 * The platform root domain (no subdomain). Tenant subdomains (e.g.
 * axisora.placements.com, manyasree.placements.com) resolve to individual
 * organizations; this bare domain is the platform admin entry point that shows
 * the dedicated platform menu (Organizations, Org Subscriptions, ...).
 */
const ROOT_DOMAIN = 'placements.com';

function isIpHost(hostname: string): boolean {
  return /^(\d{1,3}\.){3}\d{1,3}$/.test(hostname) || hostname === 'localhost' || hostname === '127.0.0.1';
}

/**
 * Handles admin authentication: login, token storage, logout, and role checks.
 */
@Injectable({ providedIn: 'root' })
export class AuthService {
  private http = inject(HttpClient);
  private router = inject(Router);

  /**
   * Mirrors ApiService.baseUrl: production uses window.location.origin so the
   * login request carries the correct tenant sub-domain as the Host header,
   * while local dev targets the backend's dev port.
   */
  private get baseUrl(): string {
    return environment.production ? window.location.origin : 'http://localhost:8080';
  }

  login(email: string, password: string) {
    return this.http.post<LoginResponse>(`${this.baseUrl}/api/auth/login`, { email, password }).pipe(
      tap(response => {
        localStorage.setItem('access_token', response.accessToken);
        localStorage.setItem('refresh_token', response.refreshToken);
        localStorage.setItem('user', JSON.stringify(response.user));
      })
    );
  }

  register(form: { name: string; email: string; password: string; phone: string }) {
    return this.http.post<LoginResponse>(`${this.baseUrl}/api/auth/register`, form).pipe(
      tap(response => {
        localStorage.setItem('access_token', response.accessToken);
        localStorage.setItem('refresh_token', response.refreshToken);
        localStorage.setItem('user', JSON.stringify(response.user));
      })
    );
  }

  get token(): string | null {
    return localStorage.getItem('access_token');
  }

  get user(): LoginResponse['user'] | null {
    const raw = localStorage.getItem('user');
    return raw ? JSON.parse(raw) : null;
  }

  get isAdmin(): boolean {
    const u = this.user;
    if (u && (u.roles?.includes('ADMIN') || u.role === 'ADMIN')) {
      return true;
    }
    // Robust fallback: decode the JWT's `role` claim and treat admin accordingly.
    // The access token is written to localStorage at the same moment as the user
    // object, so even if the stored `user` is stale/missing its role fields, an
    // ADMIN token still unlocks the admin-only menus. INSTITUTE_ADMIN tokens carry
    // "INSTITUTE_ADMIN" here, so org admins still do NOT see the admin-only menus.
    const role = this.jwtRoleClaim();
    return role === 'ADMIN';
  }

  /** True when the current user is an Instructor (role INSTRUCTOR). */
  get isInstructor(): boolean {
    const u = this.user;
    if (u && (u.roles?.includes('INSTRUCTOR') || u.role === 'INSTRUCTOR')) {
      return true;
    }
    const role = this.jwtRoleClaim();
    return role === 'INSTRUCTOR';
  }

  /** True when the current user is a tenant organization admin (role INSTITUTE_ADMIN). */
  get isInstituteAdmin(): boolean {
    const u = this.user;
    if (u && (u.roles?.includes('INSTITUTE_ADMIN') || u.role === 'INSTITUTE_ADMIN')) {
      return true;
    }
    const role = this.jwtRoleClaim();
    return role === 'INSTITUTE_ADMIN';
  }

  /** Decodes the `role` claim from the stored access token, or null. */
  private jwtRoleClaim(): string | null {
    const token = this.token;
    if (!token) return null;
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    try {
      const base64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
      const payload = JSON.parse(atob(base64));
      return (payload && typeof payload.role === 'string') ? payload.role : null;
    } catch {
      return null;
    }
  }

  /**
   * True when the browser is on the platform root domain (placements.com, or
   * localhost / a direct IP in dev), as opposed to a tenant subdomain
   * (e.g. axisora.placements.com). Used to render the dedicated platform admin
   * menu on the root domain vs the per-organization operational menu on tenants.
   */
  get isPlatformDomain(): boolean {
    const h = window.location.hostname;
    if (isIpHost(h)) {
      return true;
    }
    return h === ROOT_DOMAIN;
  }

  isLoggedIn(): boolean {
    return !!this.token && !!this.user;
  }

  logout() {
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    localStorage.removeItem('user');
    this.router.navigate(['/login']);
  }
}
