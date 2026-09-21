import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ApiService } from '../../services/api.service';
import { AuthService } from '../../services/auth.service';

/** Platform (placements.com) dashboard metrics returned by GET /api/saas/stats. */
interface PlatformStats {
  totalOrganizations: number;
  activeOrganizations: number;
  expiredOrganizations: number;
  totalRevenue: number;
  renewalCount: number;
  renewalPercentage: number;
}

interface BatchBreakdown {
  batchId: number;
  batchName: string;
  totalStudents: number;
  placed: number;
  unplaced: number;
}

interface BatchHealth {
  batchId: number;
  batchName: string;
  mentorName: string | null;
  studentCount: number;
  averageAttendance: number;
  isActive: boolean;
}

interface Overview {
  batchBreakdown: BatchBreakdown[];
  kpi: {
    totalStudents: number;
    activeStudents: number;
    placementRate: number;
    averageAttendance: number;
    totalFaculty?: number;
    activeSubscriptions?: number;
    monthlyRevenue?: number;
    outstandingDues?: number;
    revenueByMode?: Record<string, number>;
    subscriptionQuotas?: {
      maxStudents?: number;
      maxFaculty?: number;
      storageGbLimit?: number;
      storageGbUsed?: number;
      activeStudentsUsed?: number;
      facultyUsed?: number;
    };
    storageBreakdown?: {
      videoBytes: number;
      fileBytes: number;
      pdfBytes: number;
      totalBytes: number;
    };
  };
  academics: {
    assignmentsGraded: number;
    assignmentsPending: number;
    examsGraded: number;
    examsPending: number;
    certificatesIssued: number;
    recentCertificates: any[];
    batchHealth: BatchHealth[];
  };
  placements: {
    eligible: number;
    inProcess: number;
    placed: number;
    upcomingDrives: any[];
    companyKitEngagement: { kitId: number; companyName: string }[];
  };
  engagement: { unansweredQuestions: number };
  actionCenter: { pendingGrading: number; lowAttendanceCount: number };
}

const EMPTY_OVERVIEW: Overview = {
  batchBreakdown: [],
  kpi: { totalStudents: 0, activeStudents: 0, placementRate: 0, averageAttendance: 0 },
  academics: {
    assignmentsGraded: 0, assignmentsPending: 0, examsGraded: 0, examsPending: 0,
    certificatesIssued: 0, recentCertificates: [], batchHealth: []
  },
  placements: { eligible: 0, inProcess: 0, placed: 0, upcomingDrives: [], companyKitEngagement: [] },
  engagement: { unansweredQuestions: 0 },
  actionCenter: { pendingGrading: 0, lowAttendanceCount: 0 }
};


@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './dashboard.component.html',
  styleUrls: ['./dashboard.component.css']
})
export class DashboardComponent implements OnInit {
  private api = inject(ApiService);
  private auth = inject(AuthService);

  /** True only on the platform root domain (placements.com) for the super admin. */
  get isPlatformAdmin(): boolean {
    return this.auth.isPlatformDomain && this.auth.isAdmin;
  }

  /** Tenant admins (ADMIN off-platform or INSTITUTE_ADMIN) see subscription/revenue/storage cards; Faculty do not. */
  get isOrgAdmin(): boolean {
    return (!this.isPlatformAdmin && this.auth.isAdmin) || this.auth.isInstituteAdmin;
  }

  platformStats: PlatformStats = {
    totalOrganizations: 0,
    activeOrganizations: 0,
    expiredOrganizations: 0,
    totalRevenue: 0,
    renewalCount: 0,
    renewalPercentage: 0
  };

  overview: Overview = EMPTY_OVERVIEW;
  loading = true;

  ngOnInit() {
    if (this.isPlatformAdmin) {
      this.loadPlatformStats();
    } else {
      this.loadOverview();
    }
  }

  loadPlatformStats() {
    this.api.get<PlatformStats>('/api/saas/stats').subscribe({
      next: (data) => {
        this.platformStats = data;
        this.loading = false;
      },
      error: (err) => {
        console.error('Failed to load platform stats', err);
        this.loading = false;
      }
    });
  }

  loadOverview() {
    this.api.get<Overview>('/api/dashboard/overview').subscribe({
      next: (data) => {
        this.overview = { ...EMPTY_OVERVIEW, ...data };
        this.loading = false;
      },
      error: (err) => {
        console.error('Failed to load dashboard overview', err);
        this.loading = false;
      }
    });
  }

  /** Highest batchBreakdown total, used to scale the placed/unplaced bars. */
  get maxBatchTotal(): number {
    const totals = this.overview.batchBreakdown.map(b => b.totalStudents);
    return totals.length ? Math.max(...totals, 1) : 1;
  }

  barWidth(value: number): string {
    return Math.round((value / this.maxBatchTotal) * 100) + '%';
  }

  /** Rounds bytes into a human MB/GB display for the storage breakdown. */
  formatBytes(bytes: number | undefined): string {
    if (!bytes) return '0 MB';
    const mb = bytes / (1024 * 1024);
    if (mb < 1024) return mb.toFixed(1) + ' MB';
    return (mb / 1024).toFixed(2) + ' GB';
  }

  attendanceClass(pct: number): string {
    if (pct >= 85) return 'badge-success';
    if (pct >= 75) return 'badge-warning';
    return 'badge-danger';
  }

  storagePercent(): number {
    const used = this.overview.kpi.subscriptionQuotas?.storageGbUsed ?? 0;
    const limit = this.overview.kpi.subscriptionQuotas?.storageGbLimit ?? 0;
    if (!limit) return 0;
    return Math.min(100, Math.round((used / limit) * 100));
  }

  studentQuotaPercent(): number {
    const used = this.overview.kpi.subscriptionQuotas?.activeStudentsUsed ?? 0;
    const limit = this.overview.kpi.subscriptionQuotas?.maxStudents ?? 0;
    if (!limit) return 0;
    return Math.min(100, Math.round((used / limit) * 100));
  }

  facultyQuotaPercent(): number {
    const used = this.overview.kpi.subscriptionQuotas?.facultyUsed ?? 0;
    const limit = this.overview.kpi.subscriptionQuotas?.maxFaculty ?? 0;
    if (!limit) return 0;
    return Math.min(100, Math.round((used / limit) * 100));
  }

  revenueByModeEntries(): { mode: string; amount: number }[] {
    const rec = this.overview.kpi.revenueByMode || {};
    return Object.keys(rec).map(mode => ({ mode, amount: rec[mode] }));
  }
}

