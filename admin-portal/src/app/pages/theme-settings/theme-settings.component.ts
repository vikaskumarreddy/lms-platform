import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';
import { ThemeService, ThemeColors, DEFAULT_THEME, THEME_FIELD_GROUPS } from '../../services/theme.service';

@Component({
  selector: 'app-theme-settings',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './theme-settings.component.html',
  styleUrls: ['./theme-settings.component.css']
})
export class ThemeSettingsComponent implements OnInit {
  private api = inject(ApiService);
  private themeService = inject(ThemeService);

  readonly groups = THEME_FIELD_GROUPS;

  orgId: number | null = null;
  orgName = '';
  /** Live-editable copy the color pickers are bound to; the preview reads straight from this. */
  form: ThemeColors = { ...DEFAULT_THEME };
  /** What is currently saved on the server, used to detect unsaved changes and for Cancel. */
  private saved: ThemeColors = { ...DEFAULT_THEME };

  loading = true;
  saving = false;
  successMessage = '';
  errorMessage = '';

  ngOnInit() {
    this.api.get<any>('/api/organizations/current').subscribe({
      next: (org) => {
        this.orgId = org?.id ?? null;
        this.orgName = org?.name || '';
        const theme = { ...DEFAULT_THEME, ...(org?.theme || {}) };
        this.form = { ...theme };
        this.saved = { ...theme };
        this.loading = false;
      },
      error: () => {
        this.loading = false;
        this.errorMessage = 'Could not load the current organization.';
      }
    });
  }

  get hasChanges(): boolean {
    return this.groups.some(g => g.fields.some(f => this.form[f.key] !== this.saved[f.key]));
  }

  /** Applies the in-progress form values to the whole app immediately, live-previewing every page. */
  previewLive() {
    this.themeService.apply(this.form);
  }

  resetToDefaults() {
    this.form = { ...DEFAULT_THEME };
    this.previewLive();
  }

  cancel() {
    this.form = { ...this.saved };
    this.themeService.apply(this.saved);
  }

  save() {
    if (!this.orgId) return;
    this.saving = true;
    this.successMessage = '';
    this.errorMessage = '';
    this.api.put<any>(`/api/organizations/${this.orgId}/theme`, this.form).subscribe({
      next: (org) => {
        this.saving = false;
        this.saved = { ...this.form };
        this.themeService.apply(this.form);
        this.successMessage = 'Theme saved. It is already applied for you — log out and log back in (or ask other admins to refresh) to see it everywhere the next time you sign in.';
        setTimeout(() => (this.successMessage = ''), 8000);
      },
      error: (err) => {
        this.saving = false;
        this.errorMessage = err.error?.message || 'Failed to save the theme. Please try again.';
      }
    });
  }
}
