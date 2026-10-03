import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { ApiService } from '../../../services/api.service';
import { ApiErrorService } from '../../../services/api-error.service';
import { ConfirmService } from '../../../services/confirm.service';

interface SubscriptionPlan {
  id: number;
  name: string;
  price: number;
  period: string;
}

interface Batch {
  id: number;
  name: string;
  planId?: number;
  isActive: boolean;
}

interface RuleCondition {
  fieldKey: string;
  operator: 'EQUALS' | 'NOT_EQUALS' | 'CONTAINS' | 'STARTS_WITH' | 'IN';
  value: string;
}

interface BatchRule {
  id?: number;
  name: string;
  planId: number | null;
  batchId: number | null;
  priority: number;
  isActive: boolean;
  conditions?: string; // JSON string
  parsedConditions?: RuleCondition[];
  createdAt?: string;
}

interface AvailableField {
  key: string;
  label: string;
  type: string;
  options?: string[];
}

@Component({
  selector: 'app-batch-rules',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  template: `
    <div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:20px;flex-wrap:wrap;gap:16px;">
      <div>
        <h1 style="font-size:24px;font-weight:700;margin:0 0 6px;">👥 Batches & Rules</h1>
        <p style="color:var(--text-secondary);margin:0;font-size:14px;">
          Define automatic batch assignment rules for self-registering students based on their chosen subscription plan and registration form responses.
        </p>
      </div>
      <button class="btn btn-primary" (click)="openAddModal()">+ Create Batch Rule</button>
    </div>

    <!-- Submenu navigation tabs -->
    <div class="batch-tabs">
      <a routerLink="/batches" class="batch-tab-btn">👥 All Batches</a>
      <a routerLink="/batches/rules" class="batch-tab-btn active">⚡ Batch Rules ({{ rules.length }})</a>
    </div>

    <div class="note" style="background:#EFF6FF;border:1px solid #BFDBFE;color:#1E3A8A;padding:12px 16px;border-radius:10px;font-size:13px;margin-bottom:20px;">
      <strong>📌 How Batch Rules Work:</strong> When a student submits the registration form, the engine evaluates active rules matching their selected <strong>Subscription Plan</strong> in order of priority. If the student's field values satisfy the rule's conditions, they are automatically placed into that batch!
    </div>

    <div class="alert alert-ok" *ngIf="successMessage" style="background:#DCFCE7;color:#166534;padding:12px;border-radius:8px;margin-bottom:16px;">
      {{ successMessage }}
    </div>

    <!-- Rules Table -->
    <div class="card" style="margin-bottom:20px;">
      <table style="width:100%;border-collapse:collapse;">
        <thead>
          <tr>
            <th style="width:60px;">Pri</th>
            <th>Rule Name</th>
            <th>Subscription Plan (Mandatory)</th>
            <th>Assigned Batch</th>
            <th>Conditions</th>
            <th style="width:100px;">Status</th>
            <th style="width:150px;text-align:right;">Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr *ngFor="let r of rules">
            <td>
              <span class="badge" style="background:#F1F5F9;color:#334155;font-weight:700;">#{{ r.priority || 0 }}</span>
            </td>
            <td style="font-weight:600;">
              {{ r.name }}
            </td>
            <td>
              <span *ngIf="getPlanName(r.planId)" class="badge" style="background:#FEF3C7;color:#92400E;font-weight:600;">
                ⭐ {{ getPlanName(r.planId) }}
              </span>
              <span *ngIf="!getPlanName(r.planId)" style="color:#DC2626;font-size:12px;">⚠️ Missing Plan</span>
            </td>
            <td>
              <span *ngIf="getBatchName(r.batchId)" class="badge" style="background:#EEF2FF;color:#4338CA;font-weight:600;">
                👥 {{ getBatchName(r.batchId) }}
              </span>
              <span *ngIf="!getBatchName(r.batchId)" style="color:#DC2626;font-size:12px;">⚠️ Unknown Batch</span>
            </td>
            <td>
              <div *ngIf="r.parsedConditions && r.parsedConditions.length > 0" style="display:flex;flex-direction:column;gap:4px;">
                <div *ngFor="let cond of r.parsedConditions" style="font-size:12px;background:#F8FAFC;padding:3px 8px;border-radius:6px;border:1px solid #E2E8F0;display:inline-block;">
                  <code>{{ getFieldLabel(cond.fieldKey) }}</code>
                  <span style="color:#64748B;font-weight:600;margin:0 4px;">{{ cond.operator }}</span>
                  <strong style="color:var(--primary);">"{{ cond.value }}"</strong>
                </div>
              </div>
              <span *ngIf="!r.parsedConditions || r.parsedConditions.length === 0" style="color:#64748B;font-size:12px;font-style:italic;">
                (Catch-all default for this plan)
              </span>
            </td>
            <td>
              <button class="badge" [class.badge-success]="r.isActive" [class.badge-danger]="!r.isActive"
                      style="border:none;cursor:pointer;" (click)="toggleRuleActive(r)">
                {{ r.isActive ? 'Active' : 'Inactive' }}
              </button>
            </td>
            <td style="text-align:right;">
              <button class="btn btn-secondary" style="padding:4px 10px;font-size:12px;margin-right:6px;" (click)="openEditModal(r)">Edit</button>
              <button class="btn btn-danger" style="padding:4px 10px;font-size:12px;" (click)="deleteRule(r)">Delete</button>
            </td>
          </tr>
          <tr *ngIf="rules.length === 0">
            <td colspan="7" style="text-align:center;color:#64748B;padding:36px;">
              No batch rules created yet. Click "+ Create Batch Rule" to configure your first automated assignment rule.
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Create / Edit Modal -->
    <div class="modal-overlay" *ngIf="showModal">
      <div class="modal-content" style="max-width:620px;width:100%;">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:20px;">
          <h2 style="font-size:18px;font-weight:700;margin:0;">
            {{ editingRule ? 'Edit Batch Rule' : '+ Create Batch Rule' }}
          </h2>
          <button style="border:none;background:none;font-size:20px;cursor:pointer;color:var(--text-secondary);" (click)="closeModal()">✕</button>
        </div>

        <form (ngSubmit)="saveRule()">
          <!-- Rule Name -->
          <div style="margin-bottom:16px;">
            <label style="display:block;font-size:13px;font-weight:600;margin-bottom:6px;">Rule Name <span style="color:#DC2626;">*</span></label>
            <input type="text" class="input-field" [(ngModel)]="ruleForm.name" name="name" required placeholder="e.g. Morning Shift - Full Stack">
          </div>

          <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-bottom:16px;">
            <!-- Subscription Plan (Mandatory) -->
            <div>
              <label style="display:block;font-size:13px;font-weight:600;margin-bottom:6px;">
                Subscription Plan <span style="color:#DC2626;">* (Mandatory)</span>
              </label>
              <select class="input-field" [(ngModel)]="ruleForm.planId" name="planId" (ngModelChange)="onPlanSelected()" required>
                <option [ngValue]="null" disabled>Select Subscription Plan...</option>
                <option *ngFor="let p of plans" [ngValue]="p.id">⭐ {{ p.name }} (₹{{ p.price }})</option>
              </select>
            </div>

            <!-- Target Batch -->
            <div>
              <label style="display:block;font-size:13px;font-weight:600;margin-bottom:6px;">
                Assigned Batch <span style="color:#DC2626;">*</span>
              </label>
              <select class="input-field" [(ngModel)]="ruleForm.batchId" name="batchId" required>
                <option [ngValue]="null" disabled>Select Batch...</option>
                <option *ngFor="let b of availableBatchesForPlan" [ngValue]="b.id">👥 {{ b.name }}</option>
              </select>
              <small *ngIf="availableBatchesForPlan.length === 0" style="color:#DC2626;font-size:11px;display:block;margin-top:4px;">
                No batches found. Please create a batch in Batches first.
              </small>
            </div>
          </div>

          <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-bottom:16px;">
            <div>
              <label style="display:block;font-size:13px;font-weight:600;margin-bottom:6px;">Evaluation Priority</label>
              <input type="number" class="input-field" [(ngModel)]="ruleForm.priority" name="priority" min="0" placeholder="0 (Lowest number runs first)">
              <small style="color:var(--text-muted);font-size:11px;">Lower numbers are evaluated first (e.g. 1 before 2).</small>
            </div>
            <div>
              <label style="display:block;font-size:13px;font-weight:600;margin-bottom:6px;">Rule Status</label>
              <select class="input-field" [(ngModel)]="ruleForm.isActive" name="isActive">
                <option [ngValue]="true">Active (Evaluates during registration)</option>
                <option [ngValue]="false">Inactive (Disabled)</option>
              </select>
            </div>
          </div>

          <!-- Conditions Builder Section -->
          <div style="background:var(--surface-alt);border:1px solid var(--border-light);border-radius:12px;padding:16px;margin-bottom:20px;">
            <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;">
              <div>
                <strong style="font-size:13px;color:var(--text);">Matching Conditions (AND)</strong>
                <div style="font-size:11px;color:var(--text-secondary);">Students must match all conditions below to be assigned to this batch.</div>
              </div>
              <button type="button" class="btn btn-secondary" style="padding:4px 10px;font-size:12px;" (click)="addCondition()">
                + Add Condition
              </button>
            </div>

            <div *ngIf="ruleConditions.length === 0" style="text-align:center;padding:16px;color:var(--text-muted);font-size:12px;background:var(--surface);border-radius:8px;border:1px dashed var(--border-light);">
              No specific field conditions added. This rule will act as a default batch for any student choosing this subscription plan!
            </div>

            <div *ngFor="let cond of ruleConditions; let idx = index" style="display:flex;gap:8px;align-items:center;margin-bottom:8px;background:var(--surface);padding:8px;border-radius:8px;border:1px solid var(--border-light);">
              <!-- Field Selector -->
              <select class="input-field" style="flex:1.2;" [(ngModel)]="cond.fieldKey" [name]="'cond_field_' + idx" (ngModelChange)="onConditionFieldChange(cond)">
                <option value="" disabled>Select Field...</option>
                <option *ngFor="let f of availableFields" [value]="f.key">{{ f.label }} ({{ f.key }})</option>
              </select>

              <!-- Operator -->
              <select class="input-field" style="width:130px;" [(ngModel)]="cond.operator" [name]="'cond_op_' + idx">
                <option value="EQUALS">Equals</option>
                <option value="NOT_EQUALS">Does Not Equal</option>
                <option value="CONTAINS">Contains</option>
                <option value="STARTS_WITH">Starts With</option>
                <option value="IN">In List (comma separated)</option>
              </select>

              <!-- Value Input (Dropdown if select field, or Text) -->
              <div style="flex:1.2;">
                <select *ngIf="getFieldOptions(cond.fieldKey).length > 0 && cond.operator === 'EQUALS'"
                        class="input-field" [(ngModel)]="cond.value" [name]="'cond_val_' + idx">
                  <option value="" disabled>Select option...</option>
                  <option *ngFor="let opt of getFieldOptions(cond.fieldKey)" [value]="opt">{{ opt }}</option>
                </select>

                <input *ngIf="getFieldOptions(cond.fieldKey).length === 0 || cond.operator !== 'EQUALS'"
                       type="text" class="input-field" [(ngModel)]="cond.value" [name]="'cond_val_' + idx"
                       placeholder="Expected value">
              </div>

              <!-- Delete condition -->
              <button type="button" style="border:none;background:none;color:#DC2626;cursor:pointer;font-size:16px;padding:4px;" (click)="removeCondition(idx)">
                🗑️
              </button>
            </div>
          </div>

          <div *ngIf="errorMessage" style="margin-bottom:16px;padding:10px 14px;background:#FEE2E2;color:#991B1B;border-radius:8px;font-size:13px;">
            {{ errorMessage }}
          </div>

          <div style="display:flex;justify-content:flex-end;gap:10px;">
            <button type="button" class="btn btn-secondary" (click)="closeModal()">Cancel</button>
            <button type="submit" class="btn btn-primary" [disabled]="loading || !ruleForm.name || !ruleForm.planId || !ruleForm.batchId">
              {{ loading ? 'Saving...' : (editingRule ? 'Update Rule' : 'Create Rule') }}
            </button>
          </div>
        </form>
      </div>
    </div>
  `,
  styles: [`
    .batch-tabs {
      display: flex;
      gap: 8px;
      border-bottom: 2px solid var(--border-light);
      margin-bottom: 20px;
    }
    .batch-tab-btn {
      padding: 10px 18px;
      font-size: 14px;
      font-weight: 600;
      color: var(--text-secondary);
      text-decoration: none;
      border-bottom: 2px solid transparent;
      margin-bottom: -2px;
      transition: all 0.2s;
    }
    .batch-tab-btn:hover {
      color: var(--primary);
    }
    .batch-tab-btn.active {
      color: var(--primary);
      border-bottom-color: var(--primary);
    }
    .input-field {
      width: 100%;
      padding: 8px 12px;
      border: 1px solid var(--border-light);
      border-radius: 8px;
      background: var(--surface);
      color: var(--text);
      font-size: 13px;
    }
    .input-field:focus {
      outline: none;
      border-color: var(--primary);
    }
    .modal-overlay {
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(0,0,0,0.5);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 1000;
      padding: 20px;
    }
    .modal-content {
      background: var(--surface);
      color: var(--text);
      border-radius: 16px;
      padding: 24px;
      box-shadow: 0 20px 25px -5px rgba(0,0,0,0.15);
      max-height: 90vh;
      overflow-y: auto;
    }
    .badge {
      display: inline-block;
      padding: 3px 8px;
      border-radius: 6px;
      font-size: 12px;
    }
    .badge-success { background:#DCFCE7; color:#166534; }
    .badge-danger { background:#FEE2E2; color:#991B1B; }
  `]
})
export class BatchRulesComponent implements OnInit {
  private api = inject(ApiService);
  private errors = inject(ApiErrorService);
  private confirm = inject(ConfirmService);

