import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { ApiService } from '../../../services/api.service';

interface LeaderboardMyRank {
  rank: number;
  score: number;
  assignmentsSubmitted: number;
  examsSubmitted: number;
  attendancePercent: number;
}

interface StudentStats {
  student: {
    id: number;
    name: string;
    email: string;
    phone: string;
    batchId: number | null;
    batchName: string;
    planName: string;
  };
  attendance: {
    totalClasses: number;
    attended: number;
    missed: number;
    percentage: number;
  };
  assignments: {
    totalAssignments: number;
    submitted: number;
    pending: number;
    overdue: number;
    submissionPercentage: number;
    averageMarks: number;
  };
  exams: {
    totalExams: number;
    attended_exams: number;
    passed: number;
    failed: number;
    passPercentage: number;
    averageScore: number;
  };
  placements: {
    isPlaced: boolean;
    companyName: string;
    role: string;
    packageAmount: number;
    totalApplications: number;
    selected: number;
    rejected: number;
  };
  courses: {
    totalCourses: number;
    completed: number;
    inProgress: number;
    averageProgress: number;
    averageRating: number;
  };
  attendanceRecords: AttendanceRecord[];
  assignmentRecords: AssignmentRecord[];
  examRecords: ExamRecord[];
  courseRecords: CourseRecord[];
  placementRecords: PlacementRecord[];
}

interface AttendanceRecord {
  eventId: number;
  eventName: string;
  eventType: string;
  date: string;
  present: boolean;
  remarks: string;
  subject?: string | null;
  isoDate?: string | null;
}

interface MonthGridCell {
  day: number;
  isoDate: string;
  status: 'present' | 'absent' | 'none';
}

interface AssignmentRecord {
  assignmentId: number;
  title: string;
  courseName: string;
  dueDate: string;
  submitted: boolean;
  marksObtained: number;
  totalMarks: number;
  feedback: string;
  isGraded: boolean;
}

interface ExamRecord {
  examId: number;
  title: string;
  courseName: string;
  examDate: string;
  marksObtained: number;
  totalMarks: number;
  percentage: number;
  status: string;
}

interface CourseRecord {
  courseId: number;
  courseName: string;
  courseCode: string;
  progressPercentage: number;
  completed: boolean;
  rating: number;
  feedback: string;
}

interface PlacementRecord {
  driveId: number;
  companyName: string;
  role: string;
  packageAmount: number;
  status: string;
  description: string;
}

