import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';

interface Batch {
  id: number;
  name: string;
  isActive: boolean;
}

interface LeaderboardEntry {
  userId: number;
  name: string;
  assignmentsSubmitted: number;
  examsSubmitted: number;
  attendancePercent: number;
  score: number;
  rank: number;
}

interface LeaderboardResponse {
  weekStart: string;
  entries: LeaderboardEntry[];
  myRank?: LeaderboardEntry;
}

@Component({
  selector: 'app-leaderboard-admin',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="page-header">
      <h1 style="font-size:24px;font-weight:700;margin:0;">🏆 Leaderboard</h1>
    </div>

    <div class="card" style="margin-bottom:20px;display:flex;align-items:center;gap:16px;flex-wrap:wrap;">
      <div>
        <label style="display:block;font-size:12px;font-weight:600;color:#64748B;margin-bottom:4px;">Batch</label>
        <select [(ngModel)]="selectedBatchId" (ngModelChange)="loadLeaderboard()" style="min-width:220px;">
          <option [ngValue]="null">All batches</option>
          <option *ngFor="let b of batches" [ngValue]="b.id">{{b.name}}{{b.isActive ? '' : ' (Inactive)'}}</option>
        </select>
      </div>
      <p style="color:#64748B;font-size:13px;margin:0;" *ngIf="leaderboard?.weekStart">
        Week of {{leaderboard?.weekStart}} · score = (assignments + exams submitted this week) × 10 + attendance %
      </p>
    </div>

    <div *ngIf="loading" style="display:flex;justify-content:center;padding:48px;">
      <div class="spinner-border" role="status"><span class="visually-hidden">Loading...</span></div>
    </div>

    <ng-container *ngIf="!loading">
      <div *ngIf="!topThree.length" class="card" style="text-align:center;color:#64748B;padding:32px;">
        No leaderboard activity yet for this selection.
      </div>

      <!-- Podium -->
      <div class="podium" *ngIf="topThree.length">
        <div class="podium-tile" [class.podium-first]="i === 0" [class.podium-second]="i === 1" [class.podium-third]="i === 2"
             *ngFor="let entry of podiumOrder; let i = index" [style.order]="podiumVisualOrder[i]">
          <div class="podium-crown" *ngIf="entry.rank === 1">👑</div>
          <div class="podium-avatar">{{getInitials(entry.name)}}</div>
          <div class="podium-name">{{entry.name}}</div>
          <div class="podium-score">{{entry.score}} pts</div>
          <div class="podium-rank-block">{{entry.rank}}</div>
        </div>
      </div>

      <!-- Ranked table -->
      <div class="card" *ngIf="rest.length">
        <h3 class="section-title">Ranked</h3>
        <div class="table-responsive">
          <table class="table">
            <thead>
              <tr>
                <th>Rank</th>
                <th>Name</th>
                <th>Assignments</th>
                <th>Exams</th>
                <th>Attendance %</th>
                <th>Score</th>
              </tr>
            </thead>
            <tbody>
              <tr *ngFor="let entry of rest">
                <td>#{{entry.rank}}</td>
                <td>{{entry.name}}</td>
                <td>{{entry.assignmentsSubmitted}}</td>
                <td>{{entry.examsSubmitted}}</td>
                <td>{{entry.attendancePercent}}%</td>
                <td><strong>{{entry.score}}</strong></td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </ng-container>
  `,
  styles: [`
    .page-header { margin-bottom: 20px; }
    .section-title { margin: 0 0 16px 0; font-size: 16px; font-weight: 700; }

    .podium {
      display: flex;
      align-items: flex-end;
      justify-content: center;
      gap: 16px;
      margin-bottom: 24px;
    }

    .podium-tile {
      background: var(--surface);
      color: var(--text);
      border-radius: 12px;
      box-shadow: 0 1px 3px rgba(0,0,0,0.1);
      padding: 20px 16px;
      text-align: center;
      width: 180px;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 6px;
      position: relative;
    }

    .podium-crown { font-size: 24px; margin-bottom: -4px; }

    .podium-avatar {
      width: 56px;
      height: 56px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: 700;
      font-size: 18px;
      color: white;
    }

    .podium-first .podium-avatar { background: linear-gradient(135deg, #FBBF24 0%, #D97706 100%); width: 68px; height: 68px; font-size: 22px; }
    .podium-second .podium-avatar { background: linear-gradient(135deg, #CBD5E1 0%, #94A3B8 100%); }
    .podium-third .podium-avatar { background: linear-gradient(135deg, #FB923C 0%, #C2410C 100%); }

    .podium-name { font-weight: 600; font-size: 14px; color: #1e293b; }
    .podium-score { font-size: 13px; color: #64748B; margin-bottom: 4px; }

    .podium-rank-block {
      width: 100%;
      border-radius: 8px;
      padding: 10px 0;
      font-weight: 700;
      font-size: 18px;
      color: white;
    }

    .podium-first .podium-rank-block { background: linear-gradient(135deg, #FBBF24 0%, #D97706 100%); }
    .podium-second .podium-rank-block { background: linear-gradient(135deg, #CBD5E1 0%, #94A3B8 100%); }
    .podium-third .podium-rank-block { background: linear-gradient(135deg, #FB923C 0%, #C2410C 100%); }

    .podium-first { padding-bottom: 28px; }
  `]
})
export class LeaderboardAdminComponent implements OnInit {
  batches: Batch[] = [];
  leaderboard: LeaderboardResponse | null = null;
  selectedBatchId: number | null = null;
  loading = false;

  constructor(private apiService: ApiService) {}

  ngOnInit() {
    this.loadBatches();
    this.loadLeaderboard();
  }

  loadBatches() {
    this.apiService.get<Batch[]>('/api/batches').subscribe({
      next: (data) => { this.batches = data; },
      error: (err) => { console.error('Failed to load batches', err); this.batches = []; }
    });
  }

  loadLeaderboard() {
    this.loading = true;
    const query = this.selectedBatchId != null ? `?batchId=${this.selectedBatchId}` : '';
    this.apiService.get<LeaderboardResponse>(`/api/leaderboard${query}`).subscribe({
      next: (data) => { this.leaderboard = data; this.loading = false; },
      error: (err) => { console.error('Failed to load leaderboard', err); this.leaderboard = null; this.loading = false; }
    });
  }

  get topThree(): LeaderboardEntry[] {
    return (this.leaderboard?.entries || []).slice(0, 3);
  }

  get rest(): LeaderboardEntry[] {
    return (this.leaderboard?.entries || []).slice(3);
  }

  /** Rendered left-to-right as 2nd/1st/3rd, the classic podium arrangement. */
  get podiumOrder(): LeaderboardEntry[] {
    return this.topThree;
  }

  get podiumVisualOrder(): number[] {
    // CSS order for whatever's actually present (handles batches with only 1-2 entries).
    const count = this.topThree.length;
    if (count === 3) return [2, 1, 3];
    if (count === 2) return [1, 2];
    return [1];
  }

  getInitials(name: string): string {
    if (!name) return '?';
    const parts = name.split(' ');
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return name.substring(0, 2).toUpperCase();
  }
}
