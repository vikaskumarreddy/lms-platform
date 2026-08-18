import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ApiService } from '../../services/api.service';
import { AuthService } from '../../services/auth.service';

interface DashboardStats {
  totalStudents: number;
  activeCourses: number;
  totalRevenue: number;
  placedStudents: number;
  placementPercentage: number;
  totalAssignments: number;
  totalExams: number;
  totalEvents: number;
  recentEnrollments: RecentEnrollment[];
  upcomingEvents: UpcomingEvent[];
}

interface RecentEnrollment {
  studentName: string;
  courseName: string;
  date: string;
  status: string;
}

interface UpcomingEvent {
  eventName: string;
  eventType: string;
  date: string;
}

/** Platform (placements.com) dashboard metrics returned by GET /api/saas/stats. */
interface PlatformStats {
  totalOrganizations: number;
  activeOrganizations: number;
  expiredOrganizations: number;
  totalRevenue: number;
  renewalCount: number;
  renewalPercentage: number;
}

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule],
  template: `
    <h1 style="font-size:24px;font-weight:700;margin-bottom:24px;">Dashboard</h1>

    @if (isPlatformAdmin) {
      <div class="grid-4">
        <div class="card stat-card"><div class="icon" style="background:#DBEAFE;color:#2563EB;">🏢</div><div><div style="font-size:28px;font-weight:700;">{{platformStats.totalOrganizations || 0}}</div><div style="color:#64748B;font-size:14px;">Total Organizations</div></div></div>
        <div class="card stat-card"><div class="icon" style="background:#DCFCE7;color:#22C55E;">✅</div><div><div style="font-size:28px;font-weight:700;">{{platformStats.activeOrganizations || 0}}</div><div style="color:#64748B;font-size:14px;">Active Organizations</div></div></div>
        <div class="card stat-card"><div class="icon" style="background:#FEF3C7;color:#EAB308;">💰</div><div><div style="font-size:28px;font-weight:700;">₹{{platformStats.totalRevenue | number:'1.0-0'}}</div><div style="color:#64748B;font-size:14px;">Total Revenue</div></div></div>
        <div class="card stat-card"><div class="icon" style="background:#F3E8FF;color:#9333EA;">🔄</div><div><div style="font-size:28px;font-weight:700;">{{platformStats.renewalPercentage || 0}}%</div><div style="color:#64748B;font-size:14px;">Renewal %</div></div></div>
      </div>
    } @else {
      <div class="grid-4">
        <div class="card stat-card"><div class="icon" style="background:#DBEAFE;color:#2563EB;">👥</div><div><div style="font-size:28px;font-weight:700;">{{stats.totalStudents || 0}}</div><div style="color:#64748B;font-size:14px;">Total Students</div></div></div>
      <div class="card stat-card"><div class="icon" style="background:#FEF3C7;color:#EAB308;">📚</div><div><div style="font-size:28px;font-weight:700;">{{stats.activeCourses || 0}}</div><div style="color:#64748B;font-size:14px;">Active Courses</div></div></div>
      <div class="card stat-card"><div class="icon" style="background:#DCFCE7;color:#22C55E;">💰</div><div><div style="font-size:28px;font-weight:700;">₹{{stats.totalRevenue | number:'1.0-0'}}</div><div style="color:#64748B;font-size:14px;">Revenue</div></div></div>
      <div class="card stat-card"><div class="icon" style="background:#F3E8FF;color:#9333EA;">🎯</div><div><div style="font-size:28px;font-weight:700;">{{stats.placementPercentage || 0}}%</div><div style="color:#64748B;font-size:14px;">Placement Rate</div></div></div>
    </div>
    <div class="grid-2" style="margin-top:20px;">
      <div class="card">
        <h3 style="margin-bottom:16px;">Recent Enrollments</h3>
        <table>
          <thead>
            <tr><th>Student</th><th>Course</th><th>Date</th><th>Status</th></tr>
          </thead>
          <tbody>
            <tr *ngFor="let enrollment of stats.recentEnrollments">
              <td>{{enrollment.studentName}}</td>
              <td>{{enrollment.courseName}}</td>
              <td>{{enrollment.date | date:'MMM d'}}</td>
              <td><span class="badge" [class.badge-success]="enrollment.status === 'Active'" [class.badge-warning]="enrollment.status === 'Completed'">{{enrollment.status}}</span></td>
            </tr>
            <tr *ngIf="stats.recentEnrollments.length === 0">
              <td colspan="4" style="text-align:center;color:#64748B;padding:24px;">No enrollments yet</td>
            </tr>
          </tbody>
        </table>
      </div>
      <div class="card">
        <h3 style="margin-bottom:16px;">Upcoming Events</h3>
        <table>
          <thead>
            <tr><th>Event</th><th>Type</th><th>Date</th></tr>
          </thead>
          <tbody>
            <tr *ngFor="let event of stats.upcomingEvents">
              <td>{{event.eventName}}</td>
              <td>{{event.eventType}}</td>
              <td>{{event.date | date:'MMM d, h:mm a'}}</td>
            </tr>
            <tr *ngIf="stats.upcomingEvents.length === 0">
              <td colspan="3" style="text-align:center;color:#64748B;padding:24px;">No upcoming events</td>
            </tr>
          </tbody>
        </table>
      </div>
      </div>
    }
  `,
  styles: [`
    .stat-card { display:flex; align-items:center; gap:16px; }
    .icon { width:48px; height:48px; border-radius:12px; display:flex; align-items:center; justify-content:center; font-size:24px; }
  `]
})
export class DashboardComponent implements OnInit {
  private api = inject(ApiService);
  private auth = inject(AuthService);

  /** True only on the platform root domain (placements.com) for the super admin. */
  get isPlatformAdmin(): boolean {
    return this.auth.isPlatformDomain && this.auth.isAdmin;
  }

  platformStats: PlatformStats = {
    totalOrganizations: 0,
    activeOrganizations: 0,
    expiredOrganizations: 0,
    totalRevenue: 0,
    renewalCount: 0,
    renewalPercentage: 0
  };

  stats: DashboardStats = {
    totalStudents: 0,
    activeCourses: 0,
    totalRevenue: 0,
    placedStudents: 0,
    placementPercentage: 0,
    totalAssignments: 0,
    totalExams: 0,
    totalEvents: 0,
    recentEnrollments: [],
    upcomingEvents: []
  };

  ngOnInit() {
    if (this.isPlatformAdmin) {
      this.loadPlatformStats();
    } else {
      this.loadDashboardStats();
    }
  }

  loadPlatformStats() {
    this.api.get<PlatformStats>('/api/saas/stats').subscribe({
      next: (data) => {
        this.platformStats = data;
      },
      error: (err) => {
        console.error('Failed to load platform stats', err);
      }
    });
  }

  loadDashboardStats() {
    this.api.get<DashboardStats>('/api/dashboard/stats').subscribe({
      next: (data) => {
        this.stats = data;
      },
      error: (err) => {
        console.error('Failed to load dashboard stats', err);
      }
    });
  }
}