@Component({
  selector: 'app-student-detail',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="page-header">
      <div style="display:flex;align-items:center;gap:16px;">
        <button class="btn btn-secondary" (click="goBack()" style="padding:8px 16px;">
          ← Back
        </button>
        <h1 style="font-size:24px;font-weight:700;margin:0;">Student Profile</h1>
      </div>
    </div>

    <div *ngIf="loading" style="display:flex;justify-content:center;align-items:center;min-height:400px;">
      <div class="spinner-border" role="status">
        <span class="visually-hidden">Loading...</span>
      </div>
    </div>

    <div *ngIf="!loading && stats" class="student-detail-container">
      <!-- Student Info Card -->
      <div class="card student-info-card">
        <div class="student-header">
          <div class="student-avatar">
            {{getInitials(stats.student.name)}}
          </div>
          <div class="student-basic-info">
            <h2 style="margin:0;font-size:22px;font-weight:700;">{{stats.student.name}}</h2>
            <p style="margin:4px 0;color:#64748B;font-size:14px;">{{stats.student.email}}</p>
            <p style="margin:4px 0;color:#64748B;font-size:14px;">{{stats.student.phone || 'No phone'}}</p>
            <div style="display:flex;gap:8px;margin-top:8px;">
              <span *ngIf="stats.student.batchName" class="badge" style="background:#EEF2FF;color:#4338CA;">
                👥 {{stats.student.batchName}}
              </span>
              <span *ngIf="stats.student.planName" class="badge badge-warning">
                ⭐ {{stats.student.planName}}
              </span>
            </div>
          </div>
        </div>
      </div>

      <!-- Stats Tiles -->
      <div class="stats-grid">
        <!-- Attendance Tile -->
        <div class="stat-card">
          <!--<div class="stat-icon attendance-icon">📅</div>-->
          <div class="stat-content">
            <h3>Attendance</h3>
            <div class="stat-value">{{stats.attendance.percentage | number:'1.1-1'}}%</div>
            <p class="stat-detail">{{stats.attendance.attended}} / {{stats.attendance.totalClasses}} classes</p>
            <p class="stat-detail text-muted">Missed: {{stats.attendance.missed}}</p>
          </div>
          <div class="progress-ring" [ngStyle]="{'background': getAttendanceColor(stats.attendance.percentage)}">
            <span>{{stats.attendance.percentage | number:'1.0-0'}}%</span>
          </div>
        </div>

        <!-- Assignments Tile -->
        <div class="stat-card">
          <!--<div class="stat-icon assignments-icon">📝</div>-->
          <div class="stat-content">
            <h3>Assignments</h3>
            <div class="stat-value">{{stats.assignments.submissionPercentage | number:'1.1-1'}}%</div>
            <p class="stat-detail">{{stats.assignments.submitted}} / {{stats.assignments.totalAssignments}} submitted</p>
            <p class="stat-detail text-danger" *ngIf="stats.assignments.overdue > 0">Overdue: {{stats.assignments.overdue}}</p>
          </div>
          <div class="stat-badge" [class.badge-success]="stats.assignments.submissionPercentage >= 80" 
               [class.badge-warning]="stats.assignments.submissionPercentage >= 50 && stats.assignments.submissionPercentage < 80"
               [class.badge-danger]="stats.assignments.submissionPercentage < 50">
            Avg: {{stats.assignments.averageMarks | number:'1.0-0'}}
          </div>
        </div>

        <!-- Exams Tile -->
        <div class="stat-card">
          <!--<div class="stat-icon exams-icon">📊</div>-->
          <div class="stat-content">
            <h3>Exams</h3>
            <div class="stat-value">{{stats.exams.passPercentage | number:'1.1-1'}}%</div>
            <p class="stat-detail">Pass Rate</p>
            <p class="stat-detail">{{stats.exams.passed}} Passed / {{stats.exams.failed}} Failed</p>
          </div>
          <div class="stat-badge badge-success">
            Avg: {{stats.exams.averageScore | number:'1.0-0'}}%
          </div>
        </div>

        <!-- Courses Tile -->
        <div class="stat-card">
          <!--<div class="stat-icon courses-icon">📚</div>-->
          <div class="stat-content">
            <h3>Courses</h3>
            <div class="stat-value">{{stats.courses.completed}}</div>
            <p class="stat-detail">Completed / {{stats.courses.totalCourses}} total</p>
            <p class="stat-detail">Progress: {{stats.courses.averageProgress | number:'1.0-0'}}%</p>
          </div>
          <div class="stat-badge badge-warning" *ngIf="stats.courses.averageRating > 0">
            ⭐ {{stats.courses.averageRating | number:'1.1-0'}}
          </div>
        </div>

        <!-- Placements Tile -->
        <div class="stat-card" [class.placed]="stats.placements.isPlaced">
          <!--<div class="stat-icon placements-icon">💼</div>-->
          <div class="stat-content">
            <h3>Placement</h3>
            <div class="stat-value" *ngIf="stats.placements.isPlaced">Placed!</div>
            <div class="stat-value" *ngIf="!stats.placements.isPlaced">Not Placed</div>
            <!--<p class="stat-detail" *ngIf="stats.placements.companyName">{{stats.placements.companyName}}</p>-->
            <!--<p class="stat-detail" *ngIf="stats.placements.role">{{stats.placements.role}}</p>-->
            <!--<p class="stat-detail" *ngIf="stats.placements.packageAmount">₹{{stats.placements.packageAmount | number}} LPA</p>-->
          </div>
          <div class="stat-badge" *ngIf="stats.placements.totalApplications > 0">
            {{stats.placements.selected}} selected / {{stats.placements.rejected}} rejected
          </div>
        </div>

        <!-- Leaderboard Tile -->
        <div class="stat-card">
          <div class="stat-content">
            <h3>Leaderboard</h3>
            <ng-container *ngIf="myRank">
              <div class="stat-value">#{{myRank.rank}}</div>
              <p class="stat-detail">Score: {{myRank.score}} pts this week</p>
              <p class="stat-detail text-muted">{{myRank.assignmentsSubmitted}} assignments · {{myRank.examsSubmitted}} exams</p>
            </ng-container>
            <ng-container *ngIf="!myRank">
              <div class="stat-value">—</div>
              <p class="stat-detail text-muted">No activity this week</p>
            </ng-container>
          </div>
          <div class="stat-badge" *ngIf="myRank">
            🏆 {{myRank.attendancePercent | number:'1.0-0'}}% att.
          </div>
        </div>
      </div>

      <!-- Detailed Tables -->
      <div class="details-section">
        <div class="details-grid">
        <!-- Attendance Records -->
        <div class="card">
          <h3 class="section-title">Attendance Records</h3>
          <div class="table-responsive">
            <table class="table">
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Event</th>
                  <th>Type</th>
                  <th>Status</th>
                  <th>Remarks</th>
                </tr>
              </thead>
              <tbody>
                <tr *ngFor="let record of stats.attendanceRecords">
                  <td>{{record.date || '-'}}</td>
                  <td>{{record.eventName || '-'}}</td>
                  <td><span class="badge">{{record.eventType || '-'}}</span></td>
                  <td>
                    <span class="badge" [class.badge-success]="record.present" [class.badge-danger]="!record.present">
                      {{record.present ? 'Present' : 'Absent'}}
                    </span>
                  </td>
                  <td>{{record.remarks || '-'}}</td>
                </tr>
                <tr *ngIf="stats.attendanceRecords.length === 0">
                  <td colspan="5" style="text-align:center;color:#64748B;padding:24px;">No attendance records found</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- Assignment Records -->
        <div class="card">
          <h3 class="section-title">Assignment Details</h3>
          <div class="table-responsive">
            <table class="table">
              <thead>
                <tr>
                  <th>Title</th>
                  <th>Course</th>
                  <th>Due Date</th>
                  <th>Status</th>
                  <th>Marks</th>
                  <th>Feedback</th>
                </tr>
              </thead>
              <tbody>
                <tr *ngFor="let record of stats.assignmentRecords">
                  <td>{{record.title}}</td>
                  <td>{{record.courseName || '-'}}</td>
                  <td>{{record.dueDate || '-'}}</td>
                  <td>
                    <span class="badge" [class.badge-success]="record.submitted" [class.badge-warning]="!record.submitted">
                      {{record.submitted ? 'Submitted' : 'Pending'}}
                    </span>
                    <span *ngIf="record.isGraded" class="badge badge-success" style="margin-left:4px;">Graded</span>
                  </td>
                  <td>
                    <span *ngIf="record.marksObtained !== null">{{record.marksObtained}} / {{record.totalMarks}}</span>
                    <span *ngIf="record.marksObtained === null">-</span>
                  </td>
                  <td style="max-width:200px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;" 
                      [title]="record.feedback || '-'">{{record.feedback || '-'}}</td>
                </tr>
                <tr *ngIf="stats.assignmentRecords.length === 0">
                  <td colspan="6" style="text-align:center;color:#64748B;padding:24px;">No assignment records found</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- Exam Records -->
        <div class="card">
          <h3 class="section-title">Exam Results</h3>
          <div class="table-responsive">
            <table class="table">
              <thead>
                <tr>
                  <th>Exam</th>
                  <th>Course</th>
                  <th>Date</th>
                  <th>Marks</th>
                  <th>Percentage</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                <tr *ngFor="let record of stats.examRecords">
                  <td>{{record.title || '-'}}</td>
                  <td>{{record.courseName || '-'}}</td>
                  <td>{{record.examDate || '-'}}</td>
                  <td>{{record.marksObtained != null ? record.marksObtained + ' / ' + (record.totalMarks ?? '—') : '—'}}</td>
                  <td>{{record.percentage > 0 ? (record.percentage | number:'1.1-1') + '%' : '—'}}</td>
                  <td>
                    <span class="badge" [class.badge-success]="record.status === 'Passed'" 
                          [class.badge-danger]="record.status === 'Failed'"
                          [class.badge-secondary]="record.status === 'N/A' || record.status === 'Not Attempted'">
                      {{record.status === 'N/A' ? 'Not Attempted' : record.status}}
                    </span>
                  </td>
                </tr>
                <tr *ngIf="stats.examRecords.length === 0">
                  <td colspan="6" style="text-align:center;color:#64748B;padding:24px;">No exam records found</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- Course Records -->
        <div class="card">
          <h3 class="section-title">Course Progress</h3>
          <div class="table-responsive">
            <table class="table">
              <thead>
                <tr>
                  <th>Course</th>
                  <th>Code</th>
                  <th>Progress</th>
                  <th>Status</th>
                  <th>Rating</th>
                  <th>Feedback</th>
                </tr>
              </thead>
              <tbody>
                <tr *ngFor="let record of stats.courseRecords">
                  <td>{{record.courseName}}</td>
                  <td><span class="badge">{{record.courseCode || '-'}}</span></td>
                  <td>
                    <div class="progress-bar-container">
                      <div class="progress-bar" [ngStyle]="{'width.%': record.progressPercentage}"></div>
                      <span style="margin-left:8px;font-size:13px;">{{record.progressPercentage}}%</span>
                    </div>
                  </td>
                  <td>
                    <span class="badge" [class.badge-success]="record.completed" [class.badge-warning]="!record.completed">
                      {{record.completed ? 'Completed' : 'In Progress'}}
                    </span>
                  </td>
                  <td>{{record.rating ? ('⭐'.repeat(record.rating > 5 ? 5 : record.rating)) : '-'}}</td>
                  <td style="max-width:200px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;" 
                      [title]="record.feedback || '-'">{{record.feedback || '-'}}</td>
                </tr>
                <tr *ngIf="stats.courseRecords.length === 0">
                  <td colspan="6" style="text-align:center;color:#64748B;padding:24px;">No course records found</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- Placement Records -->
        <div class="card">
          <h3 class="section-title">Placement Applications</h3>
          <div class="table-responsive">
            <table class="table">
              <thead>
                <tr>
                  <th>Company</th>
                  <th>Role</th>
                  <th>Package</th>
                  <th>Status</th>
                  <th>Description</th>
                </tr>
              </thead>
              <tbody>
                <tr *ngFor="let record of stats.placementRecords">
                  <td>{{record.companyName || '-'}}</td>
                  <td>{{record.role || '-'}}</td>
                  <td>{{record.packageAmount ? ('₹' + (record.packageAmount | number) + ' LPA') : '-'}}</td>
                  <td>
                    <span class="badge" 
                          [class.badge-success]="record.status === 'SELECTED'" 
                          [class.badge-danger]="record.status === 'REJECTED'"
                          [class.badge-warning]="record.status === 'APPLIED' || record.status === 'OPEN'">
                      {{record.status || '-'}}
                    </span>
                  </td>
                  <td style="max-width:200px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;" 
                      [title]="record.description || '-'">{{record.description || '-'}}</td>
                </tr>
                <tr *ngIf="stats.placementRecords.length === 0">
                  <td colspan="5" style="text-align:center;color:#64748B;padding:24px;">No placement records found</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
        </div>

        <!-- Daily Attendance calendar grid -->
        <div class="card" *ngIf="subjectOptions.length > 0 || dailyFilteredRecords.length > 0">
          <h3 class="section-title">Daily Attendance</h3>

          <div class="daily-toolbar">
            <div class="subject-pills" *ngIf="subjectOptions.length > 0">
              <button class="pill" [class.pill-active]="selectedSubject === null" (click)="selectedSubject = null">All</button>
              <button class="pill" *ngFor="let s of subjectOptions" [class.pill-active]="selectedSubject === s" (click)="selectedSubject = s">{{s}}</button>
            </div>
            <div class="date-range">
              <label>From</label>
              <input type="date" [(ngModel)]="dateFrom">
              <label>To</label>
              <input type="date" [(ngModel)]="dateTo">
            </div>
            <div class="attendance-summary">
              {{ dailyAttendancePercent }}% attended
              <span class="text-muted">({{ dailyFilteredRecords.length }} days)</span>
            </div>
          </div>

          <div class="month-grid-header">
            <button class="btn btn-secondary" style="padding:4px 12px;" (click)="prevMonth()">‹</button>
            <div style="font-weight:600;">{{ viewMonthLabel }}</div>
            <button class="btn btn-secondary" style="padding:4px 12px;" (click)="nextMonth()">›</button>
          </div>
          <div class="month-grid">
            <div class="month-grid-cell" *ngFor="let c of monthGridCells"
                 [class.status-present]="c.status === 'present'"
                 [class.status-absent]="c.status === 'absent'"
                 [title]="c.isoDate">
              {{ c.day }}
            </div>
          </div>
          <div class="grid-legend">
            <span><span class="legend-swatch status-present"></span> Present</span>
            <span><span class="legend-swatch status-absent"></span> Absent</span>
          </div>
        </div>
      </div>
    </div>

    <div *ngIf="!loading && !stats" style="display:flex;justify-content:center;align-items:center;min-height:400px;">
      <div class="alert alert-danger">Student not found or error loading data</div>
    </div>
  `,
  styles: [`
    .student-detail-container {
      max-width: 1400px;
      margin: 0 auto;
    }

    .student-info-card {
      margin-bottom: 24px;
    }

    .student-header {
      display: flex;
      align-items: center;
      gap: 24px;
      padding: 24px;
    }

    .student-avatar {
      width: 80px;
      height: 80px;
      border-radius: 50%;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      display: flex;
      align-items: center;
      justify-content: center;
      color: white;
      font-size: 28px;
      font-weight: 700;
      flex-shrink: 0;
    }

    .student-basic-info {
      flex: 1;
    }

    .stats-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      gap: 20px;
      margin-bottom: 24px;
    }

    .stat-card {
      background: white;
      border-radius: 12px;
      padding: 24px;
      box-shadow: 0 1px 3px rgba(0,0,0,0.1);
      display: flex;
      align-items: center;
      gap: 16px;
      position: relative;
      overflow: hidden;
    }

    .stat-card.placed {
      border: 2px solid #10B981;
      background: linear-gradient(135deg, #f0fdf4 0%, #ffffff 100%);
    }

    .stat-icon {
      width: 56px;
      height: 56px;
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 28px;
      flex-shrink: 0;
    }

    .attendance-icon { background: #EEF2FF; }
    .assignments-icon { background: #FEF3C7; }
    .exams-icon { background: #E0E7FF; }
    .courses-icon { background: #F3E8FF; }
    .placements-icon { background: #D1FAE5; }

    .stat-content {
      flex: 1;
    }

    .stat-content h3 {
      margin: 0 0 8px 0;
      font-size: 14px;
      font-weight: 600;
      color: #64748B;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }

    .stat-value {
      font-size: 28px;
      font-weight: 700;
      color: #1e293b;
      margin-bottom: 4px;
    }

    .stat-detail {
      margin: 2px 0;
      font-size: 13px;
      color: #64748B;
    }

    .text-muted { color: #64748B !important; }
    .text-danger { color: #EF4444 !important; }

    .progress-ring {
      width: 60px;
      height: 60px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      color: white;
      font-weight: 700;
      font-size: 14px;
      flex-shrink: 0;
    }

    .stat-badge {
      padding: 6px 12px;
      border-radius: 8px;
      font-size: 12px;
      font-weight: 600;
      flex-shrink: 0;
    }

    .details-section {
      display: flex;
      flex-direction: column;
      gap: 24px;
    }

    .details-grid {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 24px;
      align-items: start;
    }

    .details-grid .card {
      margin-bottom: 0;
      overflow: hidden;
    }

    /* Detailed tables are tall; keep them scrollable inside a fixed height so
       the two-column grid stays balanced instead of sprawling down the page. */
    .details-grid .table-responsive {
      max-height: 360px;
      overflow-y: auto;
    }

    @media (max-width: 1200px) {
      .details-grid { grid-template-columns: 1fr; }
    }

    .section-title {
      font-size: 18px;
      font-weight: 700;
      margin: 0 0 20px 0;
      color: #1e293b;
      padding-bottom: 12px;
      border-bottom: 2px solid #e2e8f0;
    }

    .table {
      width: 100%;
      border-collapse: collapse;
    }

    .table th {
      background: #f8fafc;
      padding: 12px 16px;
      text-align: left;
      font-weight: 600;
      font-size: 13px;
      color: #64748B;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      border-bottom: 1px solid #e2e8f0;
    }

    .table td {
      padding: 12px 16px;
      border-bottom: 1px solid #f1f5f9;
      font-size: 14px;
    }

    .table tr:hover {
      background: #f8fafc;
    }

    .progress-bar-container {
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .progress-bar {
      height: 8px;
      border-radius: 4px;
      background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
      min-width: 30px;
    }

    .page-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 24px;
    }

    .daily-toolbar {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 16px;
      margin-bottom: 16px;
    }

    .subject-pills {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
    }

    .pill {
      padding: 6px 14px;
      border-radius: 999px;
      border: 1px solid #e2e8f0;
      background: #f8fafc;
      color: #475569;
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
    }

    .pill-active {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      border-color: transparent;
      color: #fff;
    }

    .date-range {
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 13px;
      color: #64748B;
    }

    .date-range input {
      padding: 6px 8px;
      border: 1px solid #e2e8f0;
      border-radius: 6px;
      font-size: 13px;
    }

    .attendance-summary {
      font-weight: 700;
      color: #1e293b;
      font-size: 14px;
    }

    .month-grid-header {
      display: flex;
      justify-content: center;
      align-items: center;
      gap: 16px;
      margin-bottom: 12px;
    }

    .month-grid {
      display: grid;
      grid-template-columns: repeat(7, 1fr);
      gap: 6px;
    }

    .month-grid-cell {
      display: flex;
      align-items: center;
      justify-content: center;
      aspect-ratio: 1;
      border-radius: 6px;
      background: #f1f5f9;
      color: #64748B;
      font-size: 13px;
      font-weight: 600;
    }

    .month-grid-cell.status-present {
      background: #dcfce7;
      color: #059669;
    }

    .month-grid-cell.status-absent {
      background: #fee2e2;
      color: #DC2626;
    }

    .grid-legend {
      display: flex;
      gap: 20px;
      margin-top: 12px;
      font-size: 13px;
      color: #64748B;
    }

    .legend-swatch {
      display: inline-block;
      width: 12px;
      height: 12px;
      border-radius: 3px;
      margin-right: 6px;
      vertical-align: middle;
    }

    .legend-swatch.status-present {
      background: #dcfce7;
    }

    .legend-swatch.status-absent {
      background: #fee2e2;
    }
  `]
})
export class StudentDetailComponent implements OnInit {
    Math = Math;
  stats: StudentStats | null = null;
  loading = true;
  studentId: number = 0;

  selectedSubject: string | null = null;
  dateFrom: string = '';
  dateTo: string = '';
  viewMonth: string = new Date().toISOString().slice(0, 7);
  myRank: LeaderboardMyRank | null = null;

  constructor(
    private route: ActivatedRoute,
    private router: Router,
    private apiService: ApiService
  ) {}

  ngOnInit() {
    const id = this.route.snapshot.paramMap.get('id');
    if (id) {
      this.studentId = +id;
      this.loadStudentStats();
    } else {
      this.loading = false;
    }
  }

  loadStudentStats() {
    this.loading = true;
    this.apiService.get<StudentStats>(`/api/student-stats/${this.studentId}`).subscribe({
      next: (data) => {
        this.stats = data;
        this.loading = false;
        this.loadMyRank();
      },
      error: (err) => {
        console.error('Failed to load student stats', err);
        this.loading = false;
        this.stats = null;
      }
    });
  }

  loadMyRank() {
    const batchId = this.stats?.student?.batchId;
    const query = batchId != null ? `&batchId=${batchId}` : '';
    this.apiService.get<{ myRank?: LeaderboardMyRank }>(`/api/leaderboard?studentId=${this.studentId}${query}`).subscribe({
      next: (data) => { this.myRank = data.myRank ?? null; },
      error: (err) => { console.error('Failed to load leaderboard rank', err); this.myRank = null; }
    });
  }

  goBack() {
    this.router.navigate(['/students']);
  }

  getInitials(name: string): string {
    if (!name) return '?';
    const parts = name.split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
  }

  getAttendanceColor(percentage: number): string {
    if (percentage >= 80) return 'linear-gradient(135deg, #10B981 0%, #059669 100%)';
    if (percentage >= 60) return 'linear-gradient(135deg, #F59E0B 0%, #D97706 100%)';
    return 'linear-gradient(135deg, #EF4444 0%, #DC2626 100%)';
  }

  get subjectOptions(): string[] {
    const records = this.stats?.attendanceRecords || [];
    const subjects = new Set<string>();
    for (const r of records) {
      if (r.subject) subjects.add(r.subject);
    }
    return Array.from(subjects).sort();
  }

  get dailyFilteredRecords(): AttendanceRecord[] {
    const records = this.stats?.attendanceRecords || [];
    return records.filter(r => {
      if (!r.isoDate) return false;
      if (this.selectedSubject !== null && r.subject !== this.selectedSubject) return false;
      if (this.dateFrom && r.isoDate < this.dateFrom) return false;
      if (this.dateTo && r.isoDate > this.dateTo) return false;
      return true;
    });
  }

  get dailyAttendancePercent(): number {
    const records = this.dailyFilteredRecords;
    if (records.length === 0) return 0;
    const present = records.filter(r => r.present).length;
    return Math.round((present / records.length) * 1000) / 10;
  }

  get viewMonthLabel(): string {
    const [year, month] = this.viewMonth.split('-').map(Number);
    return new Date(year, month - 1, 1).toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
  }

  get monthGridCells(): MonthGridCell[] {
    const [year, month] = this.viewMonth.split('-').map(Number);
    const daysInMonth = new Date(year, month, 0).getDate();
    const records = (this.stats?.attendanceRecords || []).filter(r => {
      if (!r.isoDate) return false;
      if (this.selectedSubject !== null && r.subject !== this.selectedSubject) return false;
      return true;
    });
    const byDate = new Map<string, boolean>();
    for (const r of records) {
      if (r.isoDate) byDate.set(r.isoDate, r.present);
    }
    const cells: MonthGridCell[] = [];
    for (let day = 1; day <= daysInMonth; day++) {
      const isoDate = `${this.viewMonth}-${String(day).padStart(2, '0')}`;
      const present = byDate.get(isoDate);
      cells.push({
        day,
        isoDate,
        status: present === undefined ? 'none' : (present ? 'present' : 'absent')
      });
    }
    return cells;
  }

  prevMonth() {
    const [year, month] = this.viewMonth.split('-').map(Number);
    const d = new Date(year, month - 2, 1);
    this.viewMonth = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
  }

  nextMonth() {
    const [year, month] = this.viewMonth.split('-').map(Number);
    const d = new Date(year, month, 1);
    this.viewMonth = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
  }
}