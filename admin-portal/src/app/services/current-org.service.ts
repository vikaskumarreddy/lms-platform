import { Injectable, inject, signal } from '@angular/core';
import { ApiService } from './api.service';

export interface CurrentOrg {
  id?: number;
  name?: string;
  category?: string;
  [key: string]: any;
}

/**
 * Single shared fetch of the current tenant organization, used by the admin
 * layout (sidebar name + category-aware menu) and any page that would
 * otherwise duplicate the same `/api/organizations/current` call.
 */
@Injectable({ providedIn: 'root' })
export class CurrentOrgService {
  private api = inject(ApiService);
  private loaded = false;

  readonly org = signal<CurrentOrg | null>(null);
  readonly category = signal<string>('OTHER');

  load() {
    if (this.loaded) return;
    this.loaded = true;
    this.api.get<CurrentOrg>('/api/organizations/current').subscribe({
      next: (org) => {
        if (org) {
          this.org.set(org);
          this.category.set(org.category || 'OTHER');
        }
      },
      error: () => {}
    });
  }
}
