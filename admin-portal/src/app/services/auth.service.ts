import { Injectable, inject } from '@angular/core';
import { Router } from '@angular/router';
import { HttpClient } from '@angular/common/http';
import { tap } from 'rxjs';

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
 * Handles admin authentication: login, token storage, logout, and role checks.
 */
@Injectable({ providedIn: 'root' })
export class AuthService {
  private http = inject(HttpClient);
  private router = inject(Router);

  login(email: string, password: string) {
    return this.http.post<LoginResponse>('http://localhost:8080/api/auth/login', { email, password }).pipe(
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
    return !!u && (u.roles?.includes('ADMIN') || u.role === 'ADMIN');
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
