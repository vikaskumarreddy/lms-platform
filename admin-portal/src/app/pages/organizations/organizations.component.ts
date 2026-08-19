import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';
import { ApiErrorService } from '../../services/api-error.service';

interface Organization {
  id?: number;
  name: string;
  slug: string;
  domain?: string;
  logoUrl?: string;
  isActive: boolean;
  status?: string;
  purchaseDate?: string;
  expiryDate?: string;
  renewalCount?: number;
  planId?: number;
  orgSubscriptionId?: number | null;
  orgSubscriptionName?: string | null;
  settings?: Record<string, string>;
  createdAt?: string;
  updatedAt?: string;

  /** Sales context. */
  poNumber?: string;
  salesOwner?: string;

  /** GST identity, captured at creation so invoices can be raised without chasing it. */
  legalName?: string;
  gstin?: string;
  placeOfSupply?: string;
  stateCode?: string;
  billingEmail?: string;
  billingPhone?: string;
  billingAddress?: string;
}

interface OrgFormData {
  name: string;
  slug: string;
  domain: string;
  isActive: boolean;
  status: string;
  purchaseDate: string;
  expiryDate: string;
  planId: number | null;
  orgSubscriptionId: number | null;

  /** Subscription terms agreed at creation. */
  billingCycle: string;
  agreedPrice: number | null;

  /** Negotiated limits — only sent for plans that allow them. */
  limitStudents: number | null;
  limitFaculty: number | null;
  limitBranches: number | null;
  limitStorage: number | null;

  /** Sales context, shown back to the tenant on their Account page. */
  poNumber: string;
  salesOwner: string;

  /** GST identity, needed before a compliant invoice can be raised. */
  legalName: string;
  gstin: string;
  placeOfSupply: string;
  stateCode: string;
  billingEmail: string;
  billingPhone: string;
  billingAddress: string;
}

interface AdminFormData {
  email: string;
  name: string;
  password: string;
  phone: string;
  isActive: boolean;
}

interface OrgAdmin {
  id: number;
  name: string;
  email: string;
  phone?: string;
  isActive: boolean;
}

interface OrgSubscriptionOpt {
  id: number;
  code: string;
  name: string;
  price: number;
  priceMonthly: number | null;
  priceYearly: number | null;
  period: string;
  isActive: boolean;
  isCustomPriced: boolean;
  limitsConfigurable: boolean;
  maxActiveStudents: number | null;
  maxFacultyAccounts: number | null;
  maxBranches: number | null;
  storageGb: number | null;
  includedTrainingHours: number;
  overageStudentsAllowed: number;
  overageStudentPrice: number | null;
}

@Component({
  selector: 'app-organizations',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './organizations.component.html',
  styleUrls: ['./organizations.component.css']
})
export class OrganizationsComponent implements OnInit {
  private api = inject(ApiService);
  private errors = inject(ApiErrorService);

  organizations: Organization[] = [];
  subscriptions: OrgSubscriptionOpt[] = [];
  showModal = false;
  showAdminModal = false;
  adminFormVisible = false;
  selectedOrgId: number | null = null;
  editingId: number | null = null;
  editingAdminId: number | null = null;
  formData: OrgFormData = this.blankForm();

  /** The plan currently chosen in the modal, so its limits can be previewed. */
  selectedPlan: OrgSubscriptionOpt | null = null;
  adminFormData: AdminFormData = {
    email: '',
    name: '',
    password: '',
    phone: '',
    isActive: true
  };
  orgAdmins: OrgAdmin[] = [];

  ngOnInit() {
    this.loadOrganizations();
    this.loadSubscriptions();
  }

  loadOrganizations() {
    this.api.get<Organization[]>('/api/organizations').subscribe({
      next: (data) => {
        this.organizations = data;
      },
      error: (err) => console.error('Failed to load organizations:', err)
    });
  }

  loadSubscriptions() {
    this.api.get<OrgSubscriptionOpt[]>('/api/org-subscriptions').subscribe({
      next: (data) => {
        this.subscriptions = data;
      },
      error: (err) => console.error('Failed to load org subscriptions:', err)
    });
  }

  private blankForm(): OrgFormData {
    return {
      name: '', slug: '', domain: '', isActive: true, status: 'ACTIVE',
      purchaseDate: '', expiryDate: '', planId: null, orgSubscriptionId: null,
      billingCycle: 'MONTHLY', agreedPrice: null,
      limitStudents: null, limitFaculty: null, limitBranches: null, limitStorage: null,
      poNumber: '', salesOwner: '',
      legalName: '', gstin: '', placeOfSupply: '', stateCode: '',
      billingEmail: '', billingPhone: '', billingAddress: ''
    };
  }

  openAddModal() {
    this.editingId = null;
    this.formData = this.blankForm();
    this.selectedPlan = null;
    this.showModal = true;
  }