  rules: BatchRule[] = [];
  plans: SubscriptionPlan[] = [];
  batches: Batch[] = [];
  availableFields: AvailableField[] = [];

  showModal = false;
  editingRule: BatchRule | null = null;
  loading = false;
  errorMessage = '';
  successMessage = '';

  ruleForm: {
    name: string;
    planId: number | null;
    batchId: number | null;
    priority: number;
    isActive: boolean;
  } = {
    name: '',
    planId: null,
    batchId: null,
    priority: 0,
    isActive: true
  };

  ruleConditions: RuleCondition[] = [];

  ngOnInit() {
    this.loadData();
    this.loadRegistrationFields();
  }

  loadData() {
    this.api.get<BatchRule[]>('/api/batch-rules').subscribe({
      next: (rules) => {
        this.rules = rules.map(r => {
          let parsed: RuleCondition[] = [];
          if (r.conditions) {
            try {
              parsed = JSON.parse(r.conditions);
            } catch (e) {}
          }
          return { ...r, parsedConditions: parsed };
        });
      },
      error: () => {}
    });

    this.api.get<SubscriptionPlan[]>('/api/subscription-plans/admin/all').subscribe({
      next: (plans) => this.plans = plans,
      error: () => {
        this.api.get<SubscriptionPlan[]>('/api/subscription-plans').subscribe({
          next: (plans) => this.plans = plans,
          error: () => {}
        });
      }
    });

    this.api.get<Batch[]>('/api/batches').subscribe({
      next: (batches) => {
        if (batches && batches.length > 0) {
          this.batches = batches;
        } else {
          this.api.get<Batch[]>('/api/batches/active').subscribe({
            next: (active) => this.batches = active || [],
            error: () => {}
          });
        }
      },
      error: () => {
        this.api.get<Batch[]>('/api/batches/active').subscribe({
          next: (active) => this.batches = active || [],
          error: () => {}
        });
      }
    });
  }

