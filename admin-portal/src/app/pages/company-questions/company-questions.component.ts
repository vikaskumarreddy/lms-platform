import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { DomSanitizer, SafeResourceUrl } from '@angular/platform-browser';
import { ApiService } from '../../services/api.service';
import { ApiErrorService } from '../../services/api-error.service';
import { MediaService, MediaItem } from '../../services/media.service';
import { ConfirmService } from '../../services/confirm.service';

interface CompanyKit {
  id: number;
  companyName: string;
  logoUrl?: string;
  tags?: string;
  mode: 'CONTENT' | 'PDF';
  pdfUrl?: string;
  pdfSource?: 'URL' | 'SELF';
  pdfNoteId?: number | null;
  description?: string;
  isPublished: boolean;
  createdAt?: string;
}

/**
 * "Company Questions" tiles. Each tile is either a full in-app question paper
 * (managed via the existing assessment-paper builder under type=company-kit) or
 * a pasted PDF URL that students view through the mobile in-app browser.
 */
@Component({
  selector: 'app-company-questions',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  template: `
    <div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:24px;gap:16px;flex-wrap:wrap;">
      <div>
        <h1 style="font-size:24px;font-weight:700;">🏢 Company Questions</h1>
        <div style="color:#64748B;font-size:13px;margin-top:4px;">Company-specific practice papers and PDFs for students.</div>
      </div>
      <button class="btn btn-primary" (click)="openAdd()">+ Add Company</button>
    </div>

    <div style="margin-bottom:16px;">
      <input type="text" [(ngModel)]="search" placeholder="🔍 Search by company name or tag..." style="max-width:360px;">
    </div>

    <div *ngIf="loading" class="card" style="text-align:center;padding:32px;color:#64748B;">Loading…</div>

    <div *ngIf="!loading && filteredKits.length === 0" class="card" style="text-align:center;padding:48px;color:#64748B;">
      <div style="font-size:40px;margin-bottom:8px;">🏢</div>
      <div style="font-weight:600;color:#134E4A;margin-bottom:4px;">No company tiles yet</div>
      <div style="font-size:13px;margin-bottom:16px;">Add a company and give students a content paper or a PDF to practice with.</div>
      <button class="btn btn-primary" (click)="openAdd()">+ Add Company</button>
    </div>

    <div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:16px;">
      <div class="card" *ngFor="let kit of filteredKits">
        <div style="display:flex;align-items:center;gap:10px;margin-bottom:10px;">
          <img *ngIf="kit.logoUrl" [src]="kit.logoUrl" alt="" style="width:40px;height:40px;border-radius:8px;object-fit:cover;background:#F1F5F9;">
          <div *ngIf="!kit.logoUrl" style="width:40px;height:40px;border-radius:8px;background:#EEF2FF;display:flex;align-items:center;justify-content:center;font-weight:700;color:#4338CA;">
            {{kit.companyName.charAt(0).toUpperCase()}}
          </div>
          <div style="flex:1;">
            <div style="font-weight:700;color:#134E4A;">{{kit.companyName}}</div>
            <span class="badge" [style.background]="kit.mode === 'PDF' ? '#FEF3C7' : '#CCFBF1'"
                  [style.color]="kit.mode === 'PDF' ? '#92400E' : '#134E4A'">
              {{kit.mode === 'PDF' ? '📄 PDF' : '📝 Content'}}
            </span>
          </div>
        </div>

        <div *ngIf="kit.tags" style="margin-bottom:8px;display:flex;flex-wrap:wrap;gap:6px;">
          <span class="badge" style="background:#F1F5F9;color:#475569;" *ngFor="let tag of kit.tags.split(',')">{{tag.trim()}}</span>
        </div>

        <div *ngIf="kit.description" style="font-size:13px;color:#64748B;margin-bottom:10px;">{{kit.description}}</div>

        <div style="display:flex;align-items:center;gap:8px;margin-bottom:10px;">
          <span class="badge" [class.badge-success]="kit.isPublished" [class.badge-warning]="!kit.isPublished">
            {{kit.isPublished ? 'Published' : 'Draft'}}
          </span>
        </div>

        <div style="display:flex;gap:6px;flex-wrap:wrap;">
          <button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;" *ngIf="kit.mode === 'CONTENT'" (click)="manageQuestions(kit)">Manage Questions</button>
          <button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;" *ngIf="kit.mode === 'PDF' && kit.pdfSource === 'SELF' && kit.pdfNoteId" (click)="viewSelfPdf(kit.pdfNoteId)">View</button>
          <a class="btn btn-secondary" style="padding:4px 12px;font-size:12px;" *ngIf="kit.mode === 'PDF' && kit.pdfSource !== 'SELF' && kit.pdfUrl" [href]="kit.pdfUrl" target="_blank" rel="noopener">View</a>
          <button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;" (click)="openEdit(kit)">Edit</button>
          <button class="btn" style="background:#FEE2E2;color:#991B1B;padding:4px 12px;font-size:12px;" (click)="deleteKit(kit)">Delete</button>
        </div>
      </div>
    </div>

    <!-- ===================== Add / Edit popup ===================== -->
    <div class="modal-overlay" *ngIf="showModal" (click)="closeModal($event)">
      <div class="modal-content" style="width:90%;max-width:640px;" (click)="$event.stopPropagation()">
        <form (ngSubmit)="save()">
          <fieldset>
            <legend>{{editingId ? 'Edit Company' : 'Add New Company'}}</legend>
            <div class="popup-form-grid">
              <div class="full-width">
                <label>Company name *</label>
                <input type="text" [(ngModel)]="form.companyName" name="companyName" required placeholder="e.g. TCS, Infosys">
              </div>

              <div>
                <label>Logo URL</label>
                <input type="text" [(ngModel)]="form.logoUrl" name="logoUrl" placeholder="https://...">
              </div>

              <div>
                <label>Tags (comma separated)</label>
                <input type="text" [(ngModel)]="form.tags" name="tags" placeholder="e.g. IT, Product, Service">
              </div>

              <div class="full-width">
                <label>Mode</label>
                <div style="display:flex;gap:20px;padding-top:4px;flex-wrap:wrap;">
                  <label style="display:flex;align-items:center;gap:7px;margin:0;cursor:pointer;font-weight:500;">
                    <input type="radio" name="mode" value="CONTENT" [(ngModel)]="form.mode" style="width:auto;margin:0;">
                    Content (question paper inside the app)
                  </label>
                  <label style="display:flex;align-items:center;gap:7px;margin:0;cursor:pointer;font-weight:500;">
                    <input type="radio" name="mode" value="PDF" [(ngModel)]="form.mode" style="width:auto;margin:0;">
                    PDF
                  </label>
                </div>
              </div>

              <div class="full-width" *ngIf="form.mode === 'PDF'">
                <label>PDF Source</label>
                <div style="display:flex;gap:20px;padding-top:4px;flex-wrap:wrap;">
                  <label style="display:flex;align-items:center;gap:7px;margin:0;cursor:pointer;font-weight:500;">
                    <input type="radio" name="pdfSource" value="URL" [(ngModel)]="form.pdfSource" style="width:auto;margin:0;">
                    URL
                  </label>
                  <label style="display:flex;align-items:center;gap:7px;margin:0;cursor:pointer;font-weight:500;">
                    <input type="radio" name="pdfSource" value="SELF" [(ngModel)]="form.pdfSource" style="width:auto;margin:0;">
                    Self-hosted
                  </label>
                </div>
              </div>

              <div class="full-width" *ngIf="form.mode === 'PDF' && form.pdfSource === 'URL'">
                <label>PDF URL *</label>
                <input type="text" [(ngModel)]="form.pdfUrl" name="pdfUrl" placeholder="https://example.com/paper.pdf">
              </div>

              <div class="full-width" *ngIf="form.mode === 'PDF' && form.pdfSource === 'SELF'">
                <label>Uploaded PDF *</label>
                <div style="display:flex;gap:8px;align-items:center;" *ngIf="mediaFiles.length">
                  <select [(ngModel)]="form.pdfNoteId" name="pdfNoteId" style="flex:1;padding:10px 14px;border:1px solid var(--border-light);border-radius:8px;font-size:14px;font-family:inherit;color:var(--text);background:var(--surface)">
                    <option [ngValue]="null">Select an uploaded PDF…</option>
                    <option *ngFor="let n of mediaFiles" [ngValue]="n.id">{{ n.title }}</option>
                  </select>
                  <button type="button" class="btn btn-secondary" style="padding:8px 14px;font-size:12px;white-space:nowrap;"
                          [disabled]="!form.pdfNoteId" (click)="viewSelfPdf(form.pdfNoteId)">View</button>
                </div>
                <div *ngIf="!mediaFiles.length" style="font-size:12px;color:#B45309;margin-top:6px;">
                  You have no files uploaded yet — <a routerLink="/media-hub">upload media</a> first.
                </div>
                <div *ngIf="mediaFiles.length" style="font-size:12px;color:#64748B;margin-top:6px;">
                  Students see your uploaded PDF, stored compressed and served through the platform.
                </div>
              </div>


              <div class="full-width">
                <label>Description</label>
                <textarea [(ngModel)]="form.description" name="description" rows="2" placeholder="Shown to students on the tile"></textarea>
              </div>

              <div class="full-width">
                <label style="display:flex;align-items:center;gap:8px;cursor:pointer;">
                  <input type="checkbox" [(ngModel)]="form.isPublished" name="isPublished" style="width:auto;margin:0;">
                  Published (visible to students)
                </label>
              </div>
            </div>
          </fieldset>

          <div class="popup-nav">
            <button type="submit" class="btn btn-accent" [disabled]="saving">
              {{saving ? 'Saving...' : (editingId ? 'Update Company' : 'Add Company')}}
            </button>
            <span style="flex:1"></span>
            <button type="button" class="btn btn-danger" (click)="closeModal()">Cancel</button>
          </div>
        </form>

        <div *ngIf="modalError" style="margin-top:16px;padding:12px;background:#FEE2E2;color:#991B1B;border-radius:8px;font-size:14px;">
          {{modalError}}
        </div>
      </div>
    </div>

    <!-- ===================== View PDF popup ===================== -->
    <div class="modal-overlay" *ngIf="viewingPdf" (click)="closeMediaView()">
      <div class="modal-content" style="width:90%;max-width:900px;max-height:90vh;overflow:auto;" (click)="$event.stopPropagation()">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;">
          <h3 style="font-weight:700;color:#134E4A;margin:0;">{{ viewingPdf.title }}</h3>
          <button class="btn btn-secondary" style="padding:2px 10px;font-size:16px;line-height:1;" (click)="closeMediaView()">✕</button>
        </div>
        <iframe [src]="viewingPdfSafeUrl" style="width:100%;height:75vh;border:1px solid #E2E8F0;border-radius:8px;" title="PDF viewer"></iframe>
      </div>
    </div>
  `
})
export class CompanyQuestionsComponent implements OnInit {
  private api = inject(ApiService);
  private confirm = inject(ConfirmService);
  private errors = inject(ApiErrorService);
  private router = inject(Router);
  private media = inject(MediaService);
  private sanitizer = inject(DomSanitizer);

