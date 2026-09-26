import { Component, OnInit, inject, signal, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { DomSanitizer, SafeResourceUrl } from '@angular/platform-browser';
import { MediaService, MediaItem, MediaType, compressionLabel } from '../../services/media.service';
import { ConfirmService } from '../../services/confirm.service';
import { QuotaModalService } from '../../services/quota-modal.service';

const VIDEO_TYPES = ['video/mp4', 'video/webm', 'video/quicktime', 'video/x-msvideo'];
const FILE_TYPES = ['application/pdf', 'image/png', 'image/jpeg', 'image/webp', 'image/gif'];

@Component({
  selector: 'app-media-hub',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:20px;gap:16px;flex-wrap:wrap;">
      <div>
        <h1 style="font-size:24px;font-weight:700;">🎬 Media & Files</h1>
        <div style="color:#64748B;font-size:13px;margin-top:4px;">Upload videos & files — stored compressed, enhanced on playback. Used by courses and company questions.</div>
      </div>
    </div>
    <div style="display:flex;gap:0;margin-bottom:20px;border-bottom:2px solid #E2E8F0;">
      <button class="tab-btn" [class.active]="activeTab()==='video'" (click)="setTab('video')">📹 Videos <span class="tab-count">{{videos().length}}</span></button>
      <button class="tab-btn" [class.active]="activeTab()==='file'" (click)="setTab('file')">📄 Files <span class="tab-count">{{files().length}}</span></button>
    </div>
    <div class="upload-zone" [class.dragover]="dragover()" (dragover)="$event.preventDefault(); dragover.set(true)" (dragleave)="dragover.set(false)" (drop)="onDrop($event)">
      <input #fileInput type="file" [accept]="accept()" hidden (change)="onPick($event)" />
      <div style="font-size:36px;margin-bottom:8px;">☁️</div>
      <div style="font-weight:600;color:#134E4A;margin-bottom:4px;">Drag & drop {{activeTab()=== 'video' ? 'videos' : "files"}} here</div>
      <div style="font-size:13px;color:#64748B;margin-bottom:12px;">or</div>
      <button class="btn btn-primary" (click)="fileInput.click()">Choose {{activeTab()=== 'video' ? 'Video' : "File"}} to Upload</button>
      <div style="font-size:12px;color:#94A3B8;margin-top:10px;">{{activeTab()=== 'video' ? 'MP4, WebM, MOV · up to 30MB · stored compressed' : "PDF, PNG, WebP, JPEG · up to 60MB · compressed to small size"}}</div>
    </div>
    <div *ngIf="uploading()" class="card" style="margin-bottom:16px;padding:14px 16px;">
      <div style="display:flex;justify-content:space-between;margin-bottom:6px;"><span style="font-weight:600;color:#134E4A;font-size:13px;">Uploading {{uploadName()}}…</span><span style="font-size:13px;color:#134E4A;font-weight:600;">{{uploadPct()}}%</span></div>
      <div style="height:8px;background:#E2E8F0;border-radius:4px;overflow:hidden;"><div style="height:100%;background:#0D9488;border-radius:4px;transition:width .2s;" [style.width.%]="uploadPct()"></div></div>
    </div>
    <div *ngIf="error()" class="card" style="margin-bottom:16px;padding:12px 16px;background:#FEF2F2;border:1px solid #FECACA;color:#991B1B;font-size:13px;">⚠️ {{error()}}</div>
    <div *ngIf="!loading() && currentItems().length === 0 && !uploading()" class="card" style="text-align:center;padding:48px;color:#64748B;">
      <div style="font-size:40px;margin-bottom:8px;">📭</div>
      <div style="font-weight:600;color:#134E4A;margin-bottom:4px;">No {{activeTab()=== 'video' ? 'videos' : "files"}} uploaded yet</div>
      <div style="font-size:13px;margin-bottom:16px;">Upload once — reuse them across courses and company questions.</div>
      <button class="btn btn-primary" (click)="fileInput.click()">Upload {{activeTab()=== 'video' ? 'Video' : "File"}}</button>
    </div>
    <div *ngIf="loading()" class="card" style="text-align:center;padding:32px;color:#64748B;">Loading…</div>
    <div *ngIf="currentItems().length > 0" style="display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:16px;margin-top:16px;">
      <div class="card" *ngFor="let item of currentItems()" style="padding:14px;">
        <div style="display:flex;align-items:flex-start;gap:10px;margin-bottom:10px;">
          <div style="width:44px;height:44px;border-radius:8px;background:#EEF2FF;display:flex;align-items:center;justify-content:center;font-size:22px;flex-shrink:0;">{{item.type === 'video' ? '🎬' : (isPdf(item) ? '📄' : "🖼️")}}</div>
          <div style="flex:1;min-width:0;"><div style="font-weight:700;color:#134E4A;font-size:14px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;" [title]="item.title">{{item.title}}</div><div style="font-size:12px;color:#64748B;margin-top:2px;">{{item.mimeType || item.type}}</div></div>
        </div>
        <div style="font-size:12px;color:#047857;margin-bottom:10px;font-weight:500;">{{compressionLabel(item.originalSize, item.storedSize)}}<span *ngIf="item.duration" style="color:#64748B;"> · {{item.duration}}s</span></div>
        <div style="display:flex;gap:6px;flex-wrap:wrap;">
          <button class="btn btn-secondary" style="padding:4px 10px;font-size:12px;" (click)="viewItem(item)">View</button>
          <button class="btn btn-secondary" style="padding:4px 10px;font-size:12px;" (click)="copyLink(item)">Copy Link</button>
          <button class="btn" style="background:#FEE2E2;color:#991B1B;padding:4px 10px;font-size:12px;" (click)="deleteItem(item)">Delete</button>
        </div>
      </div>
    </div>
    <div *ngIf="viewing()" class="modal-backdrop" (click)="closeView($event)">
      <div class="modal-content" (click)="$event.stopPropagation()">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;"><h3 style="font-weight:700;color:#134E4A;margin:0;">{{viewing()?.title}}</h3><button class="btn btn-secondary" style="padding:2px 10px;font-size:16px;line-height:1;" (click)="closeView()">✕</button></div>
        <div *ngIf="viewing()?.type === 'video'" style="background:#000;border-radius:8px;overflow:hidden;"><video [src]="media.serveUrl(viewing()!.id)" controls autoplay style="width:100%;max-height:70vh;display:block;"></video></div>
        <div *ngIf="viewing()?.type === 'file' && isPdf(viewing()!)"><iframe [src]="pdfSafeUrl()" style="width:100%;height:75vh;border:1px solid #E2E8F0;border-radius:8px;" title="PDF viewer"></iframe></div>
        <div *ngIf="viewing()?.type === 'file' && !isPdf(viewing()!)"><img [src]="media.serveUrl(viewing()!.id)" style="max-width:100%;max-height:70vh;display:block;margin:0 auto;border-radius:8px;" [alt]="viewing()!.title" /></div>
      </div>
    </div>
  `,
  styles: [`
    .tab-btn { border:0;background:none;padding:10px 20px;font-size:14px;font-weight:600;color:#64748B;cursor:pointer;border-bottom:2px solid transparent;margin-bottom:-2px;transition:all .15s; }
    .tab-btn.active { color:#0D9488;border-bottom-color:#0D9488; }
    .tab-count { background:#E2E8F0;color:#475569;font-size:11px;padding:1px 7px;border-radius:10px;margin-left:4px; }
    .tab-btn.active .tab-count { background:#CCFBF1;color:#134E4A; }
    .upload-zone { border:2px dashed #CBD5E1;border-radius:12px;padding:32px;text-align:center;transition:all .15s;background:#FAFAF9; }
    .upload-zone.dragover { border-color:#0D9488;background:#F0FDFA; }
    .modal-backdrop { position:fixed;inset:0;background:rgba(2,6,23,.65);z-index:1000;display:flex;align-items:center;justify-content:center;padding:24px; }
    .modal-content { background:var(--surface);color:var(--text);border-radius:12px;padding:20px;max-width:900px;width:100%;max-height:90vh;overflow:auto;box-shadow:0 20px 60px rgba(2,6,23,.4); }
  `]
})
export class MediaHubComponent implements OnInit {
  private sanitizer = inject(DomSanitizer);
  private confirm = inject(ConfirmService);
  private quotaModal = inject(QuotaModalService);
  protected media = inject(MediaService);
  activeTab = signal<MediaType>('video');
  videos = signal<MediaItem[]>([]);
  files = signal<MediaItem[]>([]);
  loading = signal(false);
  dragover = signal(false);
  uploading = signal(false);
  uploadPct = signal(0);
  uploadName = signal('');
  error = signal('');
  viewing = signal<MediaItem | null>(null);
  pdfSafeUrl = signal<SafeResourceUrl | null>(null);

  currentItems = computed(() => this.activeTab() === 'video' ? this.videos() : this.files());
  accept = computed(() => this.activeTab() === 'video' ? VIDEO_TYPES.join(',') : FILE_TYPES.join(','));
  protected compressionLabel = compressionLabel;

  ngOnInit() { this.load(); }

  setTab(t: MediaType) { this.activeTab.set(t); this.error.set(''); }

  private load() {
    this.loading.set(true);
    this.media.list().subscribe({ next: (items) => { this.videos.set(items.filter(i => i.type === 'video')); this.files.set(items.filter(i => i.type === 'file')); this.loading.set(false); }, error: () => this.loading.set(false) });
  }

  onDrop(e: DragEvent) { e.preventDefault(); this.dragover.set(false); const f = e.dataTransfer?.files?.[0]; if (f) this.uploadFile(f); }
  onPick(e: Event) { const f = (e.target as HTMLInputElement).files?.[0]; if (f) this.uploadFile(f); (e.target as HTMLInputElement).value = ''; }

  private uploadFile(file: File) {
    const type = this.activeTab();
    if (type === 'video' && !file.type.startsWith('video/')) { this.error.set('Please choose a video file.'); return; }
    if (type === 'file' && !FILE_TYPES.includes(file.type)) { this.error.set('Please choose a PDF or image file.'); return; }
    // Instant feedback instead of waiting on a round-trip — mirrors the
    // server's MAX_VIDEO_BYTES/MAX_FILE_BYTES caps in MediaController.
    const maxBytes = type === 'video' ? 30 * 1024 * 1024 : 60 * 1024 * 1024;
    if (file.size > maxBytes) {
      const limit = type === 'video' ? '30MB' : '60MB';
      this.error.set(`"${file.name}" is too large (${(file.size / 1048576).toFixed(1)}MB). ${type === 'video' ? 'Videos' : 'Files'} must be ${limit} or smaller.`);
      return;
    }
    this.error.set(''); this.uploading.set(true); this.uploadPct.set(0); this.uploadName.set(file.name);
    this.media.uploadWithProgress(file, type, (pct) => this.uploadPct.set(pct))
      .then((item) => {
        this.uploading.set(false);
        if (type === 'video') this.videos.update(list => [item, ...list]);
        else this.files.update(list => [item, ...list]);
      })
      .catch((err) => {
        this.uploading.set(false);
        const handled = this.quotaModal.handleError(err, 'Storage Limit Reached');
        if (!handled) {
          this.error.set(err.message || 'Upload failed');
        }
      });
  }

  isPdf(item: MediaItem | null): boolean { return !!item && (item.mimeType || '').includes('pdf'); }

  viewItem(item: MediaItem) {
    this.viewing.set(item);
    if (item.type === 'file' && this.isPdf(item)) {
      this.pdfSafeUrl.set(this.sanitizer.bypassSecurityTrustResourceUrl(this.media.serveUrl(item.id)));
    }
  }

  closeView(e?: Event) { if (e && e.target !== e.currentTarget) return; this.viewing.set(null); this.pdfSafeUrl.set(null); }

  copyLink(item: MediaItem) { const url = window.location.origin + this.media.serveUrl(item.id); navigator.clipboard?.writeText(url).catch(() => {}); }

  async deleteItem(item: MediaItem) {
    if (!(await this.confirm.confirm('Delete "' + item.title + '"? References to it will break.'))) return;
    this.media.delete(item.id).subscribe({ next: () => { if (item.type === 'video') this.videos.update(list => list.filter(i => i.id !== item.id)); else this.files.update(list => list.filter(i => i.id !== item.id)); }, error: () => this.error.set('Could not delete the item') });
  }
}