  loadRegistrationFields() {
    // Default prebuilt fields
    const defaultFields: AvailableField[] = [
      { key: 'qualification', label: 'Qualification', type: 'text' },
      { key: 'collegeName', label: 'College / University Name', type: 'text' },
      { key: 'parentName', label: 'Parent Name', type: 'text' },
      { key: 'linkedin', label: 'LinkedIn Profile', type: 'text' },
      { key: 'github', label: 'GitHub Profile', type: 'text' },
      { key: 'notifyMedium', label: 'Parent Notification Via', type: 'select', options: ['PUSH', 'SMS', 'WHATSAPP'] },
    ];

    this.api.get<any>('/api/organizations/current').subscribe({
      next: (org) => {
        let loadedFields: AvailableField[] = [...defaultFields];
        if (org?.settings) {
          try {
            const settingsObj = typeof org.settings === 'string' ? JSON.parse(org.settings) : org.settings;
            if (settingsObj?.registrationFormConfig?.fields) {
              const customFromSettings = settingsObj.registrationFormConfig.fields
                .filter((f: any) => f.enabled && !['name', 'email', 'password', 'planId', 'phone'].includes(f.key))
                .map((f: any) => ({
                  key: f.key,
                  label: f.label,
                  type: f.type,
                  options: f.options || []
                }));
              // Merge, avoiding duplicates
              for (const cf of customFromSettings) {
                if (!loadedFields.some(x => x.key === cf.key)) {
                  loadedFields.push(cf);
                }
              }
            }
          } catch (e) {}
        }
        this.availableFields = loadedFields;
      },
      error: () => {
        this.availableFields = defaultFields;
      }
    });
  }

