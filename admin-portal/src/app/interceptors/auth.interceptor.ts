import { HttpInterceptorFn } from '@angular/common/http';

/**
 * Attaches the JWT access token from localStorage to every outgoing
 * HTTP request so the backend can authenticate admin requests.
 */
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const token = localStorage.getItem('access_token');
  if (token) {
    const cloned = req.clone({
      headers: req.headers.set('Authorization', `Bearer ${token}`),
    });
    return next(cloned);
  }
  return next(req);
};
