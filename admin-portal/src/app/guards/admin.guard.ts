import { CanActivateFn, Router } from '@angular/router';
import { inject } from '@angular/core';
import { AuthService } from '../services/auth.service';

/**
 * Route guard: allows access to admin routes when the user is logged in and has an
 * authorized admin-level role — the platform super admin (ADMIN) or a tenant
 * organization admin (INSTITUTE_ADMIN). The granular tenant/org authorization for the
 * actual data endpoints is enforced by the backend; this guard only opens the portal
 * layout for the two admin tiers.
 */
const ADMIN_ROLES = ['ADMIN', 'INSTITUTE_ADMIN'];

export const adminGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);

  const u = auth.user;
  const hasAdminRole = !!u && ADMIN_ROLES.some(r => (u.roles ?? []).includes(r) || u.role === r);

  if (auth.isLoggedIn() && hasAdminRole) {
    return true;
  }

  router.navigate(['/login']);
  return false;
};

/**
 * Super-admin-only guard: blocks everyone except the platform super admin (ADMIN role)
 * from routes exclusive to the platform owner \u2014 Organizations, Org Subscriptions.
 * Org admins (INSTITUTE_ADMIN) and faculty are redirected to the dashboard.
 */
export const adminOnlyGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);

  if (auth.isLoggedIn() && auth.isAdmin) {
    return true;
  }

  router.navigate(['/']);
  return false;
};