  get availableBatchesForPlan(): Batch[] {
    return this.batches || [];
  }

  onPlanSelected() {
    // Keep batch selection open to all batches
  }

  openAddModal() {
    this.loadData();
    this.editingRule = null;
    this.ruleForm = {
      name: '',
      planId: null,
      batchId: null,
      priority: this.rules.length + 1,
      isActive: true
    };
    this.ruleConditions = [];
    this.errorMessage = '';
    this.showModal = true;
  }

  openEditModal(rule: BatchRule) {
    this.editingRule = rule;
    this.ruleForm = {
      name: rule.name,
      planId: rule.planId,
      batchId: rule.batchId,
      priority: rule.priority || 0,
      isActive: rule.isActive
    };
    this.ruleConditions = rule.parsedConditions ? JSON.parse(JSON.stringify(rule.parsedConditions)) : [];
    this.errorMessage = '';
    this.showModal = true;
  }

  closeModal() {
    this.showModal = false;
    this.editingRule = null;
  }

  addCondition() {
    const firstField = this.availableFields[0];
    this.ruleConditions.push({
      fieldKey: firstField ? firstField.key : '',
      operator: 'EQUALS',
      value: ''
    });
  }

  onConditionFieldChange(cond: RuleCondition) {
    const opts = this.getFieldOptions(cond.fieldKey);
    if (opts.length > 0) {
      cond.value = opts[0];
    } else {
      cond.value = '';
    }
  }

