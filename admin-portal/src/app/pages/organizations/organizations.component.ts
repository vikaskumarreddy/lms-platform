import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';

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
  name: string;
  price: number;
  period: string;
  isActive: boolean;
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

  organizations: Organization[] = [];
  subscriptions: OrgSubscriptionOpt[] = [];
  showModal = false;
  showAdminModal = false;
  adminFormVisible = false;
  selectedOrgId: number | null = null;
  editingId: number | null = null;
  editingAdminId: number | null = null;
  formData: OrgFormData = {
    name: '',
    slug: '',
    domain: '',
    isActive: true,
    status: 'ACTIVE',
    purchaseDate: '',
    expiryDate: '',
    planId: null,
    orgSubscriptionId: null
  };
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

  openAddModal() {
    this.editingId = null;
    this.formData = { name: '', slug: '', domain: '', isActive: true, status: 'ACTIVE', purchaseDate: '', expiryDate: '', planId: null, orgSubscriptionId: null };
    this.showModal = true;
  }

  openEditModal(org: Organization) {
    this.editingId = org.id || null;
    this.formData = {
      name: org.name,
      slug: org.slug,
      domain: org.domain || '',
      isActive: org.isActive,
      status: org.status || 'ACTIVE',
      purchaseDate: (org.purchaseDate || '').slice(0, 16),
      expiryDate: (org.expiryDate || '').slice(0, 16),
      planId: org.planId || null,
      orgSubscriptionId: org.orgSubscriptionId || null
    };
    this.showModal = true;
  }

  closeModal() {
    this.showModal = false;
  }

  saveOrganization() {
    if (!this.formData.name.trim() || !this.formData.slug.trim()) {
      alert('Name and Slug are required');
      return;
    }

    const payload = {
      name: this.formData.name,
      slug: this.formData.slug,
      domain: this.formData.domain,
      isActive: this.formData.isActive,
      status: this.formData.status,
      purchaseDate: this.formData.purchaseDate,
      expiryDate: this.formData.expiryDate,
      planId: this.formData.planId,
      orgSubscriptionId: this.formData.orgSubscriptionId
    };

    if (this.editingId) {
      this.api.put(`/api/organizations/${this.editingId}`, payload).subscribe({
        next: () => {
          this.closeModal();
          this.loadOrganizations();
        },
        error: (err) => console.error('Failed to update organization:', err)
      });
    } else {
      this.api.post('/api/organizations', payload).subscribe({
        next: () => {
          this.closeModal();
          this.loadOrganizations();
        },
        error: (err) => console.error('Failed to create organization:', err)
      });
    }
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
