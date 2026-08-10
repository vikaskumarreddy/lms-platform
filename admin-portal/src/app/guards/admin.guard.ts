import { CanActivateFn, Router } from '@angular/router';
import { inject } from '@angular/core';
import { AuthService } from '../services/auth.service';

/**
 * Route guard: only allows access to admin routes when the user
 * is logged in AND has the ADMIN role.
 */
export const adminGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);

  if (auth.isLoggedIn() && auth.isAdmin) {
    return true;
  }

  router.navigate(['/login']);
  return false;
};