  openEditModal(org: Organization) {
    this.editingId = org.id || null;
    this.formData = {
      ...this.blankForm(),
      name: org.name,
      slug: org.slug,
      domain: org.domain || '',
      isActive: org.isActive,
      status: org.status || 'ACTIVE',
      purchaseDate: (org.purchaseDate || '').slice(0, 16),
      expiryDate: (org.expiryDate || '').slice(0, 16),
      planId: org.planId || null,
      orgSubscriptionId: org.orgSubscriptionId || null,
      poNumber: org.poNumber || '',
      salesOwner: org.salesOwner || '',
      legalName: org.legalName || '',
      gstin: org.gstin || '',
      placeOfSupply: org.placeOfSupply || '',
      stateCode: org.stateCode || '',
      billingEmail: org.billingEmail || '',
      billingPhone: org.billingPhone || '',
      billingAddress: org.billingAddress || ''
    };
    this.onPlanSelected(this.formData.orgSubscriptionId);
    this.showModal = true;
  }

  /** Keeps the limits preview in step with the chosen plan. */
  onPlanSelected(planId: number | null) {
    this.selectedPlan = planId != null
      ? this.subscriptions.find(s => s.id === Number(planId)) ?? null
      : null;
  }

  /** Hint text for the agreed-price field: the plan's list price for the chosen cycle. */
  listPricePlaceholder(): string {
    if (!this.selectedPlan) {
      return 'Select a plan first';
    }
    if (this.selectedPlan.isCustomPriced) {
      return 'Required — this plan is quoted';
    }
    const price = this.formData.billingCycle === 'YEARLY'
      ? this.selectedPlan.priceYearly
      : this.selectedPlan.priceMonthly;
    return price != null ? String(price) : 'No list price set';
  }

  closeModal() {
    this.showModal = false;
  }

  saveOrganization() {
    if (!this.formData.name.trim() || !this.formData.slug.trim()) {
      this.errors.info('Name and slug are both required.', 'Almost there');
      return;
    }
    // A custom-priced plan has no list price to fall back on, so refusing here beats
    // letting the server reject it after the form has been dismissed.
    if (this.selectedPlan?.isCustomPriced && !this.formData.agreedPrice) {
      this.errors.info(
        `${this.selectedPlan.name} is priced per organization — enter the agreed price.`,
        'Price needed');
      return;
    }

    const payload: any = {
      name: this.formData.name,
      slug: this.formData.slug,
      domain: this.formData.domain,
      isActive: this.formData.isActive,
      status: this.formData.status,
      purchaseDate: this.formData.purchaseDate,
      expiryDate: this.formData.expiryDate,
      planId: this.formData.planId,
      orgSubscriptionId: this.formData.orgSubscriptionId,

      billingCycle: this.formData.billingCycle,
      agreedPrice: this.formData.agreedPrice,
      poNumber: this.formData.poNumber,
      salesOwner: this.formData.salesOwner,

      legalName: this.formData.legalName,
      gstin: this.formData.gstin,
      placeOfSupply: this.formData.placeOfSupply,
      stateCode: this.formData.stateCode,
      billingEmail: this.formData.billingEmail,
      billingPhone: this.formData.billingPhone,
      billingAddress: this.formData.billingAddress
    };

    // Only sent for plans that permit negotiated limits; the server rejects them otherwise.
    if (this.selectedPlan?.limitsConfigurable) {
      const overrides: Record<string, number> = {};
      if (this.formData.limitStudents) overrides['MAX_ACTIVE_STUDENTS'] = this.formData.limitStudents;
      if (this.formData.limitFaculty) overrides['MAX_FACULTY_ACCOUNTS'] = this.formData.limitFaculty;
      if (this.formData.limitBranches) overrides['MAX_BRANCHES'] = this.formData.limitBranches;
      if (this.formData.limitStorage) overrides['STORAGE_GB'] = this.formData.limitStorage;
      if (Object.keys(overrides).length > 0) {
        payload.limitOverrides = overrides;
      }
    }

    const request = this.editingId
      ? this.api.put(`/api/organizations/${this.editingId}`, payload)
      : this.api.post('/api/organizations', payload);

    request.subscribe({
      next: () => {
        this.closeModal();
        this.errors.success(this.editingId ? 'Organization updated.' : 'Organization created.');
        this.loadOrganizations();
      },
      error: (err) => this.errors.show(err, 'Could not save that organization')
    });
  }

  onLogoSelect() {
    // Handler for logo selection
  }

  uploadLogo(fileInput: HTMLInputElement) {
    const file = fileInput.files?.[0];
    if (!file || !this.editingId) return;

    const formData = new FormData();
    formData.append('file', file);

    this.api.postForm(`/api/organizations/${this.editingId}/logo`, formData).subscribe({
      next: () => {
        this.loadOrganizations();
        alert('Logo uploaded successfully');
      },
      error: (err) => console.error('Failed to upload logo:', err)
    });
  }

  confirmDelete(org: Organization) {
    if (!confirm(`Are you sure you want to delete "${org.name}"?`)) return;
    
    if (!org.id) return;
    this.api.delete(`/api/organizations/${org.id}`).subscribe({
      next: () => {
        this.loadOrganizations();
      },
      error: (err) => console.error('Failed to delete organization:', err)
    });
  }

