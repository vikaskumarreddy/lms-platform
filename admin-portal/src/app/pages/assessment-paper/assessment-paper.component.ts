import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { ApiService } from '../../services/api.service';
import { ApiErrorService } from '../../services/api-error.service';

interface PaperOption {
  id?: number;
  optionText: string;
  isCorrect: boolean;
}

type QuestionType = 'SINGLE_CHOICE' | 'MULTIPLE_ANSWER' | 'FILL_IN_BLANK' | 'CODING';

interface PaperQuestion {
  id: number;
  questionText: string;
  questionType: QuestionType;
  explanation?: string;
  marks: number;
  displayOrder: number;
  answerText?: string;
  options: Array<{ id: number; optionText: string; isCorrect: boolean }>;
}

/**
 * Question-paper builder for an in-app assignment or exam.
 *
 * Reached from the "Create Paper" action on an IN_APP row in the assignments/exams
 * tables. Two surfaces: the paper itself (questions + answer key) and the automatically
 * graded student responses, so a mentor can see exactly which option each student ticked.
 */
@Component({
  selector: 'app-assessment-paper',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:24px;gap:16px;flex-wrap:wrap;">
      <div>
        <button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;margin-bottom:10px;" (click)="goBack()">← Back to {{typeLabel}}s</button>
        <h1 style="font-size:24px;font-weight:700;">📄 {{assessmentTitle || typeLabel + ' Paper'}}</h1>
        <div style="color:#64748B;font-size:13px;margin-top:4px;">
          <span class="badge" style="background:#EEF2FF;color:#4338CA;">{{typeLabel}}</span>
          <span style="margin-left:10px;">{{questions.length}} question{{questions.length === 1 ? '' : 's'}}</span>
          <span style="margin-left:10px;">{{totalMarks}} mark{{totalMarks === 1 ? '' : 's'}} total</span>
        </div>
      </div>
      <button class="btn btn-primary" *ngIf="tab === 'paper'" (click)="openAddQuestion()">+ Add Question</button>
    </div>

    <!-- Page-level tabs: build the paper / read the results -->
    <div class="popup-tabs" style="margin-bottom:20px;">
      <button type="button" [class.active]="tab === 'paper'" (click)="tab = 'paper'">📝 Questions</button>
      <button type="button" [class.active]="tab === 'responses'" (click)="switchToResponses()">📊 Student Responses</button>
    </div>

    <div *ngIf="pageError" style="margin-bottom:16px;padding:12px;background:#FEE2E2;color:#991B1B;border-radius:8px;font-size:14px;">
      {{pageError}}
    </div>

    <!-- ===================== Questions ===================== -->
    <ng-container *ngIf="tab === 'paper'">
      <div class="card" *ngIf="loading" style="text-align:center;padding:32px;color:#64748B;">Loading paper…</div>

      <div class="card" *ngIf="!loading && questions.length === 0" style="text-align:center;padding:48px;color:#64748B;">
        <div style="font-size:40px;margin-bottom:8px;">📄</div>
        <div style="font-weight:600;color:#134E4A;margin-bottom:4px;">No questions yet</div>
        <div style="font-size:13px;margin-bottom:16px;">Add questions here and students will answer them inside the mobile app.</div>
        <button class="btn btn-primary" (click)="openAddQuestion()">+ Add Question</button>
      </div>

      <div class="card" *ngFor="let q of questions; let i = index" style="margin-bottom:16px;">
        <div style="display:flex;justify-content:space-between;align-items:flex-start;gap:12px;">
          <div style="flex:1;">
            <div style="display:flex;align-items:center;gap:8px;margin-bottom:8px;flex-wrap:wrap;">
              <span style="background:#0D9488;color:#fff;width:26px;height:26px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;font-size:13px;font-weight:700;">{{i + 1}}</span>
              <span class="badge" [style.background]="typeBadgeColor(q.questionType).bg" [style.color]="typeBadgeColor(q.questionType).fg">
                {{typeLabelFor(q.questionType)}}
              </span>
              <span class="badge" style="background:#F1F5F9;color:#475569;">{{q.marks}} mark{{q.marks === 1 ? '' : 's'}}</span>
            </div>
            <div style="font-weight:600;color:#134E4A;white-space:pre-wrap;">{{q.questionText}}</div>
          </div>
          <div style="display:flex;gap:6px;flex-shrink:0;">
            <button class="btn btn-secondary" style="padding:4px 10px;font-size:12px;" [disabled]="i === 0" (click)="move(i, -1)" title="Move up">↑</button>
            <button class="btn btn-secondary" style="padding:4px 10px;font-size:12px;" [disabled]="i === questions.length - 1" (click)="move(i, 1)" title="Move down">↓</button>
            <button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;" (click)="openEditQuestion(q)">Edit</button>
            <button class="btn" style="background:#FEE2E2;color:#991B1B;padding:4px 12px;font-size:12px;" (click)="deleteQuestion(q)">Delete</button>
          </div>
        </div>

        <div style="margin-top:12px;display:grid;gap:8px;" *ngIf="q.questionType === 'SINGLE_CHOICE' || q.questionType === 'MULTIPLE_ANSWER'">
          <div *ngFor="let o of q.options; let oi = index"
               [style.background]="o.isCorrect ? '#ECFDF5' : '#F8FAFC'"
               [style.border]="o.isCorrect ? '1px solid #6EE7B7' : '1px solid #E2E8F0'"
               style="padding:9px 12px;border-radius:10px;display:flex;align-items:center;gap:10px;font-size:14px;">
            <span style="font-weight:700;color:#64748B;min-width:18px;">{{letters[oi]}}.</span>
            <span style="flex:1;color:#134E4A;">{{o.optionText}}</span>
            <span *ngIf="o.isCorrect" style="color:#047857;font-weight:700;font-size:12px;">✓ Correct</span>
          </div>
        </div>

        <div *ngIf="q.questionType === 'FILL_IN_BLANK'" style="margin-top:12px;padding:10px 12px;background:#ECFDF5;border-radius:8px;font-size:13px;color:#047857;">
          <strong>Correct answer:</strong> {{q.answerText}}
        </div>

        <div *ngIf="q.questionType === 'CODING'" style="margin-top:12px;padding:10px 12px;background:#F8FAFC;border:1px dashed #CBD5E1;border-radius:8px;font-size:13px;color:#475569;">
          Not auto-graded — a mentor reviews the student's typed answer manually.
          <div *ngIf="q.answerText" style="margin-top:6px;"><strong>Notes:</strong> {{q.answerText}}</div>
        </div>

        <div *ngIf="q.explanation" style="margin-top:12px;padding:10px 12px;background:#F0F9FF;border-left:3px solid #0EA5E9;border-radius:6px;font-size:13px;color:#0C4A6E;">
          <strong>Explanation:</strong> {{q.explanation}}
        </div>
      </div>
    </ng-container>

    <!-- ===================== Student responses ===================== -->
    <ng-container *ngIf="tab === 'responses'">
      <div class="card" *ngIf="loadingResponses" style="text-align:center;padding:32px;color:#64748B;">Loading responses…</div>

      <ng-container *ngIf="!loadingResponses && results">
        <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:16px;margin-bottom:20px;">
          <div class="card"><div style="color:#64748B;font-size:13px;">Students attempted</div><div style="font-size:26px;font-weight:700;color:#134E4A;">{{results.studentCount}}</div></div>
          <div class="card"><div style="color:#64748B;font-size:13px;">Average score</div><div style="font-size:26px;font-weight:700;color:#134E4A;">{{results.averageScore}} / {{results.totalMarks}}</div></div>
          <div class="card"><div style="color:#64748B;font-size:13px;">Questions</div><div style="font-size:26px;font-weight:700;color:#134E4A;">{{results.questionCount}}</div></div>
        </div>

        <div class="card" *ngIf="results.studentCount === 0" style="text-align:center;padding:48px;color:#64748B;">
          No student has attempted this paper yet. Scores appear here automatically as soon as they submit.
        </div>

        <!-- Per-question accuracy: shows the topic the class struggled with -->
        <div class="card" *ngIf="results.studentCount > 0" style="margin-bottom:20px;">
          <h3 style="font-size:16px;font-weight:700;margin-bottom:12px;">Question-wise accuracy</h3>
          <table>
            <thead><tr><th>#</th><th>Question</th><th>Attempts</th><th>Correct</th><th>Accuracy</th></tr></thead>
            <tbody>
              <tr *ngFor="let s of results.questionAnalytics; let i = index">
                <td>{{i + 1}}</td>
                <td>{{s.questionText}}</td>
                <td>{{s.attempts}}</td>
                <td>{{s.correctCount}}</td>
                <td>
                  <span class="badge"
                        [class.badge-success]="s.accuracy >= 70"
                        [class.badge-warning]="s.accuracy >= 40 && s.accuracy < 70"
                        [class.badge-danger]="s.accuracy < 40">{{s.accuracy}}%</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- One row per student; expand to see exactly what they ticked -->
        <div class="card" *ngFor="let st of results.students" style="margin-bottom:12px;">
          <div style="display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap;cursor:pointer;" (click)="toggleStudent(st.userId)">
            <div>
              <div style="font-weight:600;color:#134E4A;">{{st.studentName}}</div>
              <div style="color:#64748B;font-size:12px;">{{st.studentEmail}}</div>
            </div>
            <div style="display:flex;align-items:center;gap:12px;">
              <span class="badge" style="background:#F1F5F9;color:#475569;">{{st.correctCount}}/{{st.questionCount}} correct</span>
              <span class="badge"
                    [class.badge-success]="st.percentage >= 40"
                    [class.badge-danger]="st.percentage < 40">{{st.score}}/{{st.totalMarks}} · {{st.percentage}}%</span>
              <span style="color:#64748B;font-size:18px;">{{expanded[st.userId] ? '▴' : '▾'}}</span>
            </div>
          </div>

          <div *ngIf="expanded[st.userId]" style="margin-top:16px;border-top:1px solid #E2E8F0;padding-top:16px;display:grid;gap:14px;">
            <div *ngFor="let a of st.answers; let ai = index" style="padding:12px;border-radius:10px;"
                 [style.background]="a.questionType === 'CODING' ? '#F8FAFC' : (a.isCorrect ? '#ECFDF5' : (a.attempted ? '#FEF2F2' : '#F8FAFC'))">
              <div style="font-weight:600;color:#134E4A;margin-bottom:6px;">
                {{ai + 1}}. {{a.questionText}}
                <span class="badge" style="margin-left:8px;" *ngIf="a.questionType === 'CODING'">Not auto-graded</span>
                <span class="badge" style="margin-left:8px;" *ngIf="a.questionType !== 'CODING'" [class.badge-success]="a.isCorrect" [class.badge-danger]="!a.isCorrect">
                  {{a.isCorrect ? '✓ Correct' : (a.attempted ? '✕ Wrong' : 'Not answered')}}
                </span>
              </div>
              <div style="font-size:13px;color:#475569;" *ngIf="a.questionType === 'SINGLE_CHOICE' || a.questionType === 'MULTIPLE_ANSWER'">
                <div><strong>Chose:</strong>
                  <span *ngIf="a.selectedOptions?.length">{{a.selectedOptions.join(', ')}}</span>
                  <span *ngIf="!a.selectedOptions?.length" style="color:#94A3B8;">— nothing selected —</span>
                </div>
                <div *ngIf="!a.isCorrect"><strong>Correct answer:</strong> {{a.correctOptions.join(', ')}}</div>
              </div>
              <div style="font-size:13px;color:#475569;" *ngIf="a.questionType === 'FILL_IN_BLANK' || a.questionType === 'CODING'">
                <div><strong>Answer:</strong>
                  <span *ngIf="a.answerText">{{a.answerText}}</span>
                  <span *ngIf="!a.answerText" style="color:#94A3B8;">— not answered —</span>
                </div>
                <div *ngIf="a.questionType === 'FILL_IN_BLANK' && !a.isCorrect"><strong>Correct answer:</strong> {{a.correctAnswerText}}</div>
              </div>
              <div *ngIf="a.explanation" style="margin-top:4px;color:#0C4A6E;font-size:13px;"><strong>Why:</strong> {{a.explanation}}</div>
            </div>
          </div>
        </div>
      </ng-container>
    </ng-container>

    <!-- ===================== Add / Edit question popup ===================== -->
    <div class="modal-overlay" *ngIf="showQuestionModal" (click)="closeQuestionModal($event)">
      <div class="modal-content" style="width:90%;max-width:720px;" (click)="$event.stopPropagation()">
        <form (ngSubmit)="saveQuestion()">
          <fieldset>
            <legend>{{editingQuestionId ? 'Edit Question' : 'Add New Question'}}</legend>
            <div class="popup-form-grid">
              <div class="full-width">
                <label>Question *</label>
                <textarea [(ngModel)]="qForm.questionText" name="questionText" rows="3" required placeholder="Type the question exactly as the student should read it"></textarea>
              </div>

              <div class="full-width" *ngIf="qForm.questionType === 'SINGLE_CHOICE' || qForm.questionType === 'MULTIPLE_ANSWER'">
                <label>Options * (tick the correct answer)</label>
                <div style="display:grid;gap:8px;">
                  <div *ngFor="let opt of qForm.options; let i = index" style="display:flex;align-items:center;gap:10px;">
                    <span style="font-weight:700;color:#64748B;min-width:18px;">{{letters[i]}}.</span>
                    <input type="text" [(ngModel)]="opt.optionText" [name]="'optionText' + i" placeholder="Option text" style="flex:1;margin:0;">
                    <label style="display:flex;align-items:center;gap:6px;margin:0;white-space:nowrap;font-size:13px;cursor:pointer;">
                      <input type="checkbox" [ngModel]="opt.isCorrect" (ngModelChange)="setCorrect(i, $event)" [name]="'optionCorrect' + i" style="width:auto;margin:0;">
                      Correct
                    </label>
                    <button type="button" class="btn" style="background:#FEE2E2;color:#991B1B;padding:4px 10px;font-size:12px;"
                            [disabled]="qForm.options.length <= 2" (click)="removeOption(i)">✕</button>
                  </div>
                </div>
                <button type="button" class="btn btn-secondary" style="margin-top:10px;padding:6px 14px;font-size:13px;" (click)="addOption()">+ Add Option</button>
              </div>

              <div class="full-width" *ngIf="qForm.questionType === 'FILL_IN_BLANK'">
                <label>Correct answer *</label>
                <input type="text" [(ngModel)]="qForm.answerText" name="answerText" placeholder="Exact text the student must type">
              </div>

              <div class="full-width" *ngIf="qForm.questionType === 'CODING'">
                <label>Notes (optional, not shown to students until reviewed)</label>
                <textarea [(ngModel)]="qForm.answerText" name="answerText" rows="3" placeholder="Reference solution / grading notes for the mentor — not auto-graded"></textarea>
              </div>

              <div class="full-width">
                <label>Answer type</label>
                <div style="display:flex;gap:20px;padding-top:4px;flex-wrap:wrap;">
                  <label style="display:flex;align-items:center;gap:7px;margin:0;cursor:pointer;font-weight:500;">
                    <input type="radio" name="questionType" value="SINGLE_CHOICE" [(ngModel)]="qForm.questionType"
                           (ngModelChange)="onTypeChange()" style="width:auto;margin:0;">
                    Multiple choice — one answer (radio buttons in the app)
                  </label>
                  <label style="display:flex;align-items:center;gap:7px;margin:0;cursor:pointer;font-weight:500;">
                    <input type="radio" name="questionType" value="MULTIPLE_ANSWER" [(ngModel)]="qForm.questionType" style="width:auto;margin:0;">
                    Multiple answers (checkboxes in the app)
                  </label>
                  <label style="display:flex;align-items:center;gap:7px;margin:0;cursor:pointer;font-weight:500;">
                    <input type="radio" name="questionType" value="FILL_IN_BLANK" [(ngModel)]="qForm.questionType" style="width:auto;margin:0;">
                    Fill in the blank (text answer)
                  </label>
                  <label style="display:flex;align-items:center;gap:7px;margin:0;cursor:pointer;font-weight:500;">
                    <input type="radio" name="questionType" value="CODING" [(ngModel)]="qForm.questionType" style="width:auto;margin:0;">
                    Coding (not auto-graded)
                  </label>
                </div>
              </div>

              <div>
                <label>Marks</label>
                <input type="number" min="1" [(ngModel)]="qForm.marks" name="marks" placeholder="1">
              </div>

              <div class="full-width">
                <label>Explanation</label>
                <textarea [(ngModel)]="qForm.explanation" name="explanation" rows="2" placeholder="Shown to the student after they submit"></textarea>
              </div>
            </div>
          </fieldset>

          <div class="popup-nav">
            <button type="submit" class="btn btn-accent" [disabled]="savingQuestion">
              {{savingQuestion ? 'Saving...' : (editingQuestionId ? 'Update Question' : 'Add Question')}}
            </button>
            <span style="flex:1"></span>
            <button type="button" class="btn btn-danger" (click)="closeQuestionModal()">Cancel</button>
          </div>
        </form>

        <div *ngIf="modalError" style="margin-top:16px;padding:12px;background:#FEE2E2;color:#991B1B;border-radius:8px;font-size:14px;">
          {{modalError}}
        </div>
      </div>
    </div>
  `
})
export class AssessmentPaperComponent implements OnInit {
  private api = inject(ApiService);
  private errors = inject(ApiErrorService);
  private route = inject(ActivatedRoute);
  private router = inject(Router);

  /** "assignments" or "exams" — matches the API path segment. */
  type = 'assignments';
  assessmentId!: number;
  assessmentTitle = '';

  tab: 'paper' | 'responses' = 'paper';
  letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

  loading = true;
  loadingResponses = false;
  pageError = '';
  questions: PaperQuestion[] = [];
  totalMarks = 0;

  results: any = null;
  expanded: Record<number, boolean> = {};

  showQuestionModal = false;
  editingQuestionId: number | null = null;
  savingQuestion = false;
  modalError = '';
  qForm: { questionText: string; questionType: QuestionType; marks: number; explanation: string; answerText: string; options: PaperOption[] } = this.blankForm();

  get typeLabel(): string {
    if (this.type === 'exams') return 'Exam';
    if (this.type === 'company-kit') return 'Company Kit';
    return 'Assignment';
  }

  typeBadgeColor(type: QuestionType): { bg: string; fg: string } {
    switch (type) {
      case 'MULTIPLE_ANSWER': return { bg: '#FFFBEB', fg: '#B45309' };
      case 'FILL_IN_BLANK': return { bg: '#ECFDF5', fg: '#047857' };
      case 'CODING': return { bg: '#EEF2FF', fg: '#4338CA' };
      default: return { bg: '#F0FDFA', fg: '#0D9488' };
    }
  }

  typeLabelFor(type: QuestionType): string {
    switch (type) {
      case 'MULTIPLE_ANSWER': return 'Multiple answers';
      case 'FILL_IN_BLANK': return 'Fill in the blank';
      case 'CODING': return 'Coding';
      default: return 'Single choice';
    }
  }

  ngOnInit() {
    this.type = this.route.snapshot.paramMap.get('type') || 'assignments';
    this.assessmentId = Number(this.route.snapshot.paramMap.get('id'));
    this.loadAssessment();
    this.loadQuestions();
    // Deep link from Grading, which sends mentors straight to the student answers.
    if (this.route.snapshot.queryParamMap.get('tab') === 'responses') this.switchToResponses();
  }

  private blankForm() {
    return {
      questionText: '',
      questionType: 'SINGLE_CHOICE' as QuestionType,
      marks: 1,
      explanation: '',
      answerText: '',
      options: [
        { optionText: '', isCorrect: false },
        { optionText: '', isCorrect: false }
      ] as PaperOption[]
    };
  }

  goBack() {
    if (this.type === 'exams') { this.router.navigate(['/exams-admin']); return; }
    if (this.type === 'company-kit') { this.router.navigate(['/company-questions']); return; }
    this.router.navigate(['/assignments-admin']);
  }

  loadAssessment() {
    if (this.type === 'company-kit') {
      this.api.get<any>(`/api/company-kits/${this.assessmentId}`).subscribe({
        next: (data) => { this.assessmentTitle = data?.companyName || ''; },
        error: err => this.errors.show(err, 'Could not load that company kit')
      });
      return;
    }
    this.api.get<any>(`/api/${this.type}/${this.assessmentId}`).subscribe({
      next: (data) => { this.assessmentTitle = data?.title || ''; },
      error: err => this.errors.show(err, 'Could not load that assessment')
    });
  }

  loadQuestions() {
    this.loading = true;
    this.api.get<any>(`/api/assessments/${this.type}/${this.assessmentId}/questions`).subscribe({
      next: (data) => {
        this.questions = data?.questions || [];
        this.totalMarks = data?.totalMarks || 0;
        this.loading = false;
      },
      error: () => {
        this.loading = false;
        this.pageError = 'Failed to load the question paper.';
      }
    });
  }

  switchToResponses() {
    this.tab = 'responses';
    this.loadResponses();
  }

  loadResponses() {
    this.loadingResponses = true;
    this.api.get<any>(`/api/assessments/${this.type}/${this.assessmentId}/responses`).subscribe({
      next: (data) => { this.results = data; this.loadingResponses = false; },
      error: () => { this.loadingResponses = false; this.pageError = 'Failed to load student responses.'; }
    });
  }

  toggleStudent(userId: number) {
    this.expanded[userId] = !this.expanded[userId];
  }

  // ------------------------------------------------------------ question editing

  openAddQuestion() {
    this.editingQuestionId = null;
    this.qForm = this.blankForm();
    this.modalError = '';
    this.showQuestionModal = true;
  }

  openEditQuestion(q: PaperQuestion) {
    this.editingQuestionId = q.id;
    this.qForm = {
      questionText: q.questionText,
      questionType: q.questionType,
      marks: q.marks || 1,
      explanation: q.explanation || '',
      answerText: q.answerText || '',
      options: q.options.map(o => ({ id: o.id, optionText: o.optionText, isCorrect: o.isCorrect }))
    };
    if (this.qForm.options.length < 2) this.addOption();
    this.modalError = '';
    this.showQuestionModal = true;
  }

  closeQuestionModal(event?: Event) {
    if (event && event.target !== event.currentTarget) return;
    this.showQuestionModal = false;
    this.editingQuestionId = null;
    this.savingQuestion = false;
    this.modalError = '';
  }

  addOption() {
    this.qForm.options.push({ optionText: '', isCorrect: false });
  }

  removeOption(i: number) {
    if (this.qForm.options.length <= 2) return;
    this.qForm.options.splice(i, 1);
  }

  /** Single-choice behaves like a radio group: ticking one option clears the others. */
  setCorrect(i: number, value: boolean) {
    if (value && this.qForm.questionType === 'SINGLE_CHOICE') {
      this.qForm.options.forEach((o, idx) => o.isCorrect = idx === i);
    } else {
      this.qForm.options[i].isCorrect = value;
    }
  }

  /** Switching to single-choice keeps only the first ticked option. */
  onTypeChange() {
    if (this.qForm.questionType !== 'SINGLE_CHOICE') return;
    let seen = false;
    this.qForm.options.forEach(o => {
      if (o.isCorrect && !seen) { seen = true; return; }
      o.isCorrect = false;
    });
  }

  saveQuestion() {
    this.modalError = '';
    if (!this.qForm.questionText || !this.qForm.questionText.trim()) { this.modalError = 'Question text is required'; return; }

    const isTextType = this.qForm.questionType === 'FILL_IN_BLANK' || this.qForm.questionType === 'CODING';
    let options: PaperOption[] = [];

    if (isTextType) {
      if (this.qForm.questionType === 'FILL_IN_BLANK' && !(this.qForm.answerText || '').trim()) {
        this.modalError = 'A correct answer is required for fill in the blank questions';
        return;
      }
    } else {
      options = this.qForm.options.filter(o => (o.optionText || '').trim().length > 0);
      if (options.length < 2) { this.modalError = 'Add at least two options'; return; }
      if (!options.some(o => o.isCorrect)) { this.modalError = 'Tick at least one correct answer'; return; }
      if (this.qForm.questionType === 'SINGLE_CHOICE' && options.filter(o => o.isCorrect).length > 1) {
        this.modalError = 'A single-choice question can only have one correct answer';
        return;
      }
    }

    const payload = {
      questionText: this.qForm.questionText.trim(),
      questionType: this.qForm.questionType,
      explanation: this.qForm.explanation || null,
      marks: Number(this.qForm.marks) || 1,
      answerText: isTextType ? (this.qForm.answerText || '').trim() || null : null,
      options: options.map(o => ({ optionText: o.optionText.trim(), isCorrect: !!o.isCorrect }))
    };

    this.savingQuestion = true;
    const base = `/api/assessments/${this.type}/${this.assessmentId}/questions`;
    const request$ = this.editingQuestionId
      ? this.api.put<any>(`${base}/${this.editingQuestionId}`, payload)
      : this.api.post<any>(base, payload);

    request$.subscribe({
      next: () => {
        this.savingQuestion = false;
        this.showQuestionModal = false;
        this.editingQuestionId = null;
        this.loadQuestions();
      },
      error: (err) => {
        this.savingQuestion = false;
        this.modalError = err?.error?.message || 'Failed to save the question';
      }
    });
  }

  deleteQuestion(q: PaperQuestion) {
    if (!confirm('Delete this question? Any answers students already gave for it are removed too.')) return;
    this.api.delete(`/api/assessments/${this.type}/${this.assessmentId}/questions/${q.id}`).subscribe({
      next: () => this.loadQuestions(),
      error: () => { this.pageError = 'Failed to delete the question.'; }
    });
  }

  move(index: number, delta: number) {
    const target = index + delta;
    if (target < 0 || target >= this.questions.length) return;
    const reordered = [...this.questions];
    const [moved] = reordered.splice(index, 1);
    reordered.splice(target, 0, moved);
    this.questions = reordered;
    this.api.put(`/api/assessments/${this.type}/${this.assessmentId}/questions-order`,
      { questionIds: reordered.map(q => q.id) }).subscribe({
      next: () => {},
      error: () => { this.pageError = 'Failed to save the new order.'; this.loadQuestions(); }
    });
  }
}
