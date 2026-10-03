import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient } from '@angular/common/http';
import { environment } from '../../../environments/environment';

export interface DetailedInterviewSessionItem {
  id?: number;
  roomCode: string;
  title: string;
  status: string;
  scheduledAt?: string;
  startedAt?: string;
  endedAt?: string;
  slotId?: number;
  driveId?: number;
  companyName?: string;
  driveRole?: string;

  candidateId?: number;
  candidateName: string;
  candidateEmail?: string;
  candidatePhone?: string;
  batchName?: string;

  interviewerId?: number;
  interviewerName?: string;
  interviewerEmail?: string;

  problemTitle?: string;
  problemDifficulty?: string;

  hiringDecision?: string;
  problemSolvingScore?: number;
  technicalCompetencyScore?: number;
  codeQualityScore?: number;
  communicationScore?: number;
  interviewerNotes?: string;
  candidateNotes?: string;
  submittedCode?: string;
  hmsMeetingUrl?: string;
}

@Component({
  selector: 'app-interviews-admin',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="interviews-container">
      <!-- Page Header -->
      <div class="page-header">
        <div>
          <h1 class="page-title">
            <span class="icon-badge">🎤</span> 1-on-1 Mock Interviews & Technical Rooms
          </h1>
          <p class="page-subtitle">
            Conduct low-latency WebRTC video rounds, live collaborative coding, and structured candidate evaluation with 100ms.
          </p>
        </div>
        <div class="header-actions">
          <button class="btn btn-secondary" (click)="openScheduleModal()">
            <span>➕</span> Schedule Interview
          </button>
          <button class="btn btn-primary" (click)="createInstantMockRoom()">
            <span>🚀</span> Launch Instant Room (100ms)
          </button>
        </div>
      </div>

      <!-- Metric Stats Cards -->
      <div class="metrics-grid">
        <div class="metric-card">
          <div class="metric-icon" style="background: rgba(39, 217, 211, 0.15); color: #27D9D3;">🎤</div>
          <div class="metric-info">
            <span class="metric-value">{{ sessions.length }}</span>
            <span class="metric-label">Active Listed</span>
          </div>
        </div>
        <div class="metric-card">
          <div class="metric-icon" style="background: rgba(16, 185, 129, 0.15); color: #10B981;">🔴</div>
          <div class="metric-info">
            <span class="metric-value">{{ activeLiveCount }}</span>
            <span class="metric-label">Live Active Calls</span>
          </div>
        </div>
        <div class="metric-card">
          <div class="metric-icon" style="background: rgba(99, 102, 241, 0.15); color: #6366F1;">📋</div>
          <div class="metric-info">
            <span class="metric-value">{{ upcomingCount }}</span>
            <span class="metric-label">Upcoming / Today</span>
          </div>
        </div>
        <div class="metric-card">
          <div class="metric-icon" style="background: rgba(245, 158, 11, 0.15); color: #F59E0B;">⭐</div>
          <div class="metric-info">
            <span class="metric-value">{{ hiredCount }}</span>
            <span class="metric-label">Recommended Hires</span>
          </div>
        </div>
      </div>

      <!-- Main Navigation Tabs (My Interviews vs Batch Interviews) -->
      <div class="main-tabs-wrapper">
        <div class="scope-tabs">
          <button
            class="scope-tab"
            [class.active]="activeScope === 'mine'"
            (click)="setScope('mine')"
          >
            <span>👤</span> My Interviews
            <span class="tab-badge" *ngIf="activeScope === 'mine'">{{ sessions.length }}</span>
          </button>
          <button
            class="scope-tab"
            [class.active]="activeScope === 'batch'"
            (click)="setScope('batch')"
          >
            <span>👥</span> Batch Students' Interviews
            <span class="tab-badge" *ngIf="activeScope === 'batch'">{{ sessions.length }}</span>
          </button>
        </div>

        <div class="time-filters">
          <button
            *ngFor="let tf of [
              { key: 'all', label: 'All Times' },
              { key: 'upcoming', label: 'Upcoming' },
              { key: 'today', label: 'Today' },
              { key: 'past', label: 'Past (<24h)' }
            ]"
            class="time-pill"
            [class.active]="timeFilter === tf.key"
            (click)="setTimeFilter(tf.key)"
          >
            {{ tf.label }}
          </button>
        </div>
      </div>

      <!-- Filters & Search Toolbar -->
      <div class="toolbar">
        <div class="search-box">
          <span class="search-icon">🔍</span>
          <input
            type="text"
            [(ngModel)]="searchQuery"
            placeholder="Search candidate, faculty, room code, company..."
          />
        </div>
        <div class="filter-tabs">
          <button
            *ngFor="let tab of ['ALL', 'SCHEDULED', 'LIVE', 'COMPLETED']"
            [class.active]="selectedTab === tab"
            (click)="selectedTab = tab"
          >
            {{ tab }}
          </button>
        </div>
      </div>

      <!-- Sessions Table -->
      <div class="table-card">
        <div *ngIf="loading" class="loading-state">
          <div class="spinner"></div>
          <p>Loading interview sessions...</p>
        </div>

        <div *ngIf="!loading && filteredSessions.length === 0" class="empty-state">
          <div class="empty-icon">📹</div>
          <h3>No interview sessions found</h3>
          <p>
            {{ activeScope === 'mine' ? 'No interviews scheduled for your login currently.' : 'No interviews scheduled for students in your batch.' }}
          </p>
          <button class="btn btn-primary" (click)="createInstantMockRoom()">Launch Instant Room</button>
        </div>

        <div *ngIf="!loading && filteredSessions.length > 0" class="table-responsive">
          <table class="interviews-table">
            <thead>
              <tr>
                <th>Room Code</th>
                <th>Candidate</th>
                <th>Interviewer / Faculty</th>
                <th>Placement / Topic</th>
                <th>Status</th>
                <th>Rubric & Decision</th>
                <th>Scheduled Time</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr *ngFor="let session of filteredSessions">
                <td>
                  <div class="room-pill" (click)="copyLink(session.roomCode)">
                    <code>{{ session.roomCode }}</code>
                    <span class="copy-hint" title="Copy Room Link">📋</span>
                  </div>
                </td>
                <td>
                  <div class="candidate-cell">
                    <div class="candidate-header-row">
                      <span class="candidate-name">{{ session.candidateName || 'Candidate' }}</span>
                      <button
                        *ngIf="session.candidateId"
                        class="btn-profile-badge"
                        (click)="viewCandidateProfile(session.candidateId, session.candidateName)"
                        title="View Full Candidate Profile"
                      >
                        👤 Profile
                      </button>
                    </div>
                    <span class="candidate-email">{{ session.candidateEmail || 'student@axisora.internal' }}</span>
                    <span *ngIf="session.batchName" class="candidate-batch">👥 {{ session.batchName }}</span>
                  </div>
                </td>
                <td>
                  <div class="interviewer-cell">
                    <span class="interviewer-name">{{ session.interviewerName || 'Lead Mentor' }}</span>
                    <span class="interviewer-email">{{ session.interviewerEmail || 'faculty@axisora.internal' }}</span>
                  </div>
                </td>
                <td>
                  <div class="challenge-cell">
                    <div *ngIf="session.companyName" class="company-tag">
                      🏢 {{ session.companyName }} <span *ngIf="session.driveRole">({{ session.driveRole }})</span>
                    </div>
                    <span class="challenge-title">{{ session.problemTitle || session.title || 'Technical Round' }}</span>
                    <span
                      *ngIf="session.problemDifficulty"
                      class="difficulty-tag"
                      [ngClass]="session.problemDifficulty.toLowerCase()"
                    >
                      {{ session.problemDifficulty }}
                    </span>
                  </div>
                </td>
                <td>
                  <span class="status-badge" [ngClass]="session.status.toLowerCase()">
                    <span *ngIf="session.status === 'LIVE'" class="pulse-dot"></span>
                    {{ session.status }}
                  </span>
                </td>
                <td>
                  <div *ngIf="session.hiringDecision" class="decision-cell">
                    <span class="decision-badge" [ngClass]="session.hiringDecision.toLowerCase()">
                      {{ formatDecision(session.hiringDecision) }}
                    </span>
                    <span *ngIf="session.problemSolvingScore" class="score-stars">
                      ⭐ {{ session.problemSolvingScore }}/5
                    </span>
                  </div>
                  <span *ngIf="!session.hiringDecision" class="pending-text">Pending evaluation</span>
                </td>
                <td>
                  <span class="date-text">{{ formatDate(session.scheduledAt || session.startedAt) }}</span>
                </td>
                <td>
                  <div class="action-buttons">
                    <button
                      class="btn-join"
                      (click)="joinRoom(session.roomCode)"
                      title="Enter live 100ms interview room"
                    >
                      <span>🎥</span> Join
                    </button>
                    <button
                      *ngIf="session.candidateId"
                      class="btn-icon"
                      (click)="viewCandidateProfile(session.candidateId, session.candidateName)"
                      title="View Candidate Profile"
                    >
                      👤
                    </button>
                    <button
                      class="btn-icon"
                      (click)="copyLink(session.roomCode)"
                      title="Copy invitation link"
                    >
                      🔗
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Schedule Modal -->
      <div class="modal-backdrop" *ngIf="showModal" (click)="closeModal()">
        <div class="modal-card" (click)="$event.stopPropagation()">
          <div class="modal-header">
            <h3>Schedule 1-on-1 Interview Room</h3>
            <button class="modal-close" (click)="closeModal()">✕</button>
          </div>
          <div class="modal-body">
            <div class="form-group">
              <label>Interview Title</label>
              <input
                type="text"
                [(ngModel)]="newSessionTitle"
                placeholder="e.g. Senior Full Stack Technical Round"
              />
            </div>
            <div class="form-group">
              <label>Candidate Name</label>
              <input
                type="text"
                [(ngModel)]="newCandidateName"
                placeholder="e.g. Alex Morgan"
              />
            </div>
            <div class="form-group">
              <label>Candidate Email</label>
              <input
                type="email"
                [(ngModel)]="newCandidateEmail"
                placeholder="e.g. alex@gmail.com"
              />
            </div>
            <div class="form-group">
              <label>Coding Challenge</label>
              <select [(ngModel)]="selectedQuestionId">
                <option *ngFor="let q of questions" [value]="q.id">
                  {{ q.title }} ({{ q.difficulty }})
                </option>
              </select>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-secondary" (click)="closeModal()">Cancel</button>
            <button class="btn btn-primary" (click)="submitSchedule()">
              Create & Launch Room
            </button>
          </div>
        </div>
      </div>

      <!-- Candidate Profile View Modal (Requirement 7) -->
      <div class="modal-backdrop" *ngIf="showProfileModal" (click)="closeProfileModal()">
        <div class="modal-card profile-modal-card" (click)="$event.stopPropagation()">
          <div class="modal-header">
            <div style="display:flex;align-items:center;gap:12px;">
              <div class="profile-avatar">{{ candidateInitials }}</div>
              <div>
                <h3 style="margin:0;font-size:17px;font-weight:700;color:#0F172A;">{{ candidateProfileName }}</h3>
                <p style="margin:2px 0 0 0;font-size:12px;color:#64748B;">Candidate Comprehensive Record</p>
              </div>
            </div>
            <button class="modal-close" (click)="closeProfileModal()">✕</button>
          </div>

          <div class="modal-body profile-modal-body">
            <div *ngIf="profileLoading" class="loading-state">
              <div class="spinner"></div>
              <p>Fetching candidate stats and profile...</p>
            </div>

            <div *ngIf="!profileLoading && candidateStats" class="profile-details-content">
              <!-- Basic Contact & Batch Strip -->
              <div class="profile-strip">
                <div class="strip-item">
                  <span class="strip-label">Email</span>
                  <span class="strip-val">{{ candidateStats.student?.email || 'N/A' }}</span>
                </div>
                <div class="strip-item">
                  <span class="strip-label">Phone</span>
                  <span class="strip-val">{{ candidateStats.student?.phone || 'N/A' }}</span>
                </div>
                <div class="strip-item">
                  <span class="strip-label">Batch</span>
                  <span class="strip-val" style="color:#0D9488;">👥 {{ candidateStats.student?.batchName || 'General' }}</span>
                </div>
                <div class="strip-item" *ngIf="candidateStats.student?.planName">
                  <span class="strip-label">Plan</span>
                  <span class="strip-val" style="color:#D97706;">⭐ {{ candidateStats.student?.planName }}</span>
                </div>
              </div>

              <!-- Stats Mini Grid -->
              <div class="profile-mini-grid">
                <!-- Attendance -->
                <div class="mini-stat-card">
                  <div class="mini-stat-title">Attendance</div>
                  <div class="mini-stat-value" [style.color]="candidateStats.attendance?.percentage >= 75 ? '#16A34A' : '#D97706'">
                    {{ candidateStats.attendance?.percentage | number:'1.0-1' }}%
                  </div>
                  <div class="mini-stat-sub">
                    {{ candidateStats.attendance?.attended || 0 }} / {{ candidateStats.attendance?.totalClasses || 0 }} classes
                  </div>
                </div>

                <!-- Assignments -->
                <div class="mini-stat-card">
                  <div class="mini-stat-title">Assignments</div>
                  <div class="mini-stat-value" style="color:#4F46E5;">
                    {{ candidateStats.assignments?.submissionPercentage | number:'1.0-1' }}%
                  </div>
                  <div class="mini-stat-sub">
                    Avg Marks: {{ candidateStats.assignments?.averageMarks | number:'1.0-1' }}
                  </div>
                </div>

                <!-- Exams -->
                <div class="mini-stat-card">
                  <div class="mini-stat-title">Exams Pass Rate</div>
                  <div class="mini-stat-value" style="color:#16A34A;">
                    {{ candidateStats.exams?.passPercentage | number:'1.0-1' }}%
                  </div>
                  <div class="mini-stat-sub">
                    {{ candidateStats.exams?.passed || 0 }} Passed · Avg: {{ candidateStats.exams?.averageScore | number:'1.0-1' }}%
                  </div>
                </div>

                <!-- Courses -->
                <div class="mini-stat-card">
                  <div class="mini-stat-title">Courses Completed</div>
                  <div class="mini-stat-value" style="color:#0D9488;">
                    {{ candidateStats.courses?.completed || 0 }} / {{ candidateStats.courses?.totalCourses || 0 }}
                  </div>
                  <div class="mini-stat-sub">
                    Progress: {{ candidateStats.courses?.averageProgress | number:'1.0-1' }}%
                  </div>
                </div>

                <!-- Placements -->
                <div class="mini-stat-card">
                  <div class="mini-stat-title">Placement Status</div>
                  <div class="mini-stat-value" [style.color]="candidateStats.placements?.isPlaced ? '#16A34A' : '#64748B'">
                    {{ candidateStats.placements?.isPlaced ? 'Placed!' : 'Active' }}
                  </div>
                  <div class="mini-stat-sub">
                    {{ candidateStats.placements?.totalApplications || 0 }} Applications
                  </div>
                </div>

                <!-- Total Feedbacks -->
                <div class="mini-stat-card">
                  <div class="mini-stat-title">Total Feedbacks</div>
                  <div class="mini-stat-value" style="color:#D97706;">
                    {{ candidateStats.feedbacks?.totalFeedbacks || 0 }}
                  </div>
                  <div class="mini-stat-sub">
                    {{ candidateStats.feedbacks?.recommendedHires || 0 }} Recommended Hires
                  </div>
                </div>
              </div>

              <!-- Past Feedback History in Modal -->
              <div class="profile-history-card" *ngIf="candidateStats.feedbackRecords && candidateStats.feedbackRecords.length > 0">
                <h4 style="margin:0 0 10px 0;font-size:13px;color:#0F172A;text-transform:uppercase;letter-spacing:0.5px;font-weight:700;">
                  Recent 1-on-1 Evaluations
                </h4>
                <div class="history-list">
                  <div class="history-item" *ngFor="let fb of candidateStats.feedbackRecords">
                    <div style="display:flex;justify-content:space-between;align-items:center;">
                      <strong style="color:#0F172A;">{{ fb.title || 'Technical Interview' }}</strong>
                      <span class="decision-badge" [ngClass]="(fb.hiringDecision || '').toLowerCase()">
                        {{ formatDecision(fb.hiringDecision) }}
                      </span>
                    </div>
                    <div style="font-size:12px;color:#64748B;margin-top:4px;">
                      Interviewer: {{ fb.interviewerName }} · {{ formatDate(fb.interviewDate) }}
                    </div>
                    <div style="font-size:12px;color:#334155;margin-top:4px;" *ngIf="fb.interviewerNotes">
                      "{{ fb.interviewerNotes }}"
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-secondary" (click)="closeProfileModal()">Close</button>
          </div>
        </div>
      </div>
    </div>
  `,
  styles: [`
    .interviews-container {
      padding: 0;
      color: var(--text, #134E4A);
      font-family: 'Inter', -apple-system, sans-serif;
    }
    .page-header {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      margin-bottom: 24px;
      flex-wrap: wrap;
      gap: 16px;
    }
    .page-title {
      font-size: 24px;
      font-weight: 700;
      color: #0F172A;
      margin: 0 0 6px 0;
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .icon-badge {
      font-size: 22px;
    }
    .page-subtitle {
      font-size: 13.5px;
      color: var(--text-secondary, #475569);
      margin: 0;
      max-width: 650px;
    }
    .header-actions {
      display: flex;
      gap: 12px;
    }
    .btn {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 10px 18px;
      border-radius: 8px;
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      border: none;
      transition: all 0.2s ease;
    }
    .btn-primary {
      background: var(--primary, #0D9488);
      color: #ffffff;
      box-shadow: 0 2px 6px rgba(13, 148, 136, 0.2);
    }
    .btn-primary:hover {
      background: var(--primary-hover, #0C8A7E);
      transform: translateY(-1px);
    }
    .btn-secondary {
      background: #FFFFFF;
      color: #334155;
      border: 1px solid #CBD5E1;
    }
    .btn-secondary:hover {
      background: #F1F5F9;
    }

    /* Metrics Grid */
    .metrics-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 16px;
      margin-bottom: 24px;
    }
    .metric-card {
      background: var(--surface, #FFFFFF);
      border: 1px solid var(--border-light, #E2E8F0);
      border-radius: var(--radius, 14px);
      padding: 18px;
      display: flex;
      align-items: center;
      gap: 14px;
      box-shadow: var(--shadow-sm, 0 1px 3px rgba(0,0,0,0.05));
    }
    .metric-icon {
      width: 44px;
      height: 44px;
      border-radius: 10px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 20px;
    }
    .metric-info {
      display: flex;
      flex-direction: column;
    }
    .metric-value {
      font-size: 22px;
      font-weight: 700;
      color: #0F172A;
      line-height: 1.2;
    }
    .metric-label {
      font-size: 12.5px;
      color: var(--text-secondary, #475569);
      margin-top: 2px;
      font-weight: 500;
    }

    /* Main Tabs */
    .main-tabs-wrapper {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 20px;
      flex-wrap: wrap;
      gap: 14px;
    }
    .scope-tabs {
      display: flex;
      background: #E6FFFA;
      padding: 4px;
      border-radius: 10px;
      border: 1px solid rgba(13, 148, 136, 0.2);
      gap: 4px;
    }
    .scope-tab {
      background: transparent;
      border: none;
      color: var(--text-secondary, #475569);
      padding: 8px 18px;
      font-size: 13.5px;
      font-weight: 600;
      border-radius: 8px;
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 8px;
      transition: all 0.15s;
    }
    .scope-tab.active {
      background: var(--primary, #0D9488);
      color: #FFFFFF;
      box-shadow: 0 2px 6px rgba(13, 148, 136, 0.25);
    }
    .tab-badge {
      background: rgba(255, 255, 255, 0.25);
      color: #FFFFFF;
      font-size: 11px;
      padding: 2px 7px;
      border-radius: 10px;
      margin-left: 2px;
    }
    .scope-tab:not(.active) .tab-badge {
      background: rgba(13, 148, 136, 0.12);
      color: var(--primary, #0D9488);
    }

    .time-filters {
      display: flex;
      gap: 6px;
      background: #FFFFFF;
      padding: 4px;
      border-radius: 8px;
      border: 1px solid var(--border-light, #E2E8F0);
    }
    .time-pill {
      background: transparent;
      border: none;
      color: var(--text-secondary, #475569);
      padding: 6px 12px;
      font-size: 12px;
      font-weight: 600;
      border-radius: 6px;
      cursor: pointer;
      transition: all 0.15s;
    }
    .time-pill.active {
      background: var(--primary, #0D9488);
      color: #FFFFFF;
    }

    /* Toolbar */
    .toolbar {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 16px;
      flex-wrap: wrap;
      gap: 12px;
    }
    .search-box {
      display: flex;
      align-items: center;
      background: #FFFFFF;
      border: 1px solid var(--border-light, #E2E8F0);
      border-radius: 8px;
      padding: 8px 14px;
      min-width: 320px;
      box-shadow: 0 1px 2px rgba(0,0,0,0.03);
    }
    .search-icon {
      margin-right: 8px;
      font-size: 14px;
    }
    .search-box input {
      background: transparent;
      border: none;
      color: #0F172A;
      font-size: 13px;
      outline: none;
      width: 100%;
    }
    .search-box input::placeholder {
      color: #94A3B8;
    }
    .filter-tabs {
      display: flex;
      background: #FFFFFF;
      padding: 4px;
      border-radius: 8px;
      border: 1px solid var(--border-light, #E2E8F0);
      gap: 4px;
    }
    .filter-tabs button {
      background: transparent;
      border: none;
      color: var(--text-secondary, #475569);
      padding: 6px 14px;
      font-size: 12px;
      font-weight: 600;
      border-radius: 6px;
      cursor: pointer;
      transition: all 0.15s;
    }
    .filter-tabs button.active {
      background: #CCFBF1;
      color: #0F766E;
      font-weight: 700;
    }

    /* Table Card */
    .table-card {
      background: var(--surface, #FFFFFF);
      border: 1px solid var(--border-light, #E2E8F0);
      border-radius: var(--radius, 14px);
      box-shadow: var(--shadow-sm, 0 1px 3px rgba(0,0,0,0.05));
      overflow: hidden;
      margin-bottom: 24px;
    }
    .table-responsive {
      overflow-x: auto;
    }
    .interviews-table {
      width: 100%;
      border-collapse: collapse;
      text-align: left;
      font-size: 13px;
    }
    .interviews-table th {
      background: var(--surface-alt, #F8FAFA);
      padding: 12px 16px;
      color: var(--text-secondary, #475569);
      font-weight: 600;
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      border-bottom: 1px solid var(--border-light, #E2E8F0);
    }
    .interviews-table td {
      padding: 14px 16px;
      border-bottom: 1px solid var(--border-light, #E2E8F0);
      vertical-align: middle;
      color: #1E293B;
    }
    .interviews-table tbody tr:hover td {
      background: #F8FAFC;
    }
    .room-pill {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: #F0FDFA;
      border: 1px solid #5EEAD4;
      color: #0F766E;
      padding: 4px 8px;
      border-radius: 6px;
      font-size: 12px;
      font-weight: 600;
      cursor: pointer;
    }
    .room-pill:hover {
      background: #CCFBF1;
    }
    .candidate-cell {
      display: flex;
      flex-direction: column;
      gap: 2px;
    }
    .candidate-header-row {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .candidate-name {
      font-weight: 600;
      color: #0F172A;
    }
    .btn-profile-badge {
      background: #EEF2FF;
      border: 1px solid #C7D2FE;
      color: #4F46E5;
      font-size: 10.5px;
      font-weight: 600;
      padding: 2px 6px;
      border-radius: 4px;
      cursor: pointer;
      transition: all 0.15s;
    }
    .btn-profile-badge:hover {
      background: #E0E7FF;
      color: #3730A3;
    }
    .candidate-email {
      font-size: 11.5px;
      color: #64748B;
    }
    .candidate-batch {
      font-size: 11px;
      color: #0D9488;
      font-weight: 600;
    }
    .interviewer-cell {
      display: flex;
      flex-direction: column;
      gap: 2px;
    }
    .interviewer-name {
      font-weight: 600;
      color: #0F172A;
    }
    .interviewer-email {
      font-size: 11.5px;
      color: #64748B;
    }
    .challenge-cell {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .company-tag {
      font-size: 11.5px;
      color: #0D9488;
      font-weight: 600;
    }
    .challenge-title {
      font-weight: 500;
      color: #1E293B;
    }
    .difficulty-tag {
      display: inline-block;
      align-self: flex-start;
      padding: 2px 8px;
      border-radius: 4px;
      font-size: 11px;
      font-weight: 600;
      text-transform: capitalize;
    }
    .difficulty-tag.easy {
      background: #DCFCE7;
      color: #166534;
    }
    .difficulty-tag.medium {
      background: #FEF3C7;
      color: #92400E;
    }
    .difficulty-tag.hard {
      background: #FEE2E2;
      color: #991B1B;
    }
    .status-badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 4px 10px;
      border-radius: 6px;
      font-size: 11.5px;
      font-weight: 600;
    }
    .status-badge.live {
      background: #FEE2E2;
      color: #DC2626;
      border: 1px solid #FCA5A5;
    }
    .status-badge.scheduled {
      background: #E0E7FF;
      color: #3730A3;
      border: 1px solid #C7D2FE;
    }
    .status-badge.completed {
      background: #DCFCE7;
      color: #166534;
      border: 1px solid #86EFAC;
    }
    .status-badge.cancelled {
      background: #F1F5F9;
      color: #64748B;
      border: 1px solid #E2E8F0;
    }
    .pulse-dot {
      width: 7px;
      height: 7px;
      background: #DC2626;
      border-radius: 50%;
      animation: pulse 1.2s infinite;
    }
    @keyframes pulse {
      0% { transform: scale(0.9); opacity: 1; }
      50% { transform: scale(1.3); opacity: 0.5; }
      100% { transform: scale(0.9); opacity: 1; }
    }
    .decision-cell {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .decision-badge {
      display: inline-block;
      padding: 3px 8px;
      border-radius: 4px;
      font-size: 11px;
      font-weight: 600;
    }
    .decision-badge.strong_hire, .decision-badge.strong-hire {
      background: #DCFCE7;
      color: #166534;
    }
    .decision-badge.hire {
      background: #CCFBF1;
      color: #0F766E;
    }
    .decision-badge.lean_hire, .decision-badge.lean-hire {
      background: #FEF3C7;
      color: #92400E;
    }
    .decision-badge.lean_reject, .decision-badge.lean-reject, .decision-badge.reject {
      background: #FEE2E2;
      color: #991B1B;
    }
    .pending-text {
      color: #94A3B8;
      font-size: 12px;
    }
    .score-stars {
      font-size: 11.5px;
      color: #D97706;
      font-weight: 600;
    }
    .date-text {
      font-size: 12.5px;
      color: #334155;
    }
    .action-buttons {
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .btn-join {
      background: #0D9488;
      color: #ffffff;
      border: none;
      padding: 6px 12px;
      border-radius: 6px;
      font-size: 12px;
      font-weight: 600;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 4px;
      transition: all 0.15s;
    }
    .btn-join:hover {
      background: #0B7070;
      transform: translateY(-1px);
      box-shadow: 0 4px 12px rgba(13, 148, 136, 0.25);
    }
    .btn-icon {
      background: #F1F5F9;
      border: 1px solid #E2E8F0;
      color: #475569;
      padding: 6px 9px;
      border-radius: 6px;
      cursor: pointer;
    }
    .btn-icon:hover {
      color: #0F172A;
      background: #E2E8F0;
    }

    /* Modals */
    .modal-backdrop {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background: rgba(15, 23, 42, 0.5);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 1000;
      backdrop-filter: blur(4px);
    }
    .modal-card {
      background: #FFFFFF;
      border: 1px solid var(--border-light, #E2E8F0);
      border-radius: 14px;
      width: 90%;
      max-width: 480px;
      box-shadow: 0 20px 40px rgba(0, 0, 0, 0.15);
    }
    .profile-modal-card {
      max-width: 680px;
      max-height: 90vh;
      display: flex;
      flex-direction: column;
    }
    .profile-avatar {
      width: 40px;
      height: 40px;
      border-radius: 50%;
      background: #0D9488;
      color: #ffffff;
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: 700;
      font-size: 16px;
    }
    .modal-header {
      padding: 16px 20px;
      border-bottom: 1px solid var(--border-light, #E2E8F0);
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .modal-header h3 {
      margin: 0;
      color: #0F172A;
      font-size: 16px;
      font-weight: 700;
    }
    .modal-close {
      background: transparent;
      border: none;
      color: #64748B;
      font-size: 18px;
      cursor: pointer;
    }
    .modal-close:hover {
      color: #0F172A;
    }
    .modal-body {
      padding: 20px;
      display: flex;
      flex-direction: column;
      gap: 14px;
    }
    .profile-modal-body {
      overflow-y: auto;
      max-height: calc(90vh - 130px);
    }
    .form-group {
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    .form-group label {
      font-size: 12.5px;
      color: #334155;
      font-weight: 600;
    }
    .form-group input, .form-group select {
      background: #FFFFFF;
      border: 1px solid #CBD5E1;
      border-radius: 8px;
      padding: 10px 12px;
      color: #0F172A;
      font-size: 13.5px;
      outline: none;
    }
    .form-group input:focus, .form-group select:focus {
      border-color: #0D9488;
      box-shadow: 0 0 0 3px rgba(13, 148, 136, 0.12);
    }
    .modal-footer {
      padding: 16px 20px;
      border-top: 1px solid var(--border-light, #E2E8F0);
      display: flex;
      justify-content: flex-end;
      gap: 10px;
      background: #F8FAFC;
      border-bottom-left-radius: 14px;
      border-bottom-right-radius: 14px;
    }

    /* Profile Modal Details */
    .profile-strip {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
      gap: 10px;
      background: #F0FDFA;
      padding: 14px 16px;
      border-radius: 8px;
      border: 1px solid #CCFBF1;
    }
    .strip-item {
      display: flex;
      flex-direction: column;
      gap: 2px;
    }
    .strip-label {
      font-size: 11px;
      color: #0F766E;
      text-transform: uppercase;
      font-weight: 600;
    }
    .strip-val {
      font-size: 13px;
      font-weight: 600;
      color: #0F172A;
    }
    .profile-mini-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
      gap: 12px;
      margin-top: 14px;
    }
    .mini-stat-card {
      background: #F8FAFC;
      padding: 12px 14px;
      border-radius: 8px;
      border: 1px solid #E2E8F0;
    }
    .mini-stat-title {
      font-size: 11px;
      color: #64748B;
      text-transform: uppercase;
      font-weight: 600;
    }
    .mini-stat-value {
      font-size: 20px;
      font-weight: 700;
      margin: 4px 0 2px 0;
      color: #0F172A;
    }
    .mini-stat-sub {
      font-size: 11.5px;
      color: #64748B;
    }
    .profile-history-card {
      margin-top: 14px;
      background: #F8FAFC;
      border-radius: 8px;
      padding: 14px;
      border: 1px solid #E2E8F0;
    }
    .history-list {
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .history-item {
      background: #FFFFFF;
      padding: 10px 12px;
      border-radius: 6px;
      border: 1px solid #E2E8F0;
      border-left: 3px solid #0D9488;
    }

    .empty-state {
      padding: 48px 24px;
      text-align: center;
      background: #FFFFFF;
    }
    .empty-icon {
      font-size: 42px;
      margin-bottom: 12px;
    }
    .empty-state h3 {
      color: #0F172A;
      margin-bottom: 6px;
    }
    .empty-state p {
      color: #64748B;
      margin-bottom: 16px;
    }
    .loading-state {
      padding: 40px;
      text-align: center;
      color: #64748B;
    }
    .spinner {
      width: 32px;
      height: 32px;
      border: 3px solid #E2E8F0;
      border-top-color: #0D9488;
      border-radius: 50%;
      margin: 0 auto 12px auto;
      animation: spin 0.8s linear infinite;
    }
    @keyframes spin {
      to { transform: rotate(360deg); }
    }
  `]
})
export class InterviewsAdminComponent implements OnInit {
  sessions: DetailedInterviewSessionItem[] = [];
  questions: any[] = [];
  loading = true;
  searchQuery = '';
  selectedTab = 'ALL';

  // Primary Scope Tab (Requirement 5: My Interviews vs Batch Students)
  activeScope: 'mine' | 'batch' = 'mine';
  // Time filter: all | upcoming | today | past
  timeFilter = 'all';

  // Schedule modal state
  showModal = false;
  newSessionTitle = 'Senior Full Stack Technical Interview';
  newCandidateName = '';
  newCandidateEmail = '';
  selectedQuestionId = 1;

  // Candidate Profile Modal (Requirement 7)
  showProfileModal = false;
  profileLoading = false;
  candidateProfileName = '';
  candidateStats: any = null;

  constructor(private http: HttpClient) {}

  ngOnInit(): void {
    this.loadQuestions();
    this.loadInterviews();
  }

  setScope(scope: 'mine' | 'batch'): void {
    this.activeScope = scope;
    this.loadInterviews();
  }

  setTimeFilter(tf: string): void {
    this.timeFilter = tf;
    this.loadInterviews();
  }

  loadQuestions(): void {
    const apiUrl = environment.apiUrl || '/api';
    this.http.get<any[]>(`${apiUrl}/interviews/questions`).subscribe({
      next: (qList) => {
        this.questions = qList || [];
      },
      error: () => {}
    });
  }

  loadInterviews(): void {
    this.loading = true;
    const apiUrl = environment.apiUrl || '/api';

    this.http.get<DetailedInterviewSessionItem[]>(
      `${apiUrl}/interviews?scope=${this.activeScope}&filter=${this.timeFilter}`
    ).subscribe({
      next: (list) => {
        this.sessions = list || [];
        this.loading = false;
      },
      error: (err) => {
        console.error('Failed to load interviews', err);
        this.sessions = [];
        this.loading = false;
      }
    });
  }

  get activeLiveCount(): number {
    return this.sessions.filter(s => s.status === 'LIVE').length;
  }

  get upcomingCount(): number {
    return this.sessions.filter(s => s.status === 'SCHEDULED' || s.status === 'LIVE').length;
  }

  get hiredCount(): number {
    return this.sessions.filter(s => s.hiringDecision === 'STRONG_HIRE' || s.hiringDecision === 'HIRE').length;
  }

  get filteredSessions(): DetailedInterviewSessionItem[] {
    return this.sessions.filter(s => {
      const matchTab = this.selectedTab === 'ALL' || s.status.toUpperCase() === this.selectedTab;
      if (!matchTab) return false;
      if (!this.searchQuery.trim()) return true;
      const q = this.searchQuery.toLowerCase();
      return (
        (s.candidateName && s.candidateName.toLowerCase().includes(q)) ||
        (s.interviewerName && s.interviewerName.toLowerCase().includes(q)) ||
        (s.roomCode && s.roomCode.toLowerCase().includes(q)) ||
        (s.title && s.title.toLowerCase().includes(q)) ||
        (s.companyName && s.companyName.toLowerCase().includes(q)) ||
        (s.problemTitle && s.problemTitle.toLowerCase().includes(q))
      );
    });
  }

  createInstantMockRoom(): void {
    const instantCode = 'AXIS-MOCK-' + Math.random().toString(36).substring(2, 8).toUpperCase();
    const apiUrl = environment.apiUrl || '/api';

    this.http.post<any>(`${apiUrl}/interviews/rooms`, {
      roomCode: instantCode,
      title: 'Instant 1-on-1 Mock Interview',
      candidateName: 'Candidate',
      interviewerName: 'Interviewer'
    }).subscribe({
      next: (room) => {
        this.loadInterviews();
        this.joinRoom(room.roomCode);
      },
      error: () => {
        this.joinRoom(instantCode);
      }
    });
  }

  joinRoom(roomCode: string): void {
    const targetUrl = `/interview/${roomCode}?role=interviewer`;
    window.open(targetUrl, '_blank');
  }

  copyLink(roomCode: string): void {
    const origin = window.location.origin;
    const link = `${origin}/interview/${roomCode}?role=candidate`;
    navigator.clipboard.writeText(link).then(() => {
      alert(`Candidate interview invitation copied to clipboard!\n${link}`);
    });
  }

  viewCandidateProfile(candidateId: number, name: string): void {
    this.candidateProfileName = name;
    this.showProfileModal = true;
    this.profileLoading = true;
    this.candidateStats = null;

    const apiUrl = environment.apiUrl || '/api';
    this.http.get<any>(`${apiUrl}/student-stats/${candidateId}`).subscribe({
      next: (stats) => {
        this.candidateStats = stats;
        this.profileLoading = false;
      },
      error: (err) => {
        console.error('Failed to fetch candidate stats', err);
        this.profileLoading = false;
      }
    });
  }

  closeProfileModal(): void {
    this.showProfileModal = false;
    this.candidateStats = null;
  }

  get candidateInitials(): string {
    if (!this.candidateProfileName) return '?';
    const parts = this.candidateProfileName.trim().split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return this.candidateProfileName.substring(0, 2).toUpperCase();
  }

  openScheduleModal(): void {
    this.showModal = true;
  }

  closeModal(): void {
    this.showModal = false;
  }

  submitSchedule(): void {
    const newCode = 'AXIS-INT-' + Math.floor(1000 + Math.random() * 9000);
    const apiUrl = environment.apiUrl || '/api';
    const selectedProb = this.questions.find(q => q.id === +this.selectedQuestionId);

    this.http.post<any>(`${apiUrl}/interviews/rooms`, {
      roomCode: newCode,
      title: this.newSessionTitle || '1-on-1 Technical Interview',
      candidateName: this.newCandidateName || 'Scheduled Candidate',
      candidateEmail: this.newCandidateEmail,
      problemTitle: selectedProb ? selectedProb.title : 'Two Sum - Target Pair',
      problemDifficulty: selectedProb ? selectedProb.difficulty : 'Easy'
    }).subscribe({
      next: () => {
        this.closeModal();
        this.loadInterviews();
      },
      error: () => {
        this.closeModal();
        this.loadInterviews();
      }
    });
  }

  formatDate(iso?: string): string {
    if (!iso) return 'Today';
    try {
      const d = new Date(iso);
      return d.toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      });
    } catch {
      return iso;
    }
  }

  formatDecision(decision?: string): string {
    if (!decision) return 'Pending';
    switch (decision.toUpperCase()) {
      case 'STRONG_HIRE': return 'Strong Hire';
      case 'HIRE': return 'Hire';
      case 'LEAN_HIRE': return 'Lean Hire';
      case 'LEAN_REJECT': return 'Lean Reject';
      case 'REJECT': return 'Reject';
      default: return decision;
    }
  }
}
