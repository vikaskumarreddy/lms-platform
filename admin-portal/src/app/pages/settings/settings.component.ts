import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';

interface SystemConfigItem {
  id: number;
  configKey: string;
  configValue: string;
  category: string;
  description?: string;
  isSecret?: boolean;
}

@Component({
  selector: 'app-settings',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <h1 style="font-size:24px;font-weight:700;margin-bottom:8px;">Settings</h1>
    <p style="color:#64748B;margin-bottom:24px;">
      Manage credentials and environment configuration (Firebase, Razorpay, JWT, etc.) without
      redeploying the backend or mobile app.
    </p>

    <div *ngIf="successMessage" style="margin-bottom:16px;padding:12px;background:#DCFCE7;color:#166534;border-radius:8px;font-size:14px;">
      {{ successMessage }}
    </div>

    <div class="grid-2">
      <div class="card" *ngFor="let category of categories">
        <h3 style="margin-bottom:16px;">{{ categoryLabel(category) }}</h3>
        <div style="display:flex;flex-direction:column;gap:14px;">
          <div *ngFor="let cfg of configsByCategory(category)">
            <label style="display:block;font-weight:600;margin-bottom:4px;font-size:13px;">
              {{ cfg.description || cfg.configKey }}
              <span *ngIf="cfg.isSecret" style="color:#B45309;font-size:11px;">🔒 secret</span>
            </label>
            <div style="display:flex;gap:8px;">
              <input
                [type]="cfg.isSecret && !revealed[cfg.id] ? 'password' : 'text'"
                [(ngModel)]="cfg.configValue"
                [placeholder]="cfg.configKey"
                style="flex:1;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
              <button *ngIf="cfg.isSecret" type="button" class="btn btn-secondary"
                      style="padding:0 12px;" (click)="revealed[cfg.id] = !revealed[cfg.id]">
                {{ revealed[cfg.id] ? 'Hide' : 'Show' }}
              </button>
            </div>
          </div>
          <button class="btn btn-primary" [disabled]="saving" (click)="saveCategory(category)">
            {{ saving ? 'Saving...' : 'Save ' + categoryLabel(category) }}
          </button>
        </div>
      </div>
    </div>
  `
})
export class SettingsComponent implements OnInit {
  configs: SystemConfigItem[] = [];
  categories: string[] = [];
  saving = false;
  successMessage = '';
  revealed: Record<number, boolean> = {};

  constructor(private apiService: ApiService) {}

  ngOnInit() {
    this.loadConfigs();
  }

  loadConfigs() {
    this.apiService.get<SystemConfigItem[]>('/api/system-config').subscribe({
      next: (data) => {
        this.configs = data;
        this.categories = [...new Set(data.map(c => c.category))];
      },
      error: (err) => {
        console.error('Failed to load system config', err);
        this.configs = [];
        this.categories = [];
      }
    });
  }

  configsByCategory(category: string): SystemConfigItem[] {
    return this.configs.filter(c => c.category === category);
  }

  categoryLabel(category: string): string {
    const labels: Record<string, string> = {
      FIREBASE: 'Firebase Configuration',
      PAYMENTS: 'Payment Settings (Razorpay)',
      SECURITY: 'Security (JWT)',
      GENERAL: 'General'
    };
    return labels[category] || category;
  }

  saveCategory(category: string) {
    this.saving = true;
    this.successMessage = '';
    const items = this.configsByCategory(category);
    let remaining = items.length;
    if (remaining === 0) { this.saving = false; return; }

    items.forEach(cfg => {
      this.apiService.put(`/api/system-config/${cfg.id}`, { configValue: cfg.configValue }).subscribe({
        next: () => {
          remaining--;
          if (remaining === 0) {
            this.saving = false;
            this.successMessage = `${this.categoryLabel(category)} saved successfully.`;
            setTimeout(() => (this.successMessage = ''), 3000);
          }
        },
        error: (err) => {
          console.error('Failed to save config', cfg.configKey, err);
          this.saving = false;
          alert(`Failed to save ${cfg.configKey}`);
        }
      });
    });
  }
}