  kits: CompanyKit[] = [];
  mediaFiles: MediaItem[] = [];
  loading = true;
  search = '';
  viewingPdf: MediaItem | null = null;
  viewingPdfSafeUrl: SafeResourceUrl | null = null;

  showModal = false;
  editingId: number | null = null;
  saving = false;
  modalError = '';
  form: { companyName: string; logoUrl: string; tags: string; mode: 'CONTENT' | 'PDF'; pdfSource: 'URL' | 'SELF'; pdfNoteId: number | null; pdfUrl: string; description: string; isPublished: boolean } = this.blankForm();

  get filteredKits(): CompanyKit[] {
    const q = this.search.trim().toLowerCase();
    if (!q) return this.kits;
    return this.kits.filter(k =>
      k.companyName.toLowerCase().includes(q) || (k.tags || '').toLowerCase().includes(q));
  }

  ngOnInit() {
    this.load();
    this.loadMediaFiles();
  }

  private blankForm() {
    return { companyName: '', logoUrl: '', tags: '', mode: 'CONTENT' as 'CONTENT' | 'PDF', pdfSource: 'URL' as 'URL' | 'SELF', pdfNoteId: null as number | null, pdfUrl: '', description: '', isPublished: true };
  }

  /** Uploaded PDF files power the "Self-hosted" dropdown. */
  loadMediaFiles() {
    this.media.list('file').subscribe({
      next: (data) => { this.mediaFiles = data || []; },
      error: () => { this.mediaFiles = []; }
    });
  }

