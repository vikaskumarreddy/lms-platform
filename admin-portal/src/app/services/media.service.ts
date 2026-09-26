import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from './api.service';
import { environment } from '../../environments/environment';

export type MediaType = 'video' | 'file';

export interface MediaItem {
  id: number;
  title: string;
  type: MediaType;
  mimeType?: string;
  originalSize?: number;
  storedSize?: number;
  duration?: number;
  width?: number;
  height?: number;
  url?: string;
  createdAt?: string;
  createdByName?: string;
}

export interface MediaUploadResult {
  item: MediaItem;
}

/**
 * Wraps the media API (to be implemented server-side — see the API contract
 * in media.service.ts). Backend owns all compression: images → WebP, PDFs →
 * gzipped, videos → downscaled/transcoded. The frontend validates type/size,
 * streams upload progress, and surfaces the stored size returned by the server.
 */
@Injectable({ providedIn: 'root' })
export class MediaService {
  private api = inject(ApiService);

  private get baseUrl(): string {
    return environment.production ? window.location.origin : 'http://localhost:8080';
  }

  list(type?: MediaType): Observable<MediaItem[]> {
    const q = type ? `?type=${type}` : '';
    return this.api.get<MediaItem[]>(`/api/media${q}`);
  }

  get(id: number): Observable<MediaItem> {
    return this.api.get<MediaItem>(`/api/media/${id}`);
  }

  /**
   * Upload with progress callback (uses XHR directly for reliable progress
   * events — HttpClient's interceptor pipeline doesn't run for XHR, so the
   * JWT/tenant headers that auth.interceptor.ts normally attaches must be
   * set here by hand, exactly the same way, or the backend 403s every upload).
   */
  uploadWithProgress(
    file: File,
    type: MediaType,
    onProgress?: (pct: number) => void
  ): Promise<MediaItem> {
    return new Promise((resolve, reject) => {
      const fd = new FormData();
      fd.append('file', file);
      fd.append('type', type);
      fd.append('title', file.name.replace(/\.[^.]+$/, ''));
      const xhr = new XMLHttpRequest();
      xhr.open('POST', `${this.baseUrl}/api/media/upload`);
      const token = localStorage.getItem('access_token') || '';
      if (token) xhr.setRequestHeader('Authorization', 'Bearer ' + token);
      xhr.setRequestHeader('X-Tenant-Slug', this.tenantSlug());
      xhr.upload.onprogress = (e) => {
        if (e.lengthComputable && onProgress) onProgress(Math.round((e.loaded / e.total) * 100));
      };
      xhr.onload = () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          try { resolve(JSON.parse(xhr.responseText).item); }
          catch { reject(new Error('Invalid server response')); }
        } else if (xhr.status === 413) {
          reject(new Error('File is too large for the server to accept. Ask an admin to raise the upload limit.'));
        } else if (xhr.status === 403) {
          reject(new Error('Not authorized to upload — please log in again.'));
        } else {
          let msg = `Upload failed (${xhr.status})`;
          let jsonBody: any = null;
          try {
            jsonBody = JSON.parse(xhr.responseText);
            msg = jsonBody?.message || jsonBody?.error || msg;
          } catch { /* ignore */ }
          const err: any = new Error(msg);
          err.status = xhr.status;
          err.code = jsonBody?.code || (xhr.status === 409 ? 'QUOTA_STORAGE_EXCEEDED' : '');
          err.error = jsonBody;
          reject(err);
        }
      };
      xhr.onerror = () => reject(new Error('Network error during upload'));
      xhr.send(fd);
    });
  }

  /** Mirrors auth.interceptor.ts's deriveTenantSlug() so XHR uploads resolve the same organization. */
  private tenantSlug(): string {
    const hostname = window.location.hostname;
    if (hostname && hostname !== 'localhost' && hostname !== '127.0.0.1' && !/^\d+\.\d+\.\d+\.\d+$/.test(hostname)) {
      const parts = hostname.split('.');
      if (parts.length >= 3) {
        const sub = parts[0].toLowerCase();
        if (sub === 'admin' || sub === 'www') {
          return 'axisora';
        }
        return sub;
      }
      return 'axisora';
    }

    const stored = localStorage.getItem('tenant_slug');
    if (stored && stored.trim()) return stored.trim();
    return 'axisora';
  }

  /**
   * Direct serve URL for <video src>/<img src>/<iframe src>/<a href>. These are
   * plain browser GETs — the browser cannot attach the Authorization header the
   * way HttpClient's interceptor does for XHR/fetch calls — so the JWT and
   * tenant slug are passed as query params instead. The backend's /serve
   * endpoint must accept `token`/`tenant` query params as a fallback to the
   * Authorization header (same JWT, just carried differently for this one
   * always-browser-initiated request).
   */
  serveUrl(id: number): string {
    const token = localStorage.getItem('access_token') || '';
    const params = new URLSearchParams({ tenant: this.tenantSlug() });
    if (token) params.set('token', token);
    return `${this.baseUrl}/api/media/${id}/serve?${params.toString()}`;
  }

  serve(id: number): Observable<ArrayBuffer> {
    return this.api.getArrayBuffer(`/api/media/${id}/serve`);
  }

  delete(id: number): Observable<any> {
    return this.api.delete(`/api/media/${id}`);
  }
}

export const formatBytes = (bytes = 0): string => {
  if (!bytes) return '0 B';
  if (bytes >= 1073741824) return (bytes / 1073741824).toFixed(1) + ' GB';
  if (bytes >= 1048576) return (bytes / 1048576).toFixed(1) + ' MB';
  if (bytes >= 1024) return (bytes / 1024).toFixed(1) + ' KB';
  return bytes + ' B';
};

export const compressionLabel = (original?: number, stored?: number): string => {
  const o = original ?? 0, s = stored ?? 0;
  let label = formatBytes(s) + ' stored';
  if (o > 0 && s > 0 && s < o) label += ' · ' + Math.round((1 - s / o) * 100) + '% smaller';
  return label;
};