  removeCondition(index: number) {
    this.ruleConditions.splice(index, 1);
  }

  getFieldOptions(fieldKey: string): string[] {
    const f = this.availableFields.find(x => x.key === fieldKey);
    return f?.options || [];
  }

  getFieldLabel(fieldKey: string): string {
    const f = this.availableFields.find(x => x.key === fieldKey);
    return f ? f.label : fieldKey;
  }

  getPlanName(planId: number | null | undefined): string {
    if (!planId) return '';
    const p = this.plans.find(x => x.id === planId);
    return p ? p.name : `Plan #${planId}`;
  }

  getBatchName(batchId: number | null | undefined): string {
    if (!batchId) return '';
    const b = this.batches.find(x => x.id === batchId);
    return b ? b.name : `Batch #${batchId}`;
  }

  toggleRuleActive(rule: BatchRule) {
    const updated = { ...rule, isActive: !rule.isActive };
    this.api.put<BatchRule>(`/api/batch-rules/${rule.id}`, updated).subscribe({
      next: () => {
        rule.isActive = !rule.isActive;
      },
      error: (err) => alert(err.error?.message || 'Failed to toggle status')
    });
  }

  deleteRule(rule: BatchRule) {
    if (!confirm(`Are you sure you want to delete rule "${rule.name}"?`)) return;
    this.api.delete(`/api/batch-rules/${rule.id}`).subscribe({
      next: () => {
        this.rules = this.rules.filter(r => r.id !== rule.id);
        this.successMessage = `Rule "${rule.name}" deleted.`;
        setTimeout(() => this.successMessage = '', 4000);
      },
      error: (err) => alert(err.error?.message || 'Failed to delete rule')
    });
  }

  saveRule() {
    this.errorMessage = '';
    if (!this.ruleForm.name.trim()) {
      this.errorMessage = 'Rule name is required';
      return;
    }
    if (!this.ruleForm.planId) {
      this.errorMessage = 'Subscription Plan is mandatory';
      return;
    }
    if (!this.ruleForm.batchId) {
      this.errorMessage = 'Target Batch is mandatory';
      return;
    }

    // Verify batch belongs to plan
    const selectedBatch = this.batches.find(b => b.id === this.ruleForm.batchId);
    if (!selectedBatch || selectedBatch.planId !== Number(this.ruleForm.planId)) {
      this.errorMessage = 'The selected target batch does not belong to the selected subscription plan!';
      return;
    }

    this.loading = true;
    const payload: BatchRule = {
      name: this.ruleForm.name.trim(),
      planId: this.ruleForm.planId,
      batchId: this.ruleForm.batchId,
      priority: this.ruleForm.priority || 0,
      isActive: this.ruleForm.isActive,
      conditions: JSON.stringify(this.ruleConditions.filter(c => c.fieldKey && c.value.trim()))
    };

    if (this.editingRule?.id) {
      this.api.put<BatchRule>(`/api/batch-rules/${this.editingRule.id}`, payload).subscribe({
        next: () => {
          this.loading = false;
          this.closeModal();
          this.loadData();
          this.successMessage = 'Batch rule updated successfully!';
          setTimeout(() => this.successMessage = '', 4000);
        },
        error: (err) => {
          this.loading = false;
          this.errorMessage = err.error?.message || 'Failed to update rule';
        }
      });
    } else {
      this.api.post<BatchRule>('/api/batch-rules', payload).subscribe({
        next: () => {
          this.loading = false;
          this.closeModal();
          this.loadData();
          this.successMessage = 'Batch rule created successfully!';
          setTimeout(() => this.successMessage = '', 4000);
        },
        error: (err) => {
          this.loading = false;
          this.errorMessage = err.error?.message || 'Failed to create rule';
        }
      });
    }
  }
}
