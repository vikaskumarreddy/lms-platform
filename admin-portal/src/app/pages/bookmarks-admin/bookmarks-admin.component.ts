import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ApiService } from '../../services/api.service';

interface Bookmark {
  id: number;
  lessonId: number;
  lessonTitle: string;
  lessonType: string;
  courseName?: string;
  bookmarkedAt: string;
}

@Component({
  selector: 'app-bookmarks-admin',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
      <h1 style="font-size:24px;font-weight:700;">🔖 Bookmarks</h1>
    </div>

    <div class="card" *ngIf="bookmarks.length === 0">
      <p style="color:#64748B;text-align:center;padding:40px 0;">No bookmarks found</p>
    </div>

    <div class="card" *ngIf="bookmarks.length > 0">
      <table>
        <thead>
          <tr>
            <th>Lesson Title</th>
            <th>Type</th>
            <th>Course</th>
            <th>Bookmarked At</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr *ngFor="let b of bookmarks">
            <td style="font-weight:600;">{{b.lessonTitle}}</td>
            <td><span class="badge badge-info">{{b.lessonType}}</span></td>
            <td>{{b.courseName || 'N/A'}}</td>
            <td>{{b.bookmarkedAt}}</td>
            <td>
              <button class="btn btn-danger" style="padding:4px 12px;font-size:12px;" (click)="deleteBookmark(b)">Delete</button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  `
})
export class BookmarksAdminComponent implements OnInit {
  private api = inject(ApiService);
  bookmarks: Bookmark[] = [];

  ngOnInit(): void {
    this.loadBookmarks();
  }

  loadBookmarks(): void {
    this.api.get<Bookmark[]>('/api/bookmarks').subscribe({
      next: (data: Bookmark[]) => {
        this.bookmarks = data;
      },
      error: (err: any) => {
        console.error('Failed to load bookmarks', err);
      }
    });
  }

  deleteBookmark(bookmark: Bookmark): void {
    if (!confirm(`Delete bookmark for "${bookmark.lessonTitle}"?`)) return;
    this.api.delete(`/api/bookmarks/user/0/lesson/${bookmark.lessonId}`).subscribe({
      next: () => {
        this.bookmarks = this.bookmarks.filter(b => b.id !== bookmark.id);
      },
      error: (err: any) => {
        console.error('Failed to delete bookmark', err);
        alert('Failed to delete bookmark');
      }
    });
  }
}