  openAdminModal(org: Organization) {
    this.selectedOrgId = org.id || null;
    this.editingAdminId = null;
    this.adminFormVisible = false;
    this.adminFormData = {
      email: '',
      name: '',
      password: '',
      phone: '',
      isActive: true
    };
    this.orgAdmins = [];
    this.showAdminModal = true;
    this.loadOrgAdmins();
  }

  loadOrgAdmins() {
    if (!this.selectedOrgId) return;
    this.api.get<OrgAdmin[]>(`/api/organizations/${this.selectedOrgId}/admin`).subscribe({
      next: (data) => {
        this.orgAdmins = data;
      },
      error: (err) => console.error('Failed to load organization admins:', err)
    });
  }

  closeAdminModal() {
    this.showAdminModal = false;
    this.adminFormVisible = false;
    this.editingAdminId = null;
    this.selectedOrgId = null;
    this.orgAdmins = [];
  }

  /** Opens the "Create Admin" popup for the selected organization. */
  openCreateAdminForm() {
    this.editingAdminId = null;
    this.adminFormData = { email: '', name: '', password: '', phone: '', isActive: true };
    this.adminFormVisible = true;
  }

  /** Closes the create/edit admin popup and resets the form. */
  closeAdminForm() {
    this.adminFormVisible = false;
    this.editingAdminId = null;
    this.adminFormData = { email: '', name: '', password: '', phone: '', isActive: true };
  }

  createAdmin() {
    if (!this.adminFormData.email.trim() || !this.adminFormData.name.trim() || !this.adminFormData.password.trim()) {
      alert('Email, Name, and Password are required');
      return;
    }

    if (!this.selectedOrgId) {
      alert('No organization selected');
      return;
    }

    const payload = {
      email: this.adminFormData.email,
      name: this.adminFormData.name,
      password: this.adminFormData.password,
      phone: this.adminFormData.phone
    };

    this.api.post(`/api/organizations/${this.selectedOrgId}/admin`, payload).subscribe({
      next: () => {
        alert('Organization admin created successfully!');
        this.adminFormData = { email: '', name: '', password: '', phone: '', isActive: true };
        this.editingAdminId = null;
        this.adminFormVisible = false;
        this.loadOrgAdmins();
      },
      error: (err) => {
        console.error('Failed to create organization admin:', err);
        const message = err.error?.error || err.error?.message || 'Check console for details.';
        alert('Failed to create organization admin. ' + message);
      }
    });
  }

  editAdmin(admin: OrgAdmin) {
    this.editingAdminId = admin.id;
    this.adminFormData = {
      email: admin.email,
      name: admin.name,
      password: '',
      phone: admin.phone || '',
      isActive: admin.isActive
    };
    this.adminFormVisible = true;
  }

  cancelAdminEdit() {
    this.editingAdminId = null;
    this.adminFormData = { email: '', name: '', password: '', phone: '', isActive: true };
    this.adminFormVisible = false;
  }

  submitAdmin() {
    if (this.editingAdminId) {
      this.updateAdmin();
    } else {
      this.createAdmin();
    }
  }

  updateAdmin() {
    if (!this.editingAdminId || !this.selectedOrgId) {
      alert('No admin selected');
      return;
    }
    if (!this.adminFormData.name.trim()) {
      alert('Name is required');
      return;
    }
    const payload = {
      name: this.adminFormData.name,
      phone: this.adminFormData.phone,
      isActive: this.adminFormData.isActive,
      password: this.adminFormData.password
    };
    this.api.put(`/api/organizations/${this.selectedOrgId}/admin/${this.editingAdminId}`, payload).subscribe({
      next: () => {
        alert('Organization admin updated successfully!');
        this.cancelAdminEdit();
        this.loadOrgAdmins();
      },
      error: (err) => {
        console.error('Failed to update organization admin:', err);
        const message = err.error?.error || err.error?.message || 'Check console for details.';
        alert('Failed to update organization admin. ' + message);
      }
    });
  }

  deleteAdmin(admin: OrgAdmin) {
    if (!confirm(`Are you sure you want to delete admin "${admin.email}"?`)) return;
    if (!this.selectedOrgId || !admin.id) return;
    this.api.delete(`/api/organizations/${this.selectedOrgId}/admin/${admin.id}`).subscribe({
      next: () => {
        this.loadOrgAdmins();
      },
      error: (err) => {
        console.error('Failed to delete organization admin:', err);
        const message = err.error?.error || err.error?.message || 'Check console for details.';
        alert('Failed to delete organization admin. ' + message);
      }
    });
  }

  /** Renews an expired/inactive organization via POST /api/organizations/{id}/renew. */
  renewOrg(org: Organization) {
    if (!org.id) return;
    if (!confirm(`Renew "${org.name}"? This reactivates the organization and extends its plan expiry.`)) return;
    this.api.post(`/api/organizations/${org.id}/renew`, {}).subscribe({
      next: () => {
        this.loadOrganizations();
      },
      error: (err) => {
        console.error('Failed to renew organization:', err);
        alert('Failed to renew organization.');
      }
    });
  }
}
