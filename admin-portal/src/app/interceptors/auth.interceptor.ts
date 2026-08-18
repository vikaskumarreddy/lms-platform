import { HttpInterceptorFn } from '@angular/common/http';

/**
 * 1. Attaches the JWT access token from localStorage to every outgoing request.
 * 2. Sends the tenant slug (derived from the browser hostname subdomain) as the
 *    X-Tenant-Slug header so the backend TenantInterceptor can resolve the
 *    correct organization even when the SPA calls the API at a fixed dev origin
 *    (localhost:8080) where the Host header alone cannot reveal the tenant.
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
 * Extracts the tenant slug from the browser hostname subdomain.
 * - "yogasree.placements.com"   -> "yogasree"
 * - "axisora.placements.com"    -> "axisora"
 * - "localhost:4200"            -> "axisora"  (default platform-admin org)
 */
function deriveTenantSlug(): string {
  const hostname = window.location.hostname;
  if (hostname === 'localhost' || hostname === '127.0.0.1' || /^\d+\.\d+\.\d+\.\d+$/.test(hostname)) {
    return 'axisora';
  }
  const firstPart = hostname.split('.')[0];
  return firstPart && firstPart !== 'localhost' ? firstPart : 'axisora';
}
