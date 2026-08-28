import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { ApiService } from '../../services/api.service';
import { ApiErrorService } from '../../services/api-error.service';
import { formatDateTimeDisplay } from '../../utils/date.util';

interface Assignment { id: number; title: string; totalMarks?: number; deliveryMode?: string; }
interface Exam { id: number; title: string; totalMarks?: number; deliveryMode?: string; }
interface SubmissionUser { id: number; fullName?: string; name?: string; email?: string; }
interface AssignmentSubmission {
  id: number;
  user: SubmissionUser;
  assignmentId: number;
  submission?: string;
  submittedAt?: string;
  marksObtained?: number | null;
  feedback?: string | null;
  isGraded: boolean;
}
interface ExamSubmission {
  id: number;
  user: SubmissionUser;
  examId: number;
  answers?: string;
  submittedAt?: string;
  marksObtained?: number | null;
  remarks?: string | null;
  isGraded: boolean;
}

@Component({
  selector: 'app-grading-admin',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
      <h1 style="font-size:24px;font-weight:700;">✅ Grading & Evaluation</h1>
    </div>

    <div style="display:flex;gap:12px;margin-bottom:20px;">
      <button class="btn" [class.btn-primary]="tab==='assignments'" [style.background]="tab==='assignments' ? '' : '#E2E8F0'" (click)="tab='assignments'">📝 Assignment Submissions</button>
      <button class="btn" [class.btn-primary]="tab==='exams'" [style.background]="tab==='exams' ? '' : '#E2E8F0'" (click)="tab='exams'">📋 Exam Submissions</button>
    </div>

    <div class="card" style="margin-bottom:20px;display:flex;gap:16px;align-items:center;">
      <label style="font-weight:600;font-size:14px;">Filter by status:</label>
      <select [(ngModel)]="statusFilter" style="padding:8px;border:1px solid #E2E8F0;border-radius:8px;">
        <option value="all">All</option>
        <option value="pending">Pending Review</option>
        <option value="graded">Graded</option>
      </select>
    </div>

    <div class="card" style="margin-bottom:20px;background:#F0FDFA;border:1px solid #5EEAD4;color:#134E4A;font-size:13px;padding:12px 16px;">
      Submissions marked <strong>Auto</strong> come from an in-app question paper and are already graded.
      Use <strong>Answers</strong> to see exactly which options each student picked.
    </div>

    <div class="card" *ngIf="tab==='assignments'">
      <table>
        <thead><tr><th>Student</th><th>Assignment</th><th>Submitted</th><th>Content</th><th>Marks</th><th>Feedback</th><th>Status</th><th>Actions</th></tr></thead>
        <tbody>
          <tr *ngFor="let s of filteredAssignmentSubmissions">
            <td style="font-weight:600;">{{ s.user?.fullName || s.user?.name || s.user?.email || 'Unknown' }}</td>
            <td>{{ getAssignmentTitle(s.assignmentId) }}</td>
            <td>{{ formatDate(s.submittedAt) }}</td>
            <td style="max-width:220px;"><span style="display:block;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;" [title]="s.submission">{{ s.submission || '—' }}</span></td>
            <td style="width:110px;">
              <input type="number" [(ngModel)]="s._marks" min="0" [max]="getAssignmentMax(s.assignmentId)" style="width:70px;padding:6px;border:1px solid #E2E8F0;border-radius:6px;">
              <span style="color:#94A3B8;font-size:12px;">/ {{ getAssignmentMax(s.assignmentId) }}</span>
            </td>
            <td style="width:180px;"><textarea [(ngModel)]="s._feedback" rows="1" placeholder="Feedback" style="width:100%;padding:6px;border:1px solid #E2E8F0;border-radius:6px;font-size:12px;"></textarea></td>
            <td>
              <span class="badge" [class.badge-success]="s.isGraded" [class.badge-warning]="!s.isGraded">{{ s.isGraded ? 'Graded' : 'Pending' }}</span>
              <span *ngIf="isInAppAssignment(s.assignmentId)" class="badge" style="background:#CCFBF1;color:#134E4A;margin-left:6px;">Auto</span>
            </td>
            <td style="white-space:nowrap;">
              <button *ngIf="isInAppAssignment(s.assignmentId)" class="btn btn-secondary" style="padding:6px 12px;font-size:12px;margin-right:6px;" (click)="viewAnswers('assignments', s.assignmentId)">👁 Answers</button>
              <button class="btn btn-primary" style="padding:6px 14px;font-size:12px;" (click)="gradeAssignment(s)">Save & Grade</button>
            </td>
          </tr>
          <tr *ngIf="filteredAssignmentSubmissions.length === 0">
            <td colspan="8" style="text-align:center;padding:32px;color:#64748B;">No assignment submissions found.</td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="card" *ngIf="tab==='exams'">
      <table>
        <thead><tr><th>Student</th><th>Exam</th><th>Submitted</th><th>Answers</th><th>Marks</th><th>Remarks</th><th>Status</th><th>Actions</th></tr></thead>
        <tbody>
          <tr *ngFor="let s of filteredExamSubmissions">
            <td style="font-weight:600;">{{ s.user?.fullName || s.user?.name || s.user?.email || 'Unknown' }}</td>
            <td>{{ getExamTitle(s.examId) }}</td>
            <td>{{ formatDate(s.submittedAt) }}</td>
            <td style="max-width:220px;"><span style="display:block;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;" [title]="s.answers">{{ s.answers || '—' }}</span></td>
            <td style="width:110px;">
              <input type="number" [(ngModel)]="s._marks" min="0" [max]="getExamMax(s.examId)" style="width:70px;padding:6px;border:1px solid #E2E8F0;border-radius:6px;">
              <span style="color:#94A3B8;font-size:12px;">/ {{ getExamMax(s.examId) }}</span>
            </td>
            <td style="width:180px;"><textarea [(ngModel)]="s._remarks" rows="1" placeholder="Remarks" style="width:100%;padding:6px;border:1px solid #E2E8F0;border-radius:6px;font-size:12px;"></textarea></td>
            <td>
              <span class="badge" [class.badge-success]="s.isGraded" [class.badge-warning]="!s.isGraded">{{ s.isGraded ? 'Graded' : 'Pending' }}</span>
              <span *ngIf="isInAppExam(s.examId)" class="badge" style="background:#CCFBF1;color:#134E4A;margin-left:6px;">Auto</span>
            </td>
            <td style="white-space:nowrap;">
              <button *ngIf="isInAppExam(s.examId)" class="btn btn-secondary" style="padding:6px 12px;font-size:12px;margin-right:6px;" (click)="viewAnswers('exams', s.examId)">👁 Answers</button>
              <button class="btn btn-primary" style="padding:6px 14px;font-size:12px;" (click)="gradeExam(s)">Save & Grade</button>
            </td>
          </tr>
          <tr *ngIf="filteredExamSubmissions.length === 0">
            <td colspan="8" style="text-align:center;padding:32px;color:#64748B;">No exam submissions found.</td>
          </tr>
        </tbody>
      </table>
    </div>
  `
})
export class GradingAdminComponent implements OnInit {
  private api = inject(ApiService);
  private router = inject(Router);
  private errors = inject(ApiErrorService);

  tab: 'assignments' | 'exams' = 'assignments';
  statusFilter: 'all' | 'pending' | 'graded' = 'all';

  assignments: Assignment[] = [];
  exams: Exam[] = [];
  assignmentSubmissions: (AssignmentSubmission & { _marks?: number | null; _feedback?: string | null })[] = [];
  examSubmissions: (ExamSubmission & { _marks?: number | null; _remarks?: string | null })[] = [];

  ngOnInit() {
    this.loadAssignments();
    this.loadExams();
    this.loadAssignmentSubmissions();
    this.loadExamSubmissions();
  }

  get filteredAssignmentSubmissions() {
    if (this.statusFilter === 'pending') return this.assignmentSubmissions.filter(s => !s.isGraded);
    if (this.statusFilter === 'graded') return this.assignmentSubmissions.filter(s => s.isGraded);
    return this.assignmentSubmissions;
  }

  get filteredExamSubmissions() {
    if (this.statusFilter === 'pending') return this.examSubmissions.filter(s => !s.isGraded);
    if (this.statusFilter === 'graded') return this.examSubmissions.filter(s => s.isGraded);
    return this.examSubmissions;
  }

  loadAssignments() {
    this.api.get<Assignment[]>('/api/assignments').subscribe({
      next: (data) => { this.assignments = data; },
      error: err => this.errors.show(err, 'Could not load assignments')
    });
  }

  loadExams() {
    this.api.get<Exam[]>('/api/exams').subscribe({
      next: (data) => { this.exams = data; },
      error: err => this.errors.show(err, 'Could not load exams')
    });
  }

  loadAssignmentSubmissions() {
    this.api.get<AssignmentSubmission[]>('/api/assignment-submissions').subscribe({
      next: (data) => {
        this.assignmentSubmissions = data.map(s => ({ ...s, _marks: s.marksObtained ?? null, _feedback: s.feedback ?? '' }));
      },
      error: err => this.errors.show(err, 'Could not load assignment submissions')
    });
  }

  loadExamSubmissions() {
    this.api.get<ExamSubmission[]>('/api/exam-submissions').subscribe({
      next: (data) => {
        this.examSubmissions = data.map(s => ({ ...s, _marks: s.marksObtained ?? null, _remarks: s.remarks ?? '' }));
      },
      error: err => this.errors.show(err, 'Could not load exam submissions')
    });
  }

  getAssignmentTitle(id: number): string {
    const a = this.assignments.find(x => x.id === id);
    return a ? a.title : `#${id}`;
  }

  getAssignmentMax(id: number): number {
    const a = this.assignments.find(x => x.id === id);
    return a?.totalMarks ?? 100;
  }

  getExamTitle(id: number): string {
    const e = this.exams.find(x => x.id === id);
    return e ? e.title : `#${id}`;
  }

  getExamMax(id: number): number {
    const e = this.exams.find(x => x.id === id);
    return e?.totalMarks ?? 100;
  }

  /** In-app papers are auto-graded, so the mentor reviews answers rather than marking. */
  isInAppAssignment(id: number): boolean {
    return this.assignments.find(x => x.id === id)?.deliveryMode === 'IN_APP';
  }

  isInAppExam(id: number): boolean {
    return this.exams.find(x => x.id === id)?.deliveryMode === 'IN_APP';
  }

  /** Opens the paper builder straight on its Student Responses tab. */
  viewAnswers(type: 'assignments' | 'exams', id: number) {
    this.router.navigate(['/assessment-paper', type, id], { queryParams: { tab: 'responses' } });
  }

  formatDate(value?: string): string {
    return formatDateTimeDisplay(value);
  }

  gradeAssignment(s: AssignmentSubmission & { _marks?: number | null; _feedback?: string | null }) {
    const marks = s._marks === undefined || s._marks === null || `${s._marks}` === '' ? null : Number(s._marks);
    const payload = {
      marksObtained: marks,
      feedback: s._feedback || null,
      isGraded: marks !== null
    };
    this.api.put<AssignmentSubmission>(`/api/assignment-submissions/${s.id}`, payload).subscribe({
      next: (updated) => {
        const i = this.assignmentSubmissions.findIndex(x => x.id === s.id);
        if (i > -1) this.assignmentSubmissions[i] = { ...this.assignmentSubmissions[i], ...updated, _marks: updated.marksObtained, _feedback: updated.feedback };
        this.errors.success('Assignment graded successfully.');
      },
      error: (err) => { console.error('Failed to grade assignment:', err); this.errors.show(err, 'Could not save grade'); }
    });
  }

  gradeExam(s: ExamSubmission & { _marks?: number | null; _remarks?: string | null }) {
    const marks = s._marks === undefined || s._marks === null || `${s._marks}` === '' ? null : Number(s._marks);
    const payload = {
      marksObtained: marks,
      remarks: s._remarks || null,
      isGraded: marks !== null
    };
    this.api.put<ExamSubmission>(`/api/exam-submissions/${s.id}`, payload).subscribe({
      next: (updated) => {
        const i = this.examSubmissions.findIndex(x => x.id === s.id);
        if (i > -1) this.examSubmissions[i] = { ...this.examSubmissions[i], ...updated, _marks: updated.marksObtained, _remarks: updated.remarks };
        this.errors.success('Exam graded successfully.');
      },
      error: (err) => { console.error('Failed to grade exam:', err); this.errors.show(err, 'Could not save grade'); }
    });
  }
}
