import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';
import { ThemeService, ThemeColors, DEFAULT_THEME, THEME_FIELD_GROUPS } from '../../services/theme.service';

export interface FormFieldConfig {
  key: string;
  label: string;
  type: 'text' | 'email' | 'tel' | 'password' | 'plan' | 'select' | 'date';
  required: boolean;
  enabled: boolean;
  isPrebuilt: boolean;
  options?: string[]; // for select type and plan display
  planOptions?: any[]; // copied structured subscription plan details
  placeholder?: string;
  helpText?: string;
}

export interface SubscriptionPlan {
  id: number;
  name: string;
  price: number;
  period?: string;
  description?: string;
  features?: string;
  isPopular?: boolean;
  isActive?: boolean;
}

export const DEFAULT_REGISTRATION_FIELDS: FormFieldConfig[] = [
  { key: 'name', label: 'Full Name', type: 'text', required: true, enabled: true, isPrebuilt: true, placeholder: 'Enter full name' },
  { key: 'email', label: 'Email Address', type: 'email', required: true, enabled: true, isPrebuilt: true, placeholder: 'student@example.com' },
  { key: 'phone', label: 'Mobile Number', type: 'tel', required: true, enabled: true, isPrebuilt: true, placeholder: '+91 98765 43210' },
  { key: 'password', label: 'Password', type: 'password', required: true, enabled: true, isPrebuilt: true, placeholder: 'Create a strong password' },
  { key: 'planId', label: 'Subscription Plan', type: 'plan', required: true, enabled: true, isPrebuilt: true, placeholder: 'Select subscription plan' },
  { key: 'linkedin', label: 'LinkedIn Profile', type: 'text', required: false, enabled: false, isPrebuilt: true, placeholder: 'linkedin.com/in/username' },
  { key: 'github', label: 'GitHub Profile', type: 'text', required: false, enabled: false, isPrebuilt: true, placeholder: 'github.com/username' },
  { key: 'parentName', label: 'Parent / Guardian Name', type: 'text', required: false, enabled: false, isPrebuilt: true, placeholder: 'Parent name' },
  { key: 'parentPhone', label: 'Parent Phone Number', type: 'tel', required: false, enabled: false, isPrebuilt: true, placeholder: '+91 98765 43210' },
  { key: 'parentEmail', label: 'Parent Email Address', type: 'email', required: false, enabled: false, isPrebuilt: true, placeholder: 'parent@example.com' },
  { key: 'notifyMedium', label: 'Parent Notification Via', type: 'select', required: false, enabled: false, isPrebuilt: true, options: ['PUSH', 'SMS', 'WHATSAPP'] },
];

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

  activeTab: 'theme' | 'registration' = 'theme';

  orgId: number | null = null;
  orgName = '';
  /** Live-editable copy the color pickers are bound to; the preview reads straight from this. */
  form: ThemeColors = { ...DEFAULT_THEME };
  /** What is currently saved on the server, used to detect unsaved changes and for Cancel. */
  private saved: ThemeColors = { ...DEFAULT_THEME };

  // Registration fields configuration
  registrationFields: FormFieldConfig[] = JSON.parse(JSON.stringify(DEFAULT_REGISTRATION_FIELDS));
  savedRegistrationFields: FormFieldConfig[] = JSON.parse(JSON.stringify(DEFAULT_REGISTRATION_FIELDS));
  availablePlans: SubscriptionPlan[] = [];
  
  // Custom field modal / form
  showCustomFieldModal = false;
  newField: {
    label: string;
    key: string;
    type: 'text' | 'select' | 'date';
    required: boolean;
    optionsInput: string;
    placeholder: string;
  } = {
    label: '',
    key: '',
    type: 'text',
    required: false,
    optionsInput: '',
    placeholder: ''
  };

  loading = true;
  saving = false;
  savingFields = false;
  successMessage = '';
  errorMessage = '';

  ngOnInit() {
    this.loadSubscriptionPlans();
    this.api.get<any>('/api/organizations/current').subscribe({
      next: (org) => {
        this.orgId = org?.id ?? null;
        this.orgName = org?.name || '';
        const theme = { ...DEFAULT_THEME, ...(org?.theme || {}) };
        this.form = { ...theme };
        this.saved = { ...theme };

        // Load registration form config if present
        if (org?.settings) {
          try {
            const settingsObj = typeof org.settings === 'string' ? JSON.parse(org.settings) : org.settings;
            if (settingsObj?.registrationFormConfig?.fields && Array.isArray(settingsObj.registrationFormConfig.fields)) {
              this.registrationFields = settingsObj.registrationFormConfig.fields.map((f: FormFieldConfig) => {
                if (f.type === 'select' && f.options) {
                  f.options = this.filterCompositeOptions(f.options);
                }
                return f;
              });
              this.savedRegistrationFields = JSON.parse(JSON.stringify(this.registrationFields));
            }
          } catch (e) {
            console.error('Error parsing org settings:', e);
          }
        }

        this.syncPlanFieldOptions();
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

  get hasRegistrationChanges(): boolean {
    return JSON.stringify(this.registrationFields) !== JSON.stringify(this.savedRegistrationFields);
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
      next: () => {
        this.saving = false;
        this.saved = { ...this.form };
        this.themeService.apply(this.form);
        this.successMessage = 'Theme saved successfully.';
        setTimeout(() => (this.successMessage = ''), 8000);
      },
      error: (err) => {
        this.saving = false;
        this.errorMessage = err.error?.message || 'Failed to save the theme. Please try again.';
      }
    });
  }

  // --- Registration Fields Logic ---

  loadSubscriptionPlans() {
    this.api.get<SubscriptionPlan[]>('/api/subscription-plans').subscribe({
      next: (plans) => {
        this.availablePlans = (plans || []).filter(p => p.isActive !== false);
        this.syncPlanFieldOptions();
      },
      error: () => {
        this.api.get<SubscriptionPlan[]>('/api/subscription-plans/admin/all').subscribe({
          next: (plans) => {
            this.availablePlans = (plans || []).filter(p => p.isActive !== false);
            this.syncPlanFieldOptions();
          },
          error: () => {}
        });
      }
    });
  }

  syncPlanFieldOptions() {
    if (!this.availablePlans || this.availablePlans.length === 0) return;
    const planField = this.registrationFields.find(f => f.key === 'planId');
    if (planField) {
      planField.options = this.availablePlans.map(p =>
        `${p.name} — ₹${p.price}${p.period ? ' / ' + p.period : ''}`
      );
      planField.planOptions = this.availablePlans.map(p => ({
        id: p.id,
        name: p.name,
        price: p.price,
        period: p.period,
        description: p.description,
        features: p.features,
        isPopular: p.isPopular
      }));
    }
  }

  filterCompositeOptions(options: string[]): string[] {
    if (!options || options.length <= 1) return options || [];
    return options.filter(opt => {
      const words = opt.split(/\s+/).filter(Boolean);
      if (words.length > 1) {
        const otherOptions = options.filter(o => o !== opt);
        const allWordsInOthers = words.every(w =>
          otherOptions.some(o => o.toLowerCase() === w.toLowerCase())
        );
        if (allWordsInOthers) {
          // Extra concatenated option (e.g. "MTIET MITS SITAMS" when "MTIET", "MITS", "SITAMS" exist)
          return false;
        }
      }
      return true;
    });
  }

  sanitizeCustomOptions(input: string): string[] {
    if (!input || !input.trim()) return ['Option 1', 'Option 2'];
    const rawTokens = input
      .split(/[,\n]+/)
      .map(s => s.trim())
      .filter(Boolean);

    const distinct: string[] = [];
    for (const token of rawTokens) {
      if (!distinct.includes(token)) {
        distinct.push(token);
      }
    }

    return this.filterCompositeOptions(distinct);
  }

  moveField(index: number, direction: 'up' | 'down') {
    const targetIndex = direction === 'up' ? index - 1 : index + 1;
    if (targetIndex < 0 || targetIndex >= this.registrationFields.length) return;
    const temp = this.registrationFields[index];
    this.registrationFields[index] = this.registrationFields[targetIndex];
    this.registrationFields[targetIndex] = temp;
  }

  toggleField(field: FormFieldConfig) {
    if (this.isMandatoryPrebuilt(field)) return;
    field.enabled = !field.enabled;
  }

  isMandatoryPrebuilt(field: FormFieldConfig): boolean {
    return ['name', 'email', 'password', 'planId'].includes(field.key);
  }

  openAddCustomFieldModal() {
    this.newField = {
      label: '',
      key: '',
      type: 'text',
      required: false,
      optionsInput: '',
      placeholder: ''
    };
    this.showCustomFieldModal = true;
  }

  onCustomLabelChange() {
    if (!this.newField.key || this.newField.key.startsWith('custom_')) {
      const generated = this.newField.label
        .toLowerCase()
        .replace(/[^a-z0-9]/g, '_')
        .replace(/_+/g, '_')
        .replace(/^_|_$/g, '');
      this.newField.key = generated || 'custom_field';
    }
  }

  addCustomField() {
    if (!this.newField.label.trim()) return;
    let key = this.newField.key.trim();
    if (!key) {
      key = 'field_' + Date.now();
    }
    // Check if key already exists
    if (this.registrationFields.some(f => f.key === key)) {
      key = key + '_' + Math.floor(Math.random() * 1000);
    }

    const field: FormFieldConfig = {
      key: key,
      label: this.newField.label.trim(),
      type: this.newField.type,
      required: this.newField.required,
      enabled: true,
      isPrebuilt: false,
      placeholder: this.newField.placeholder.trim() || undefined
    };

    if (this.newField.type === 'select') {
      field.options = this.sanitizeCustomOptions(this.newField.optionsInput);
    }

    this.registrationFields.push(field);
    this.showCustomFieldModal = false;
  }

  removeField(field: FormFieldConfig) {
    if (field.isPrebuilt) return;
    this.registrationFields = this.registrationFields.filter(f => f !== field);
  }

  resetRegistrationFields() {
    this.registrationFields = JSON.parse(JSON.stringify(DEFAULT_REGISTRATION_FIELDS));
    this.syncPlanFieldOptions();
  }

  cancelRegistrationChanges() {
    this.registrationFields = JSON.parse(JSON.stringify(this.savedRegistrationFields));
    this.syncPlanFieldOptions();
  }

  saveRegistrationFields() {
    if (!this.orgId) return;
    this.savingFields = true;
    this.successMessage = '';
    this.errorMessage = '';

    // Always copy matching subscription plan details into planId field before saving
    this.syncPlanFieldOptions();

    // Clean any composite options from all select fields
    for (const f of this.registrationFields) {
      if (f.type === 'select' && f.options) {
        f.options = this.filterCompositeOptions(f.options);
      }
    }

    const payload = {
      fields: this.registrationFields
    };

    this.api.put<any>(`/api/organizations/${this.orgId}/registration-fields`, payload).subscribe({
      next: () => {
        this.savingFields = false;
        this.savedRegistrationFields = JSON.parse(JSON.stringify(this.registrationFields));
        this.successMessage = 'Registration page fields saved successfully. Your public registration page (/register) is now updated!';
        setTimeout(() => (this.successMessage = ''), 8000);
      },
      error: (err) => {
        this.savingFields = false;
        this.errorMessage = err.error?.message || 'Failed to save registration fields. Please try again.';
      }
    });
  }

  get enabledFieldsCount(): number {
    return this.registrationFields.filter(f => f.enabled).length;
  }
}