  viewSelfPdf(id: number | null) {
    if (!id) return;
    const item = this.mediaFiles.find(f => f.id === id) || null;
    this.viewingPdf = item;
    if (item) this.viewingPdfSafeUrl = this.sanitizer.bypassSecurityTrustResourceUrl(this.media.serveUrl(item.id));
  }

  closeMediaView() { this.viewingPdf = null; this.viewingPdfSafeUrl = null; }

  load() {
    this.loading = true;
    this.api.get<CompanyKit[]>('/api/company-kits').subscribe({
      next: (data) => { this.kits = data || []; this.loading = false; },
      error: (err) => { this.loading = false; this.errors.show(err, 'Could not load company tiles'); }
    });
  }

  manageQuestions(kit: CompanyKit) {
    this.router.navigate(['/assessment-paper', 'company-kit', kit.id]);
  }

  openAdd() {
    this.editingId = null;
    this.form = this.blankForm();
    this.modalError = '';
    this.showModal = true;
  }

  openEdit(kit: CompanyKit) {
    this.editingId = kit.id;
    this.form = {
      companyName: kit.companyName,
      logoUrl: kit.logoUrl || '',
      tags: kit.tags || '',
      mode: kit.mode,
      pdfSource: kit.pdfSource === 'SELF' ? 'SELF' : 'URL',
      pdfNoteId: kit.pdfNoteId ?? null,
      pdfUrl: kit.pdfUrl || '',
      description: kit.description || '',
      isPublished: kit.isPublished
    };
    this.modalError = '';
    this.showModal = true;
  }

