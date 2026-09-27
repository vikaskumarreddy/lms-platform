import { Component, OnInit, inject, signal, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { DomSanitizer, SafeResourceUrl } from '@angular/platform-browser';
import { MediaService, MediaItem, MediaType, compressionLabel } from '../../services/media.service';
import { ConfirmService } from '../../services/confirm.service';
import { QuotaModalService } from '../../services/quota-modal.service';

const VIDEO_TYPES = ['video/mp4', 'video/webm', 'video/quicktime', 'video/x-msvideo'];
const FILE_TYPES = ['application/pdf', 'image/png', 'image/jpeg', 'image/webp', 'image/gif'];

export interface MediaFolder {
  id: string;
  name: string;
  icon: string;
  color?: string;
  isSystem?: boolean;
  description?: string;
}

const DEFAULT_FOLDERS: MediaFolder[] = [
  { id: 'all', name: 'All Files', icon: '📁', isSystem: true, description: 'All uploaded media across folders' },
  { id: 'unorganized', name: 'Unorganized', icon: '📥', isSystem: true, description: 'Files not yet categorized into a folder' },
  { id: 'lessons', name: 'Course Lessons', icon: '🎬', isSystem: false, color: '#4F46E5', description: 'Videos & lecture recordings for course lessons' },
  { id: 'docs', name: 'Study Materials', icon: '📚', isSystem: false, color: '#0D9488', description: 'PDF notes, textbooks, and documentation' },
  { id: 'branding', name: 'Logos & Branding', icon: '🖼️', isSystem: false, color: '#E11D48', description: 'Organization logos, badges, and marketing images' },
  { id: 'assignments', name: 'Exams & Notes', icon: '📝', isSystem: false, color: '#D97706', description: 'Problem statements, attachments, and exams' }
];

const FOLDER_STORAGE_KEY = 'lms_media_folders_v1';
const FILE_MAP_STORAGE_KEY = 'lms_media_file_folder_map_v1';

@Component({
  selector: 'app-media-hub',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <!-- Top Header -->
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:20px;gap:16px;flex-wrap:wrap;">
      <div>
        <h1 style="font-size:24px;font-weight:700;margin:0;display:flex;align-items:center;gap:8px;">
          <span>🎬</span> Media & Files Manager
        </h1>
        <div style="color:#64748B;font-size:13px;margin-top:4px;">
          Organize media in custom folders, upload compressed videos & documents, and reuse across courses.
        </div>
      </div>
      <div style="display:flex;align-items:center;gap:10px;">
        <button class="btn btn-secondary" style="display:flex;align-items:center;gap:6px;" (click)="openCreateFolderModal()">
          <span>📁</span> + New Folder
        </button>
        <button class="btn btn-primary" style="display:flex;align-items:center;gap:6px;" (click)="fileInput.click()">
          <span>⬆</span> Upload {{activeTab() === 'video' ? 'Video' : (activeTab() === 'file' ? 'File' : 'Media')}}
        </button>
      </div>
    </div>

    <!-- Folder Navigation Strip / Breadcrumbs -->
    <div class="card" style="margin-bottom:20px;padding:14px 16px;background:#FFFFFF;border:1px solid #E2E8F0;border-radius:12px;">
      <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:12px;flex-wrap:wrap;gap:10px;">
        <div style="display:flex;align-items:center;gap:8px;font-size:13px;font-weight:600;color:#0F172A;">
          <span style="color:#64748B;">Folders:</span>
          <button *ngIf="activeFolderId() !== 'all'" class="btn btn-secondary" style="padding:2px 8px;font-size:11px;" (click)="setFolder('all')">
            ← View All Files
          </button>
          <span *ngIf="activeFolderId() !== 'all'" style="color:#94A3B8;">›</span>
          <span *ngIf="activeFolderId() !== 'all'" style="color:#0D9488;display:flex;align-items:center;gap:4px;">
            <span>{{activeFolder().icon}}</span> {{activeFolder().name}}
          </span>
        </div>
        <div *ngIf="!activeFolder().isSystem" style="display:flex;align-items:center;gap:8px;">
          <button class="btn btn-secondary" style="padding:3px 8px;font-size:11px;" (click)="openRenameFolderModal(activeFolder())">
            ✏️ Rename Folder
          </button>
          <button class="btn" style="background:#FEE2E2;color:#991B1B;padding:3px 8px;font-size:11px;" (click)="deleteFolder(activeFolder())">
            🗑️ Delete Folder
          </button>
        </div>
      </div>

      <!-- Folder Pills Horizontal Scroll -->
      <div class="folder-scroll-row">
        <button *ngFor="let f of folders()"
                class="folder-chip"
                [class.active]="activeFolderId() === f.id"
                (click)="setFolder(f.id)">
          <span class="folder-icon">{{f.icon}}</span>
          <span class="folder-name">{{f.name}}</span>
          <span class="folder-count">{{getFolderCount(f.id)}}</span>
        </button>
      </div>
    </div>

    <!-- Upload Drop Zone with Active Folder Destination -->
    <div class="upload-zone" [class.dragover]="dragover()"
         (dragover)="$event.preventDefault(); dragover.set(true)"
         (dragleave)="dragover.set(false)"
         (drop)="onDrop($event)">
      <input #fileInput type="file" [accept]="accept()" hidden (change)="onPick($event)" />
      <div style="font-size:32px;margin-bottom:6px;">☁️</div>
      <div style="font-weight:700;color:#134E4A;font-size:15px;margin-bottom:4px;">
        Drag & drop {{activeTab() === 'video' ? 'videos' : (activeTab() === 'file' ? 'files' : 'media')}} here
      </div>
      <div style="font-size:13px;color:#64748B;margin-bottom:10px;">or</div>
      <div style="display:flex;justify-content:center;align-items:center;gap:10px;flex-wrap:wrap;">
        <button class="btn btn-primary" (click)="fileInput.click()">
          Choose {{activeTab() === 'video' ? 'Video' : 'File'}} to Upload
        </button>
        <span *ngIf="activeFolderId() !== 'all'" class="badge" style="background:#CCFBF1;color:#115E59;font-size:12px;padding:6px 12px;border-radius:8px;">
          Saving into: {{activeFolder().icon}} {{activeFolder().name}}
        </span>
      </div>
      <div style="font-size:12px;color:#94A3B8;margin-top:10px;">
        Videos: MP4, WebM, MOV (up to 30MB) · Files: PDF, PNG, WebP, JPEG (up to 60MB) · Automatically stored compressed
      </div>
    </div>

    <!-- Upload Progress Bar -->
    <div *ngIf="uploading()" class="card" style="margin-top:16px;margin-bottom:16px;padding:14px 16px;">
      <div style="display:flex;justify-content:space-between;margin-bottom:6px;">
        <span style="font-weight:600;color:#134E4A;font-size:13px;">Uploading {{uploadName()}}…</span>
        <span style="font-size:13px;color:#134E4A;font-weight:600;">{{uploadPct()}}%</span>
      </div>
      <div style="height:8px;background:#E2E8F0;border-radius:4px;overflow:hidden;">
        <div style="height:100%;background:#0D9488;border-radius:4px;transition:width .2s;" [style.width.%]="uploadPct()"></div>
      </div>
    </div>

    <!-- Error Banner -->
    <div *ngIf="error()" class="card" style="margin-top:16px;margin-bottom:16px;padding:12px 16px;background:#FEF2F2;border:1px solid #FECACA;color:#991B1B;font-size:13px;">
      ⚠️ {{error()}}
    </div>

    <!-- Filter & Search Toolbar -->
    <div class="card" style="margin-top:20px;padding:14px 16px;background:#FFFFFF;border:1px solid #E2E8F0;border-radius:12px;display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:12px;">
      <!-- Type Tabs -->
      <div style="display:flex;align-items:center;gap:4px;">
        <button class="filter-tab-btn" [class.active]="activeTab() === 'all'" (click)="setTab('all')">
          All Media <span class="tab-count">{{totalItemCount()}}</span>
        </button>
        <button class="filter-tab-btn" [class.active]="activeTab() === 'video'" (click)="setTab('video')">
          📹 Videos <span class="tab-count">{{videoCount()}}</span>
        </button>
        <button class="filter-tab-btn" [class.active]="activeTab() === 'file'" (click)="setTab('file')">
          📄 Files <span class="tab-count">{{fileCount()}}</span>
        </button>
      </div>

      <!-- Search & Page Size -->
      <div style="display:flex;align-items:center;gap:10px;flex:1;max-width:420px;justify-content:flex-end;">
        <div style="position:relative;flex:1;min-width:180px;">
          <input type="text"
                 [ngModel]="searchQuery()"
                 (ngModelChange)="onSearchChange($event)"
                 placeholder="Search by filename or title…"
                 class="form-control"
                 style="padding:6px 12px 6px 30px;font-size:13px;border-radius:8px;width:100%;" />
          <span style="position:absolute;left:10px;top:50%;transform:translateY(-50%);font-size:13px;color:#94A3B8;">🔍</span>
        </div>

        <div style="display:flex;align-items:center;gap:6px;font-size:12px;color:#64748B;white-space:nowrap;">
          <span>Per page:</span>
          <select [ngModel]="pageSize()" (ngModelChange)="setPageSize($event)"
                  class="form-control" style="width:auto;padding:4px 8px;font-size:12px;height:auto;border-radius:6px;">
            <option [ngValue]="8">8</option>
            <option [ngValue]="9">9</option>
            <option [ngValue]="10">10</option>
            <option [ngValue]="20">20</option>
          </select>
        </div>
      </div>
    </div>

    <!-- Empty State -->
    <div *ngIf="!loading() && filteredItems().length === 0 && !uploading()" class="card" style="text-align:center;padding:48px;color:#64748B;margin-top:16px;">
      <div style="font-size:40px;margin-bottom:8px;">📭</div>
      <div style="font-weight:700;color:#134E4A;font-size:16px;margin-bottom:4px;">
        No files found in {{activeFolder().name}}
      </div>
      <div style="font-size:13px;margin-bottom:16px;">
        {{searchQuery() ? 'No files match your search criteria.' : 'Upload videos or documents to this folder to start building your library.'}}
      </div>
      <button class="btn btn-primary" (click)="fileInput.click()">
        Upload to {{activeFolder().name}}
      </button>
    </div>

    <!-- Loading State -->
    <div *ngIf="loading()" class="card" style="text-align:center;padding:40px;color:#64748B;margin-top:16px;">
      Loading media library…
    </div>

    <!-- Media Grid (Paginated) -->
    <div *ngIf="!loading() && paginatedItems().length > 0"
         style="display:grid;grid-template-columns:repeat(auto-fill,minmax(270px,1fr));gap:16px;margin-top:16px;">
      <div class="card media-card" *ngFor="let item of paginatedItems()">
        <!-- Card Header / Type Thumbnail -->
        <div style="display:flex;align-items:flex-start;gap:12px;margin-bottom:10px;">
          <div class="media-thumb-preview">
            <span *ngIf="item.type === 'video'">🎬</span>
            <span *ngIf="item.type === 'file' && isPdf(item)">📄</span>
            <img *ngIf="item.type === 'file' && !isPdf(item)" [src]="media.serveUrl(item.id)" [alt]="item.title" (error)="onThumbError($event)" />
          </div>
          <div style="flex:1;min-width:0;">
            <div style="font-weight:700;color:#0F172A;font-size:14px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;" [title]="item.title">
              {{item.title}}
            </div>
            <div style="font-size:12px;color:#64748B;margin-top:2px;display:flex;align-items:center;gap:6px;">
              <span>{{item.mimeType || item.type}}</span>
              <span *ngIf="item.duration" style="color:#0D9488;font-weight:600;">· {{item.duration}}s</span>
            </div>
          </div>
        </div>

        <!-- Folder Badge & Size Info -->
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;font-size:11px;">
          <div style="color:#047857;font-weight:600;">
            {{compressionLabel(item.originalSize, item.storedSize)}}
          </div>
          <button class="item-folder-badge" (click)="openMoveModal(item)" [title]="'Move ' + item.title + ' to another folder'">
            <span>{{getItemFolder(item).icon}}</span> {{getItemFolder(item).name}} ▾
          </button>
        </div>

        <!-- Action Buttons -->
        <div style="display:flex;gap:6px;flex-wrap:wrap;border-top:1px solid #F1F5F9;padding-top:10px;">
          <button class="btn btn-secondary" style="padding:4px 10px;font-size:12px;flex:1;" (click)="viewItem(item)">
            View
          </button>
          <button class="btn btn-secondary" style="padding:4px 8px;font-size:12px;" (click)="openMoveModal(item)" title="Move to folder">
            📁 Move
          </button>
          <button class="btn btn-secondary" style="padding:4px 8px;font-size:12px;" (click)="copyLink(item)" title="Copy direct link">
            🔗 Link
          </button>
          <button class="btn" style="background:#FEE2E2;color:#991B1B;padding:4px 8px;font-size:12px;" (click)="deleteItem(item)" title="Delete item">
            🗑️
          </button>
        </div>
      </div>
    </div>

    <!-- Media Pagination Bar -->
    <div *ngIf="totalPages() > 1" class="card" style="margin-top:20px;padding:12px 16px;display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:12px;background:#FFFFFF;border:1px solid #E2E8F0;border-radius:10px;">
      <div style="font-size:13px;color:#64748B;">
        Showing <strong style="color:#0F172A;">{{itemStartIndex()}}–{{itemEndIndex()}}</strong> of <strong style="color:#0F172A;">{{filteredItems().length}}</strong> files in <em>{{activeFolder().name}}</em> (Page {{page()}} of {{totalPages()}})
      </div>
      <div style="display:flex;align-items:center;gap:6px;">
        <button class="btn btn-secondary" style="padding:5px 12px;font-size:12px;" [disabled]="page() === 1" (click)="setPage(page() - 1)">
          ‹ Previous
        </button>
        <ng-container *ngFor="let p of pageNumbers()">
          <span *ngIf="p === -1" style="padding:0 4px;color:#94A3B8;">…</span>
          <button *ngIf="p !== -1"
                  class="btn"
                  [class.btn-primary]="p === page()"
                  [class.btn-secondary]="p !== page()"
                  style="padding:5px 10px;font-size:12px;min-width:32px;text-align:center;"
                  (click)="setPage(p)">
            {{p}}
          </button>
        </ng-container>
        <button class="btn btn-secondary" style="padding:5px 12px;font-size:12px;" [disabled]="page() === totalPages()" (click)="setPage(page() + 1)">
          Next ›
        </button>
      </div>
    </div>

    <!-- View Media Modal -->
    <div *ngIf="viewing()" class="modal-backdrop" (click)="closeView($event)">
      <div class="modal-content" (click)="$event.stopPropagation()">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;">
          <div>
            <h3 style="font-weight:700;color:#134E4A;margin:0;">{{viewing()?.title}}</h3>
            <span class="badge" style="background:#F1F5F9;color:#475569;font-size:11px;margin-top:4px;display:inline-block;">
              {{getItemFolder(viewing()!).icon}} {{getItemFolder(viewing()!).name}} · {{viewing()?.mimeType}}
            </span>
          </div>
          <button class="btn btn-secondary" style="padding:2px 10px;font-size:16px;line-height:1;" (click)="closeView()">✕</button>
        </div>
        <div *ngIf="viewing()?.type === 'video'" style="background:#000;border-radius:8px;overflow:hidden;">
          <video [src]="media.serveUrl(viewing()!.id)" controls autoplay style="width:100%;max-height:70vh;display:block;"></video>
        </div>
        <div *ngIf="viewing()?.type === 'file' && isPdf(viewing()!)">
          <iframe [src]="pdfSafeUrl()" style="width:100%;height:75vh;border:1px solid #E2E8F0;border-radius:8px;" title="PDF viewer"></iframe>
        </div>
        <div *ngIf="viewing()?.type === 'file' && !isPdf(viewing()!)">
          <img [src]="media.serveUrl(viewing()!.id)" style="max-width:100%;max-height:70vh;display:block;margin:0 auto;border-radius:8px;" [alt]="viewing()!.title" />
        </div>
      </div>
    </div>

    <!-- Create / Edit Folder Modal -->
    <div *ngIf="showFolderModal()" class="modal-backdrop" (click)="closeFolderModal()">
      <div class="modal-content" style="max-width:440px;" (click)="$event.stopPropagation()">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px;">
          <h3 style="font-weight:700;color:#0F172A;margin:0;">
            {{editingFolder() ? '✏️ Rename Folder' : '📁 Create New Folder'}}
          </h3>
          <button class="btn btn-secondary" style="padding:2px 8px;font-size:14px;" (click)="closeFolderModal()">✕</button>
        </div>
        <form (ngSubmit)="saveFolder()">
          <div style="margin-bottom:14px;">
            <label style="display:block;font-size:12px;font-weight:600;margin-bottom:6px;color:#334155;">Folder Name</label>
            <input type="text" [(ngModel)]="folderFormName" name="folderFormName" required placeholder="e.g. Python Course Videos, Certificates" class="form-control" style="width:100%;" />
          </div>
          <div style="margin-bottom:18px;">
            <label style="display:block;font-size:12px;font-weight:600;margin-bottom:6px;color:#334155;">Folder Icon</label>
            <div style="display:flex;gap:8px;flex-wrap:wrap;">
              <button type="button" *ngFor="let ic of availableIcons"
                      class="btn"
                      [class.btn-primary]="folderFormIcon === ic"
                      [class.btn-secondary]="folderFormIcon !== ic"
                      style="font-size:18px;padding:6px 10px;line-height:1;"
                      (click)="folderFormIcon = ic">
                {{ic}}
              </button>
            </div>
          </div>
          <div style="display:flex;justify-content:flex-end;gap:8px;">
            <button type="button" class="btn btn-secondary" (click)="closeFolderModal()">Cancel</button>
            <button type="submit" class="btn btn-primary" [disabled]="!folderFormName.trim()">
              {{editingFolder() ? 'Save Changes' : 'Create Folder'}}
            </button>
          </div>
        </form>
      </div>
    </div>

    <!-- Move File to Folder Modal -->
    <div *ngIf="showMoveModal()" class="modal-backdrop" (click)="closeMoveModal()">
      <div class="modal-content" style="max-width:440px;" (click)="$event.stopPropagation()">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px;">
          <div>
            <h3 style="font-weight:700;color:#0F172A;margin:0;">📁 Move to Folder</h3>
            <p style="font-size:12px;color:#64748B;margin:2px 0 0;" [title]="movingItem()?.title">
              {{movingItem()?.title}}
            </p>
          </div>
          <button class="btn btn-secondary" style="padding:2px 8px;font-size:14px;" (click)="closeMoveModal()">✕</button>
        </div>
        <div style="display:flex;flex-direction:column;gap:8px;max-height:350px;overflow-y:auto;padding-right:4px;">
          <button *ngFor="let f of assignableFolders()"
                  type="button"
                  class="btn"
                  [class.btn-primary]="getItemFolder(movingItem()!).id === f.id"
                  [class.btn-secondary]="getItemFolder(movingItem()!).id !== f.id"
                  style="display:flex;align-items:center;justify-content:space-between;padding:10px 14px;text-align:left;"
                  (click)="moveItemTo(f.id)">
            <span style="display:flex;align-items:center;gap:8px;">
              <span style="font-size:16px;">{{f.icon}}</span>
              <span style="font-weight:600;">{{f.name}}</span>
            </span>
            <span style="font-size:11px;opacity:0.8;">{{getFolderCount(f.id)}} items</span>
          </button>
        </div>
      </div>
    </div>
  `,
  styles: [`
    .folder-scroll-row {
      display: flex;
      gap: 8px;
      overflow-x: auto;
      padding-bottom: 4px;
    }
    .folder-scroll-row::-webkit-scrollbar { height: 4px; }
    .folder-scroll-row::-webkit-scrollbar-thumb { background: #CBD5E1; border-radius: 4px; }
    .folder-chip {
      border: 1px solid #E2E8F0;
      background: #F8FAFC;
      padding: 8px 14px;
      border-radius: 10px;
      font-size: 13px;
      font-weight: 600;
      color: #334155;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 6px;
      white-space: nowrap;
      transition: all .15s ease;
      flex-shrink: 0;
    }
    .folder-chip:hover {
      background: #F1F5F9;
      border-color: #CBD5E1;
    }
    .folder-chip.active {
      background: #0D9488;
      color: #FFFFFF;
      border-color: #0D9488;
      box-shadow: 0 2px 6px rgba(13, 148, 136, 0.25);
    }
    .folder-chip.active .folder-count {
      background: rgba(255, 255, 255, 0.25);
      color: #FFFFFF;
    }
    .folder-count {
      background: #E2E8F0;
      color: #475569;
      font-size: 11px;
      padding: 1px 7px;
      border-radius: 10px;
    }
    .filter-tab-btn {
      border: 0;
      background: none;
      padding: 6px 14px;
      font-size: 13px;
      font-weight: 600;
      color: #64748B;
      cursor: pointer;
      border-radius: 8px;
      transition: all .15s;
    }
    .filter-tab-btn.active {
      background: #CCFBF1;
      color: #0F766E;
    }
    .tab-count {
      background: #E2E8F0;
      color: #475569;
      font-size: 11px;
      padding: 1px 6px;
      border-radius: 10px;
      margin-left: 4px;
    }
    .filter-tab-btn.active .tab-count {
      background: #99F6E4;
      color: #115E59;
    }
    .upload-zone {
      border: 2px dashed #CBD5E1;
      border-radius: 12px;
      padding: 24px 20px;
      text-align: center;
      transition: all .15s;
      background: #FAFAF9;
    }
    .upload-zone.dragover {
      border-color: #0D9488;
      background: #F0FDFA;
    }
    .media-card {
      padding: 14px;
      background: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 12px;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      transition: transform .15s ease, box-shadow .15s ease;
    }
    .media-card:hover {
      transform: translateY(-2px);
      box-shadow: 0 6px 16px rgba(0, 0, 0, 0.06);
    }
    .media-thumb-preview {
      width: 44px;
      height: 44px;
      border-radius: 8px;
      background: #EEF2FF;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 22px;
      flex-shrink: 0;
      overflow: hidden;
    }
    .media-thumb-preview img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
    .item-folder-badge {
      background: #F1F5F9;
      color: #334155;
      border: 1px solid #E2E8F0;
      border-radius: 6px;
      padding: 2px 8px;
      font-size: 11px;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 4px;
      transition: background .15s;
    }
    .item-folder-badge:hover {
      background: #E2E8F0;
    }
    .modal-backdrop {
      position: fixed;
      inset: 0;
      background: rgba(2, 6, 23, .65);
      z-index: 1000;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 24px;
    }
    .modal-content {
      background: #FFFFFF;
      color: #0F172A;
      border-radius: 14px;
      padding: 20px;
      max-width: 900px;
      width: 100%;
      max-height: 90vh;
      overflow: auto;
      box-shadow: 0 20px 60px rgba(2, 6, 23, .4);
    }
  `]
})
export class MediaHubComponent implements OnInit {
  private sanitizer = inject(DomSanitizer);
  private confirm = inject(ConfirmService);
  private quotaModal = inject(QuotaModalService);
  protected media = inject(MediaService);

  // Raw data from server
  items = signal<MediaItem[]>([]);
  loading = signal(false);

  // Folder state
  folders = signal<MediaFolder[]>([]);
  activeFolderId = signal<string>('all');
  fileFolderMap = signal<Record<number, string>>({});

  // Tab & search filtering
  activeTab = signal<'all' | 'video' | 'file'>('all');
  searchQuery = signal<string>('');

  // Pagination state (8-10 per page default)
  page = signal<number>(1);
  pageSize = signal<number>(9);

  // Upload state
  dragover = signal(false);
  uploading = signal(false);
  uploadPct = signal(0);
  uploadName = signal('');
  error = signal('');

  // View modal state
  viewing = signal<MediaItem | null>(null);
  pdfSafeUrl = signal<SafeResourceUrl | null>(null);

  // Folder creation / edit modal
  showFolderModal = signal(false);
  editingFolder = signal<MediaFolder | null>(null);
  folderFormName = '';
  folderFormIcon = '📁';
  availableIcons = ['📁', '🎬', '📚', '🖼️', '📝', '💼', '🎓', '💻', '📊', '⚡', '📦', '🔒'];

  // Move item modal
  showMoveModal = signal(false);
  movingItem = signal<MediaItem | null>(null);

  protected compressionLabel = compressionLabel;

  ngOnInit() {
    this.initFolders();
    this.load();
  }

  // -------------------------------------------------------------------------
  // Folder Management (Frontend LocalStorage Persistence, zero backend impact)
  // -------------------------------------------------------------------------
  private initFolders() {
    try {
      const savedFolders = localStorage.getItem(FOLDER_STORAGE_KEY);
      if (savedFolders) {
        const parsed: MediaFolder[] = JSON.parse(savedFolders);
        // Ensure default system folders always exist
        const merged = [...DEFAULT_FOLDERS];
        for (const f of parsed) {
          if (!merged.some(m => m.id === f.id)) {
            merged.push(f);
          }
        }
        this.folders.set(merged);
      } else {
        this.folders.set([...DEFAULT_FOLDERS]);
      }

      const savedMap = localStorage.getItem(FILE_MAP_STORAGE_KEY);
      if (savedMap) {
        this.fileFolderMap.set(JSON.parse(savedMap));
      }
    } catch {
      this.folders.set([...DEFAULT_FOLDERS]);
    }
  }

  private persistFolders() {
    try {
      localStorage.setItem(FOLDER_STORAGE_KEY, JSON.stringify(this.folders()));
    } catch {}
  }

  private persistFileMap() {
    try {
      localStorage.setItem(FILE_MAP_STORAGE_KEY, JSON.stringify(this.fileFolderMap()));
    } catch {}
  }

  activeFolder = computed(() => {
    return this.folders().find(f => f.id === this.activeFolderId()) || this.folders()[0];
  });

  assignableFolders = computed(() => {
    return this.folders().filter(f => f.id !== 'all');
  });

  setFolder(id: string) {
    this.activeFolderId.set(id);
    this.page.set(1);
    this.error.set('');
  }

  getFolderCount(folderId: string): number {
    const all = this.items();
    if (folderId === 'all') return all.length;
    if (folderId === 'unorganized') {
      const map = this.fileFolderMap();
      return all.filter(i => !map[i.id] || map[i.id] === 'unorganized').length;
    }
    const map = this.fileFolderMap();
    return all.filter(i => map[i.id] === folderId).length;
  }

  getItemFolder(item: MediaItem): MediaFolder {
    const folderId = this.fileFolderMap()[item.id];
    if (folderId) {
      const found = this.folders().find(f => f.id === folderId);
      if (found) return found;
    }
    return this.folders().find(f => f.id === 'unorganized') || {
      id: 'unorganized', name: 'Unorganized', icon: '📥'
    };
  }

  openCreateFolderModal() {
    this.editingFolder.set(null);
    this.folderFormName = '';
    this.folderFormIcon = '📁';
    this.showFolderModal.set(true);
  }

  openRenameFolderModal(folder: MediaFolder) {
    this.editingFolder.set(folder);
    this.folderFormName = folder.name;
    this.folderFormIcon = folder.icon || '📁';
    this.showFolderModal.set(true);
  }

  closeFolderModal() {
    this.showFolderModal.set(false);
    this.editingFolder.set(null);
  }

  saveFolder() {
    const name = this.folderFormName.trim();
    if (!name) return;

    if (this.editingFolder()) {
      const target = this.editingFolder()!;
      this.folders.update(list => list.map(f => f.id === target.id ? { ...f, name, icon: this.folderFormIcon } : f));
    } else {
      const id = 'folder_' + Date.now();
      const newF: MediaFolder = {
        id,
        name,
        icon: this.folderFormIcon,
        isSystem: false
      };
      this.folders.update(list => [...list, newF]);
      this.activeFolderId.set(id);
    }
    this.persistFolders();
    this.closeFolderModal();
  }

  async deleteFolder(folder: MediaFolder) {
    if (folder.isSystem) return;
    if (!(await this.confirm.confirm(`Delete folder "${folder.name}"? Files will be moved to Unorganized.`))) return;

    // Reassign items in this folder to unorganized
    const currentMap = { ...this.fileFolderMap() };
    for (const [fileIdStr, fId] of Object.entries(currentMap)) {
      if (fId === folder.id) {
        delete currentMap[Number(fileIdStr)];
      }
    }
    this.fileFolderMap.set(currentMap);
    this.persistFileMap();

    this.folders.update(list => list.filter(f => f.id !== folder.id));
    this.persistFolders();

    if (this.activeFolderId() === folder.id) {
      this.activeFolderId.set('all');
    }
  }

  openMoveModal(item: MediaItem) {
    this.movingItem.set(item);
    this.showMoveModal.set(true);
  }

  closeMoveModal() {
    this.showMoveModal.set(false);
    this.movingItem.set(null);
  }

  moveItemTo(folderId: string) {
    const item = this.movingItem();
    if (!item) return;

    const currentMap = { ...this.fileFolderMap() };
    if (folderId === 'unorganized') {
      delete currentMap[item.id];
    } else {
      currentMap[item.id] = folderId;
    }
    this.fileFolderMap.set(currentMap);
    this.persistFileMap();
    this.closeMoveModal();
  }

  // -------------------------------------------------------------------------
  // Filtering & Pagination
  // -------------------------------------------------------------------------
  totalItemCount = computed(() => this.items().length);
  videoCount = computed(() => this.items().filter(i => i.type === 'video').length);
  fileCount = computed(() => this.items().filter(i => i.type === 'file').length);

  filteredItems = computed(() => {
    let result = this.items();

    // Filter by type tab
    const tab = this.activeTab();
    if (tab === 'video') {
      result = result.filter(i => i.type === 'video');
    } else if (tab === 'file') {
      result = result.filter(i => i.type === 'file');
    }

    // Filter by folder
    const folderId = this.activeFolderId();
    if (folderId !== 'all') {
      const map = this.fileFolderMap();
      if (folderId === 'unorganized') {
        result = result.filter(i => !map[i.id] || map[i.id] === 'unorganized');
      } else {
        result = result.filter(i => map[i.id] === folderId);
      }
    }

    // Filter by search query
    const q = this.searchQuery().trim().toLowerCase();
    if (q) {
      result = result.filter(i =>
        (i.title || '').toLowerCase().includes(q) ||
        (i.mimeType || '').toLowerCase().includes(q)
      );
    }

    return result;
  });

  totalPages = computed(() => {
    return Math.ceil(this.filteredItems().length / this.pageSize()) || 1;
  });

  paginatedItems = computed(() => {
    const start = (this.page() - 1) * this.pageSize();
    return this.filteredItems().slice(start, start + this.pageSize());
  });

  itemStartIndex = computed(() => {
    if (this.filteredItems().length === 0) return 0;
    return (this.page() - 1) * this.pageSize() + 1;
  });

  itemEndIndex = computed(() => {
    if (this.filteredItems().length === 0) return 0;
    return Math.min(this.page() * this.pageSize(), this.filteredItems().length);
  });

  pageNumbers = computed(() => {
    const total = this.totalPages();
    const current = this.page();
    const pages: number[] = [];
    if (total <= 7) {
      for (let i = 1; i <= total; i++) pages.push(i);
    } else {
      if (current <= 4) {
        pages.push(1, 2, 3, 4, 5, -1, total);
      } else if (current >= total - 3) {
        pages.push(1, -1, total - 4, total - 3, total - 2, total - 1, total);
      } else {
        pages.push(1, -1, current - 1, current, current + 1, -1, total);
      }
    }
    return pages;
  });

  setPage(p: number) {
    if (p >= 1 && p <= this.totalPages()) {
      this.page.set(p);
    }
  }

  setPageSize(size: any) {
    this.pageSize.set(Number(size) || 9);
    this.page.set(1);
  }

  setTab(t: 'all' | 'video' | 'file') {
    this.activeTab.set(t);
    this.page.set(1);
    this.error.set('');
  }

  onSearchChange(val: string) {
    this.searchQuery.set(val);
    this.page.set(1);
  }

  accept = computed(() => {
    const tab = this.activeTab();
    if (tab === 'video') return VIDEO_TYPES.join(',');
    if (tab === 'file') return FILE_TYPES.join(',');
    return [...VIDEO_TYPES, ...FILE_TYPES].join(',');
  });

  // -------------------------------------------------------------------------
  // Media Server Operations
  // -------------------------------------------------------------------------
  private load() {
    this.loading.set(true);
    this.media.list().subscribe({
      next: (items) => {
        this.items.set(items || []);
        this.loading.set(false);
      },
      error: () => this.loading.set(false)
    });
  }

  onDrop(e: DragEvent) {
    e.preventDefault();
    this.dragover.set(false);
    const f = e.dataTransfer?.files?.[0];
    if (f) this.uploadFile(f);
  }

  onPick(e: Event) {
    const f = (e.target as HTMLInputElement).files?.[0];
    if (f) this.uploadFile(f);
    (e.target as HTMLInputElement).value = '';
  }

  private uploadFile(file: File) {
    let type: MediaType = file.type.startsWith('video/') ? 'video' : 'file';

    const tab = this.activeTab();
    if (tab === 'video' && !file.type.startsWith('video/')) {
      this.error.set('Please choose a video file.');
      return;
    }
    if (tab === 'file' && !FILE_TYPES.includes(file.type)) {
      this.error.set('Please choose a PDF or image file.');
      return;
    }

    const maxBytes = type === 'video' ? 30 * 1024 * 1024 : 60 * 1024 * 1024;
    if (file.size > maxBytes) {
      const limit = type === 'video' ? '30MB' : '60MB';
      this.error.set(`"${file.name}" is too large (${(file.size / 1048576).toFixed(1)}MB). ${type === 'video' ? 'Videos' : 'Files'} must be ${limit} or smaller.`);
      return;
    }

    this.error.set('');
    this.uploading.set(true);
    this.uploadPct.set(0);
    this.uploadName.set(file.name);

    this.media.uploadWithProgress(file, type, (pct) => this.uploadPct.set(pct))
      .then((item) => {
        this.uploading.set(false);
        this.items.update(list => [item, ...list]);

        // If currently viewing a non-system folder, automatically assign the new file to it
        const currentFolderId = this.activeFolderId();
        if (currentFolderId && currentFolderId !== 'all' && currentFolderId !== 'unorganized') {
          const map = { ...this.fileFolderMap() };
          map[item.id] = currentFolderId;
          this.fileFolderMap.set(map);
          this.persistFileMap();
        }
      })
      .catch((err) => {
        this.uploading.set(false);
        const handled = this.quotaModal.handleError(err, 'Storage Limit Reached');
        if (!handled) {
          this.error.set(err.message || 'Upload failed');
        }
      });
  }

  isPdf(item: MediaItem | null): boolean {
    return !!item && (item.mimeType || '').includes('pdf');
  }

  onThumbError(event: Event) {
    (event.target as HTMLElement).style.display = 'none';
  }

  viewItem(item: MediaItem) {
    this.viewing.set(item);
    if (item.type === 'file' && this.isPdf(item)) {
      this.pdfSafeUrl.set(this.sanitizer.bypassSecurityTrustResourceUrl(this.media.serveUrl(item.id)));
    }
  }

  closeView(e?: Event) {
    if (e && e.target !== e.currentTarget) return;
    this.viewing.set(null);
    this.pdfSafeUrl.set(null);
  }

  copyLink(item: MediaItem) {
    const url = window.location.origin + this.media.serveUrl(item.id);
    navigator.clipboard?.writeText(url).catch(() => {});
  }

  async deleteItem(item: MediaItem) {
    if (!(await this.confirm.confirm('Delete "' + item.title + '"? References to it in courses will break.'))) return;
    this.media.delete(item.id).subscribe({
      next: () => {
        this.items.update(list => list.filter(i => i.id !== item.id));
        const map = { ...this.fileFolderMap() };
        delete map[item.id];
        this.fileFolderMap.set(map);
        this.persistFileMap();
      },
      error: () => this.error.set('Could not delete the item')
    });
  }
}
