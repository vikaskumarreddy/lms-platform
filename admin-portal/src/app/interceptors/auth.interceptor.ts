import { HttpInterceptorFn } from '@angular/common/http';

/**
 * 1. Attaches the JWT access token from localStorage to every outgoing request.
 * 2. Sends the tenant slug as the X-Tenant-Slug header so the backend
 *    TenantInterceptor can resolve the correct organization even when the SPA
 *    calls the API at a fixed dev origin (localhost:8080) where the Host header
 *    alone cannot reveal the tenant.
 */
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const token = localStorage.getItem('access_token');
  const tenantSlug = deriveTenantSlug();

  const cloned = req.clone({
    headers: req.headers
      .set('X-Tenant-Slug', tenantSlug)
      .set('Authorization', token ? `Bearer ${token}` : ''),
  });

  return next(cloned);
};

/**
 * Resolves the tenant slug the user explicitly entered on the login page
 * (persisted in localStorage — see login.component.ts). Guessing the tenant from
 * the browser hostname is not viable on local dev, where every host resolves to
 * localhost/127.0.0.1/an IP regardless of which organization is being tested —
 * a hardcoded 'axisora' default there made every local login/session silently
 * target the same organization no matter which one the tester intended.
 * Falls back to the real subdomain in production deployments where one exists,
 * and finally to 'axisora' only when nothing else is available.
 */
function deriveTenantSlug(): string {
  const stored = localStorage.getItem('tenant_slug');
  if (stored) {
    return stored;
  }
  const hostname = window.location.hostname;
  if (hostname === 'localhost' || hostname === '127.0.0.1' || /^\d+\.\d+\.\d+\.\d+$/.test(hostname)) {
    return 'axisora';
  }
  const firstPart = hostname.split('.')[0];
  return firstPart && firstPart !== 'localhost' ? firstPart : 'axisora';
}