  closeModal(event?: Event) {
    if (event && event.target !== event.currentTarget) return;
    this.showModal = false;
    this.editingId = null;
    this.saving = false;
    this.modalError = '';
  }

  save() {
    this.modalError = '';
    if (!this.form.companyName || !this.form.companyName.trim()) { this.modalError = 'Company name is required'; return; }
    if (this.form.mode === 'PDF' && this.form.pdfSource === 'URL' && (!this.form.pdfUrl || !this.form.pdfUrl.trim())) { this.modalError = 'PDF URL is required'; return; }
    if (this.form.mode === 'PDF' && this.form.pdfSource === 'SELF' && !this.form.pdfNoteId) { this.modalError = 'Choose one of your PDF notes'; return; }

    const payload = {
      companyName: this.form.companyName.trim(),
      logoUrl: this.form.logoUrl?.trim() || null,
      tags: this.form.tags?.trim() || null,
      mode: this.form.mode,
      pdfSource: this.form.mode === 'PDF' ? this.form.pdfSource : null,
      pdfNoteId: this.form.mode === 'PDF' && this.form.pdfSource === 'SELF' ? this.form.pdfNoteId : null,
      pdfUrl: this.form.mode === 'PDF' && this.form.pdfSource === 'URL' ? this.form.pdfUrl.trim() : null,
      description: this.form.description?.trim() || null,
      isPublished: this.form.isPublished
    };

    this.saving = true;
    const request$ = this.editingId
      ? this.api.put<any>(`/api/company-kits/${this.editingId}`, payload)
      : this.api.post<any>('/api/company-kits', payload);

    request$.subscribe({
      next: () => { this.saving = false; this.showModal = false; this.editingId = null; this.load(); },
      error: (err) => { this.saving = false; this.modalError = err?.error?.error || err?.error?.message || 'Failed to save the company tile'; }
    });
  }

  async deleteKit(kit: CompanyKit) {
    if (!(await this.confirm.confirm(`Delete "${kit.companyName}"? This also removes its questions if any.`))) return;
    this.api.delete(`/api/company-kits/${kit.id}`).subscribe({
      next: () => this.load(),
      error: (err) => this.errors.show(err, 'Failed to delete the company tile')
    });
  }
}
