import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { ApiService } from '../../services/api.service';
import { ApiErrorService } from '../../services/api-error.service';
import { ConfirmService } from '../../services/confirm.service';

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

@Component({
  selector: 'app-assessment-paper',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="assessment-builder-container">
      <!-- Left Sidebar / Info Card -->
      <aside class="assessment-info-card">
        <button type="button" class="btn-back" (click)="goBack()">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <line x1="19" y1="12" x2="5" y2="12"></line>
            <polyline points="12 19 5 12 12 5"></polyline>
          </svg>
          Back to {{ typeLabel }}s
        </button>

        <div class="doc-icon-badge">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#7C3AED" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
            <polyline points="14 2 14 8 20 8"></polyline>
            <line x1="16" y1="13" x2="8" y2="13"></line>
            <line x1="16" y1="17" x2="8" y2="17"></line>
            <polyline points="10 9 9 9 8 9"></polyline>
          </svg>
        </div>

        <h1 class="paper-title">{{ assessmentTitle || (typeLabel + ' Paper') }}</h1>

        <div class="paper-meta-row">
          <span class="type-pill">{{ typeLabel }}</span>
          <span class="meta-divider">|</span>
          <span class="meta-text">{{ questions.length }} question{{ questions.length === 1 ? '' : 's' }}</span>
          <span class="meta-divider">|</span>
          <span class="meta-text">{{ totalMarks }} mark{{ totalMarks === 1 ? '' : 's' }} total</span>
        </div>

        <div class="left-actions-group" *ngIf="tab === 'paper'">
          <button type="button" class="btn-ai-generate" (click)="openAiModal()">
            <svg width="17" height="17" viewBox="0 0 24 24" fill="currentColor">
              <path d="M12 2L14.39 8.26L21 9.27L16 13.14L17.45 19.73L12 16.3L6.55 19.73L8 13.14L3 9.27L9.61 8.26L12 2Z"/>
            </svg>
            Auto-Generate with AI
          </button>

          <button type="button" class="btn-add-question" (click)="openAddQuestion()">
            <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <line x1="12" y1="5" x2="12" y2="19"></line>
              <line x1="5" y1="12" x2="19" y2="12"></line>
            </svg>
            Add Question
          </button>
        </div>
      </aside>

      <!-- Right Main Content Card -->
      <main class="assessment-main-card">
        <!-- Top Tabs -->
        <div class="card-tabs-header">
          <button type="button" class="tab-button" [class.active]="tab === 'paper'" (click)="tab = 'paper'">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
              <polyline points="14 2 14 8 20 8"></polyline>
              <line x1="16" y1="13" x2="8" y2="13"></line>
              <line x1="16" y1="17" x2="8" y2="17"></line>
            </svg>
            Questions
          </button>

          <button type="button" class="tab-button" [class.active]="tab === 'responses'" (click)="switchToResponses()">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <line x1="18" y1="20" x2="18" y2="10"></line>
              <line x1="12" y1="20" x2="12" y2="4"></line>
              <line x1="6" y1="20" x2="6" y2="14"></line>
            </svg>
            Student Responses
          </button>
        </div>

        <!-- Global Page Error Alert -->
        <div *ngIf="pageError" class="page-alert-box">
          {{ pageError }}
        </div>

        <!-- ===================== Questions Tab ===================== -->
        <ng-container *ngIf="tab === 'paper'">
          <div *ngIf="loading" class="empty-state-container">
            <div class="loader-spinner"></div>
            <p>Loading questions…</p>
          </div>

          <div *ngIf="!loading && questions.length === 0" class="empty-state-container">
            <div class="empty-icon">📄</div>
            <h3 class="empty-title">No questions yet</h3>
            <p class="empty-subtitle">Add questions manually or use Gemini AI to generate an assessment paper instantly.</p>
            <div style="display:flex;gap:12px;justify-content:center;margin-top:16px;">
              <button type="button" class="btn-ai-generate" style="width:auto;margin:0;" (click)="openAiModal()">
                ✨ Auto-Generate with AI
              </button>
              <button type="button" class="btn-add-question" style="width:auto;" (click)="openAddQuestion()">
                + Add Question
              </button>
            </div>
          </div>

          <div *ngFor="let q of questions; let i = index" class="question-item-card" [class.last-card]="i === questions.length - 1">
            <!-- Question Header Row -->
            <div class="q-header-row">
              <div class="q-badges-group">
                <span class="q-index-circle">{{ i + 1 }}</span>
                <span class="q-pill-badge q-type-pill" [style.background]="typeBadgeColor(q.questionType).bg" [style.color]="typeBadgeColor(q.questionType).fg">
                  {{ typeLabelFor(q.questionType) }}
                </span>
                <span class="q-pill-badge q-marks-pill">{{ q.marks }} mark{{ q.marks === 1 ? '' : 's' }}</span>
              </div>

              <div class="q-actions-group">
                <button type="button" class="btn-reorder" [disabled]="i === 0" (click)="move(i, -1)" title="Move up">
                  ↑
                </button>
                <button type="button" class="btn-reorder" [disabled]="i === questions.length - 1" (click)="move(i, 1)" title="Move down">
                  ↓
                </button>
                <button type="button" class="btn-action-edit" (click)="openEditQuestion(q)">
                  <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path>
                    <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path>
                  </svg>
                  Edit
                </button>
                <button type="button" class="btn-action-delete" (click)="deleteQuestion(q)">
                  <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                    <polyline points="3 6 5 6 21 6"></polyline>
                    <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
                  </svg>
                  Delete
                </button>
              </div>
            </div>

            <!-- Question Text -->
            <h2 class="q-body-text">{{ q.questionText }}</h2>

            <!-- Options List for MCQ & Multiple Answer -->
            <div class="q-options-wrapper" *ngIf="q.questionType === 'SINGLE_CHOICE' || q.questionType === 'MULTIPLE_ANSWER'">
              <div *ngFor="let o of q.options; let oi = index" class="q-option-box" [class.option-correct]="o.isCorrect">
                <div class="q-option-left">
                  <span class="q-option-index">{{ letters[oi] }}.</span>
                  <span class="q-option-label">{{ o.optionText }}</span>
                </div>
                <div *ngIf="o.isCorrect" class="q-option-correct-badge">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#059669" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
                    <polyline points="20 6 9 17 4 12"></polyline>
                  </svg>
                  Correct
                </div>
              </div>
            </div>

            <!-- Fill in the blank box -->
            <div *ngIf="q.questionType === 'FILL_IN_BLANK'" class="q-fill-blank-container">
              <span class="bold-text">Correct answer:</span> {{ q.answerText }}
            </div>

            <!-- Coding question box -->
            <div *ngIf="q.questionType === 'CODING'" class="q-coding-container">
              <div class="coding-note">Not auto-graded — a mentor reviews the student's typed answer manually.</div>
              <div *ngIf="q.answerText" class="coding-solution"><span class="bold-text">Reference Notes:</span> {{ q.answerText }}</div>
            </div>

            <!-- Explanation Callout Box -->
            <div *ngIf="q.explanation" class="q-explanation-container">
              <span class="explanation-title">Explanation:</span>
              <span class="explanation-content">{{ q.explanation }}</span>
            </div>
          </div>
        </ng-container>

        <!-- ===================== Student Responses Tab ===================== -->
        <ng-container *ngIf="tab === 'responses'">
          <div *ngIf="loadingResponses" class="empty-state-container">
            <div class="loader-spinner"></div>
            <p>Loading responses…</p>
          </div>

          <ng-container *ngIf="!loadingResponses && results">
            <div class="metrics-grid">
              <div class="metric-card">
                <div class="metric-title">Students attempted</div>
                <div class="metric-value">{{ results.studentCount }}</div>
              </div>
              <div class="metric-card">
                <div class="metric-title">Average score</div>
                <div class="metric-value">{{ results.averageScore }} / {{ results.totalMarks }}</div>
              </div>
              <div class="metric-card">
                <div class="metric-title">Questions</div>
                <div class="metric-value">{{ results.questionCount }}</div>
              </div>
            </div>

            <div *ngIf="results.studentCount === 0" class="empty-state-container">
              <p>No student has attempted this paper yet. Scores appear here automatically as soon as students submit.</p>
            </div>

            <!-- Question-wise accuracy -->
            <div class="accuracy-card" *ngIf="results.studentCount > 0">
              <h3 class="accuracy-title">Question-wise accuracy</h3>
              <div class="table-responsive">
                <table class="styled-table">
                  <thead>
                    <tr><th>#</th><th>Question</th><th>Attempts</th><th>Correct</th><th>Accuracy</th></tr>
                  </thead>
                  <tbody>
                    <tr *ngFor="let s of results.questionAnalytics; let i = index">
                      <td>{{ i + 1 }}</td>
                      <td>{{ s.questionText }}</td>
                      <td>{{ s.attempts }}</td>
                      <td>{{ s.correctCount }}</td>
                      <td>
                        <span class="badge"
                              [class.badge-success]="s.accuracy >= 70"
                              [class.badge-warning]="s.accuracy >= 40 && s.accuracy < 70"
                              [class.badge-danger]="s.accuracy < 40">{{ s.accuracy }}%</span>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>

            <!-- Student Submissions -->
            <div class="student-result-card" *ngFor="let st of results.students">
              <div class="student-row-header" (click)="toggleStudent(st.userId)">
                <div>
                  <div class="student-name">{{ st.studentName }}</div>
                  <div class="student-email">{{ st.studentEmail }}</div>
                </div>
                <div class="student-score-tags">
                  <span class="q-pill-badge" style="background:#F1F5F9;color:#475569;">{{ st.correctCount }}/{{ st.questionCount }} correct</span>
                  <span class="badge"
                        [class.badge-success]="st.percentage >= 40"
                        [class.badge-danger]="st.percentage < 40">{{ st.score }}/{{ st.totalMarks }} · {{ st.percentage }}%</span>
                  <span class="expand-arrow">{{ expanded[st.userId] ? '▴' : '▾' }}</span>
                </div>
              </div>

              <div *ngIf="expanded[st.userId]" class="student-answers-expanded">
                <div *ngFor="let a of st.answers; let ai = index" class="student-answer-item"
                     [style.background]="a.questionType === 'CODING' ? '#F8FAFC' : (a.isCorrect ? '#ECFDF5' : (a.attempted ? '#FEF2F2' : '#F8FAFC'))">
                  <div class="answer-header">
                    {{ ai + 1 }}. {{ a.questionText }}
                    <span class="badge" style="margin-left:8px;" *ngIf="a.questionType === 'CODING'">Not auto-graded</span>
                    <span class="badge" style="margin-left:8px;" *ngIf="a.questionType !== 'CODING'" [class.badge-success]="a.isCorrect" [class.badge-danger]="!a.isCorrect">
                      {{ a.isCorrect ? '✓ Correct' : (a.attempted ? '✕ Wrong' : 'Not answered') }}
                    </span>
                  </div>
                  <div class="answer-detail" *ngIf="a.questionType === 'SINGLE_CHOICE' || a.questionType === 'MULTIPLE_ANSWER'">
                    <div><strong>Chose:</strong>
                      <span *ngIf="a.selectedOptions?.length">{{ a.selectedOptions.join(', ') }}</span>
                      <span *ngIf="!a.selectedOptions?.length" style="color:#94A3B8;">— nothing selected —</span>
                    </div>
                    <div *ngIf="!a.isCorrect" style="color:#059669;"><strong>Correct answer:</strong> {{ a.correctOptions.join(', ') }}</div>
                  </div>
                  <div class="answer-detail" *ngIf="a.questionType === 'FILL_IN_BLANK' || a.questionType === 'CODING'">
                    <div><strong>Answer:</strong>
                      <span *ngIf="a.answerText">{{ a.answerText }}</span>
                      <span *ngIf="!a.answerText" style="color:#94A3B8;">— not answered —</span>
                    </div>
                    <div *ngIf="a.questionType === 'FILL_IN_BLANK' && !a.isCorrect" style="color:#059669;"><strong>Correct answer:</strong> {{ a.correctAnswerText }}</div>
                  </div>
                  <div *ngIf="a.explanation" class="answer-why"><strong>Why:</strong> {{ a.explanation }}</div>
                </div>
              </div>
            </div>
          </ng-container>
        </ng-container>
      </main>
    </div>

    <!-- ===================== Add / Edit Question Modal ===================== -->
    <div class="modal-overlay" *ngIf="showQuestionModal" (click)="closeQuestionModal($event)">
      <div class="modal-content-styled" (click)="$event.stopPropagation()">
        <form (ngSubmit)="saveQuestion()">
          <div class="modal-header-styled">
            <h2>{{ editingQuestionId ? 'Edit Question' : 'Add New Question' }}</h2>
            <button type="button" class="btn-close-modal" (click)="closeQuestionModal()">✕</button>
          </div>

          <div class="modal-body-styled">
            <div class="form-group-styled">
              <label>Question Text *</label>
              <textarea [(ngModel)]="qForm.questionText" name="questionText" rows="3" required placeholder="Type the question as the student should read it..."></textarea>
            </div>

            <div class="form-group-styled">
              <label>Question Type</label>
              <div class="radio-pill-group">
                <label [class.selected]="qForm.questionType === 'SINGLE_CHOICE'">
                  <input type="radio" name="questionType" value="SINGLE_CHOICE" [(ngModel)]="qForm.questionType" (ngModelChange)="onTypeChange()">
                  Single choice
                </label>
                <label [class.selected]="qForm.questionType === 'MULTIPLE_ANSWER'">
                  <input type="radio" name="questionType" value="MULTIPLE_ANSWER" [(ngModel)]="qForm.questionType">
                  Multiple answers
                </label>
                <label [class.selected]="qForm.questionType === 'FILL_IN_BLANK'">
                  <input type="radio" name="questionType" value="FILL_IN_BLANK" [(ngModel)]="qForm.questionType">
                  Fill in the blank
                </label>
                <label [class.selected]="qForm.questionType === 'CODING'">
                  <input type="radio" name="questionType" value="CODING" [(ngModel)]="qForm.questionType">
                  Coding
                </label>
              </div>
            </div>

            <!-- Options for MCQ -->
            <div class="form-group-styled" *ngIf="qForm.questionType === 'SINGLE_CHOICE' || qForm.questionType === 'MULTIPLE_ANSWER'">
              <label>Options (select the correct answer)</label>
              <div class="options-edit-list">
                <div *ngFor="let opt of qForm.options; let i = index" class="option-edit-row">
                  <span class="opt-edit-index">{{ letters[i] }}.</span>
                  <input type="text" [(ngModel)]="opt.optionText" [name]="'optionText' + i" placeholder="Option text" class="opt-edit-input">
                  <label class="opt-correct-checkbox-label">
                    <input type="checkbox" [ngModel]="opt.isCorrect" (ngModelChange)="setCorrect(i, $event)" [name]="'optionCorrect' + i">
                    Correct
                  </label>
                  <button type="button" class="btn-remove-opt" [disabled]="qForm.options.length <= 2" (click)="removeOption(i)">✕</button>
                </div>
              </div>
              <button type="button" class="btn-add-option-row" (click)="addOption()">+ Add Another Option</button>
            </div>

            <!-- Fill in the blank answer -->
            <div class="form-group-styled" *ngIf="qForm.questionType === 'FILL_IN_BLANK'">
              <label>Correct answer *</label>
              <input type="text" [(ngModel)]="qForm.answerText" name="answerText" placeholder="Exact text student must type" class="full-width-input">
            </div>

            <!-- Coding notes -->
            <div class="form-group-styled" *ngIf="qForm.questionType === 'CODING'">
              <label>Reference Notes (optional)</label>
              <textarea [(ngModel)]="qForm.answerText" name="answerText" rows="3" placeholder="Reference code or notes for mentor grading..."></textarea>
            </div>

            <div class="form-row-2">
              <div class="form-group-styled">
                <label>Marks</label>
                <input type="number" min="1" [(ngModel)]="qForm.marks" name="marks" class="full-width-input">
              </div>
            </div>

            <div class="form-group-styled">
              <label>Explanation (shown to student after submission)</label>
              <textarea [(ngModel)]="qForm.explanation" name="explanation" rows="2" placeholder="e.g. Java is a high-level, class-based, object-oriented programming language..."></textarea>
            </div>

            <div *ngIf="modalError" class="modal-error-box">
              {{ modalError }}
            </div>
          </div>

          <div class="modal-footer-styled">
            <button type="button" class="btn-modal-cancel" (click)="closeQuestionModal()">Cancel</button>
            <button type="submit" class="btn-modal-save" [disabled]="savingQuestion">
              {{ savingQuestion ? 'Saving...' : (editingQuestionId ? 'Update Question' : 'Save Question') }}
            </button>
          </div>
        </form>
      </div>
    </div>

    <!-- ===================== AI Auto-Quiz Generator Modal ===================== -->
    <div class="modal-overlay" *ngIf="showAiModal" (click)="closeAiModal($event)">
      <div class="modal-content-styled modal-ai-dialog" (click)="$event.stopPropagation()">
        <div class="modal-header-styled">
          <div style="display:flex;align-items:center;gap:10px;">
            <div class="ai-sparkle-circle">✨</div>
            <div>
              <h2 style="margin:0;font-size:18px;">Auto-Generate Quiz with Gemini AI</h2>
              <p style="margin:2px 0 0;font-size:12.5px;color:#64748B;">Generate curriculum-indexed MCQs directly from lesson materials or topics</p>
            </div>
          </div>
          <button type="button" class="btn-close-modal" (click)="closeAiModal()">✕</button>
        </div>

        <div class="modal-body-styled">
          <div class="form-row-2">
            <div class="form-group-styled">
              <label>1. Select Course</label>
              <select [(ngModel)]="aiSelectedCourseId" (change)="onAiCourseChange()" class="full-width-select">
                <option [ngValue]="null">-- Choose Course --</option>
                <option *ngFor="let c of aiCourses" [ngValue]="c.id">{{ c.title }}</option>
              </select>
            </div>
            <div class="form-group-styled">
              <label>2. Select Lesson</label>
              <select [(ngModel)]="aiSelectedLessonId" [disabled]="!aiSelectedCourseId || loadingAiLessons" class="full-width-select">
                <option [ngValue]="null">-- {{ loadingAiLessons ? 'Loading modules...' : 'All Course Content' }} --</option>
                <optgroup *ngFor="let m of aiModules" [label]="'📁 ' + m.title">
                  <option *ngFor="let l of m.lessons" [ngValue]="l.id">📄 {{ l.title }}</option>
                </optgroup>
              </select>
            </div>
          </div>

          <div class="form-group-styled">
            <label>Or Paste Custom Lecture Notes / Topics (Optional)</label>
            <textarea [(ngModel)]="aiCustomTopic" rows="3" placeholder="e.g. Variables, Data Types, Control Statements in Java..."></textarea>
          </div>

          <div class="form-row-3">
            <div class="form-group-styled">
              <label>Number of Questions</label>
              <select [(ngModel)]="aiQuestionCount" class="full-width-select">
                <option [ngValue]="5">5 Questions</option>
                <option [ngValue]="10">10 Questions</option>
                <option [ngValue]="15">15 Questions</option>
                <option [ngValue]="20">20 Questions</option>
              </select>
            </div>
            <div class="form-group-styled">
              <label>Marks per Question</label>
              <input type="number" min="1" [(ngModel)]="aiMarksPerQuestion" class="full-width-input">
            </div>
            <div class="form-group-styled">
              <label>Difficulty</label>
              <select [(ngModel)]="aiDifficulty" class="full-width-select">
                <option value="low">Basic / Beginner</option>
                <option value="medium">Intermediate</option>
                <option value="high">Advanced</option>
              </select>
            </div>
          </div>

          <div style="margin-top:14px;">
            <button type="button" class="btn-ai-generate" [disabled]="generatingAiQuiz" (click)="generateAiQuiz()" style="width:100%;margin:0;">
              {{ generatingAiQuiz ? 'Generating questions with Gemini AI...' : '✨ Generate Questions' }}
            </button>
          </div>

          <div *ngIf="aiGenError" class="modal-error-box" style="margin-top:12px;">
            {{ aiGenError }}
          </div>

          <!-- Preview of generated questions -->
          <div *ngIf="generatedQuestions.length > 0" class="generated-preview-container">
            <div class="generated-preview-header">
              <h3>Generated MCQs ({{ generatedQuestions.length }})</h3>
              <button type="button" class="btn-import-all" (click)="importGeneratedQuestions()" [disabled]="importingQuestions">
                {{ importingQuestions ? 'Importing...' : '📥 Import All ' + generatedQuestions.length + ' Questions' }}
              </button>
            </div>

            <div class="generated-list">
              <div *ngFor="let gq of generatedQuestions; let qi = index" class="generated-card">
                <div class="generated-q-title">Q{{ qi + 1 }}. {{ gq.question }}</div>
                <div class="generated-options-grid">
                  <div *ngFor="let opt of gq.options; let oi = index"
                       [class.correct-opt]="oi === gq.correctIndex" class="generated-opt-item">
                    <span class="opt-letter-tag">{{ letters[oi] }}.</span>
                    <span>{{ opt }}</span>
                    <span *ngIf="oi === gq.correctIndex" class="correct-badge-small">✓ Correct</span>
                  </div>
                </div>
                <div *ngIf="gq.explanation" class="generated-explanation">
                  <strong>Explanation:</strong> {{ gq.explanation }}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  `,
  styles: [`
    /* Overall layout background: clean light mint / sage tint from screenshot */
    .assessment-builder-container {
      display: flex;
      align-items: flex-start;
      gap: 24px;
      padding: 24px;
      background-color: #EBF5F3;
      border-radius: 16px;
      min-height: calc(100vh - 120px);
      box-sizing: border-box;
      font-family: inherit;
    }

    /* Left Info Card */
    .assessment-info-card {
      width: 320px;
      flex-shrink: 0;
      background: #FFFFFF;
      border-radius: 16px;
      padding: 24px;
      box-shadow: 0 4px 20px -2px rgba(0, 0, 0, 0.05);
      border: 1px solid #E2E8F0;
      box-sizing: border-box;
    }

    .btn-back {
      background: #FFFFFF;
      color: #0D9488;
      border: 1.5px solid #99F6E4;
      border-radius: 8px;
      padding: 7px 16px;
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 8px;
      transition: all 0.2s ease;
    }
    .btn-back:hover {
      background: #F0FDFA;
      border-color: #5EEAD4;
    }

    .doc-icon-badge {
      width: 44px;
      height: 44px;
      background: #F3E8FF;
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      margin-top: 24px;
      margin-bottom: 12px;
    }

    .paper-title {
      font-size: 26px;
      font-weight: 800;
      color: #0F172A;
      margin: 0 0 10px 0;
      letter-spacing: -0.02em;
      line-height: 1.25;
    }

    .paper-meta-row {
      display: flex;
      align-items: center;
      gap: 8px;
      flex-wrap: wrap;
      margin-bottom: 28px;
    }

    .type-pill {
      background: #EDE9FE;
      color: #7C3AED;
      font-size: 12px;
      font-weight: 700;
      padding: 3px 12px;
      border-radius: 9999px;
    }

    .meta-divider {
      color: #CBD5E1;
      font-size: 13px;
    }

    .meta-text {
      color: #64748B;
      font-size: 13px;
      font-weight: 500;
    }

    .left-actions-group {
      display: flex;
      flex-direction: column;
      gap: 12px;
    }

    .btn-ai-generate {
      width: 100%;
      padding: 13px 20px;
      border-radius: 12px;
      font-size: 14px;
      font-weight: 700;
      color: #FFFFFF;
      background: linear-gradient(135deg, #7C3AED 0%, #6366F1 100%);
      border: none;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      box-shadow: 0 4px 14px rgba(124, 58, 237, 0.35);
      transition: all 0.2s ease;
    }
    .btn-ai-generate:hover {
      transform: translateY(-1px);
      box-shadow: 0 6px 20px rgba(124, 58, 237, 0.45);
    }

    .btn-add-question {
      width: 100%;
      padding: 13px 20px;
      border-radius: 12px;
      font-size: 14px;
      font-weight: 700;
      color: #FFFFFF;
      background: #0D9488;
      border: none;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      box-shadow: 0 4px 14px rgba(13, 148, 136, 0.25);
      transition: all 0.2s ease;
    }
    .btn-add-question:hover {
      background: #0F766E;
      transform: translateY(-1px);
      box-shadow: 0 6px 20px rgba(13, 148, 136, 0.35);
    }

    /* Right Main Content Card */
    .assessment-main-card {
      flex: 1;
      min-width: 0;
      background: #FFFFFF;
      border-radius: 16px;
      padding: 28px;
      box-shadow: 0 4px 20px -2px rgba(0, 0, 0, 0.05);
      border: 1px solid #E2E8F0;
      box-sizing: border-box;
    }

    /* Tabs Header */
    .card-tabs-header {
      display: flex;
      gap: 12px;
      border-bottom: 2px solid #F1F5F9;
      padding-bottom: 18px;
      margin-bottom: 28px;
    }

    .tab-button {
      background: transparent;
      color: #64748B;
      border: 1.5px solid transparent;
      border-radius: 10px;
      padding: 9px 20px;
      font-weight: 600;
      font-size: 14px;
      display: inline-flex;
      align-items: center;
      gap: 8px;
      cursor: pointer;
      transition: all 0.2s ease;
    }
    .tab-button:hover {
      background: #F8FAFC;
      color: #334155;
    }
    .tab-button.active {
      background: #E6F7F5;
      color: #0D9488;
      border-color: #99F6E4;
      font-weight: 700;
    }

    .page-alert-box {
      margin-bottom: 20px;
      padding: 12px 16px;
      background: #FEE2E2;
      color: #991B1B;
      border-radius: 10px;
      font-size: 13.5px;
      border: 1px solid #FECACA;
    }

    /* Question Item Card */
    .question-item-card {
      padding-bottom: 32px;
      margin-bottom: 32px;
      border-bottom: 1px solid #F1F5F9;
    }
    .question-item-card.last-card {
      border-bottom: none;
      padding-bottom: 0;
      margin-bottom: 0;
    }

    .q-header-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 12px;
      flex-wrap: wrap;
    }

    .q-badges-group {
      display: flex;
      align-items: center;
      gap: 10px;
      flex-wrap: wrap;
    }

    .q-index-circle {
      background: #0D9488;
      color: #FFFFFF;
      width: 32px;
      height: 32px;
      border-radius: 50%;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      font-size: 14px;
      font-weight: 700;
    }

    .q-pill-badge {
      font-size: 12px;
      font-weight: 600;
      padding: 5px 14px;
      border-radius: 9999px;
    }

    .q-type-pill {
      background: #E6F7F5;
      color: #0D9488;
    }

    .q-marks-pill {
      background: #F1F5F9;
      color: #475569;
    }

    .q-actions-group {
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .btn-reorder {
      background: #F0FDF4;
      border: 1px solid #DCFCE7;
      color: #059669;
      width: 34px;
      height: 34px;
      border-radius: 8px;
      font-size: 15px;
      font-weight: 700;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      transition: all 0.15s ease;
    }
    .btn-reorder:hover:not(:disabled) {
      background: #DCFCE7;
    }
    .btn-reorder:disabled {
      opacity: 0.35;
      cursor: not-allowed;
    }

    .btn-action-edit {
      background: #0D9488;
      color: #FFFFFF;
      border: none;
      padding: 7px 16px;
      border-radius: 8px;
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 6px;
      transition: all 0.15s ease;
    }
    .btn-action-edit:hover {
      background: #0F766E;
    }

    .btn-action-delete {
      background: #FEE2E2;
      color: #DC2626;
      border: none;
      padding: 7px 16px;
      border-radius: 8px;
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 6px;
      transition: all 0.15s ease;
    }
    .btn-action-delete:hover {
      background: #FCA5A5;
      color: #991B1B;
    }

    .q-body-text {
      font-size: 18px;
      font-weight: 700;
      color: #0F172A;
      margin: 18px 0 16px 0;
      line-height: 1.4;
      white-space: pre-wrap;
    }

    /* Options List */
    .q-options-wrapper {
      display: flex;
      flex-direction: column;
      gap: 10px;
      margin-bottom: 14px;
    }

    .q-option-box {
      background: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 12px;
      padding: 13px 18px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      font-size: 14px;
      transition: all 0.15s ease;
    }

    .q-option-box.option-correct {
      background: #F0FDF4;
      border: 1.5px solid #34D399;
    }

    .q-option-left {
      display: flex;
      align-items: center;
      gap: 12px;
      flex: 1;
    }

    .q-option-index {
      font-weight: 700;
      color: #64748B;
      min-width: 24px;
      font-size: 14.5px;
    }
    .option-correct .q-option-index {
      color: #059669;
    }

    .q-option-label {
      color: #1E293B;
      font-weight: 500;
      flex: 1;
    }
    .option-correct .q-option-label {
      color: #065F46;
      font-weight: 600;
    }

    .q-option-correct-badge {
      color: #059669;
      font-weight: 700;
      font-size: 13.5px;
      display: inline-flex;
      align-items: center;
      gap: 5px;
      margin-left: 12px;
    }

    /* Fill in blank & Coding */
    .q-fill-blank-container {
      background: #ECFDF5;
      border: 1px solid #A7F3D0;
      border-radius: 10px;
      padding: 12px 16px;
      font-size: 13.5px;
      color: #047857;
      margin-top: 10px;
    }
    .q-coding-container {
      background: #F8FAFC;
      border: 1px dashed #CBD5E1;
      border-radius: 10px;
      padding: 12px 16px;
      font-size: 13px;
      color: #475569;
      margin-top: 10px;
    }
    .bold-text {
      font-weight: 700;
    }

    /* Explanation Callout */
    .q-explanation-container {
      background: #F0F9FF;
      border-left: 4px solid #0EA5E9;
      border-radius: 0 10px 10px 0;
      padding: 13px 18px;
      font-size: 13.5px;
      color: #0369A1;
      margin-top: 14px;
      line-height: 1.5;
    }
    .explanation-title {
      font-weight: 700;
      margin-right: 6px;
      color: #0284C7;
    }

    /* Empty state */
    .empty-state-container {
      text-align: center;
      padding: 48px 24px;
      color: #64748B;
    }
    .empty-icon {
      font-size: 44px;
      margin-bottom: 8px;
    }
    .empty-title {
      font-size: 17px;
      font-weight: 700;
      color: #0F172A;
      margin: 0 0 6px 0;
    }
    .empty-subtitle {
      font-size: 13.5px;
      color: #64748B;
      margin: 0;
    }

    /* Responses metrics */
    .metrics-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 16px;
      margin-bottom: 24px;
    }
    .metric-card {
      background: #F8FAFC;
      border: 1px solid #E2E8F0;
      border-radius: 12px;
      padding: 16px 20px;
    }
    .metric-title {
      color: #64748B;
      font-size: 13px;
      font-weight: 500;
    }
    .metric-value {
      font-size: 26px;
      font-weight: 800;
      color: #0F172A;
      margin-top: 4px;
    }

    .accuracy-card {
      background: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 12px;
      padding: 20px;
      margin-bottom: 24px;
    }
    .accuracy-title {
      font-size: 16px;
      font-weight: 700;
      margin: 0 0 16px 0;
      color: #0F172A;
    }

    .styled-table {
      width: 100%;
      border-collapse: collapse;
      font-size: 13.5px;
    }
    .styled-table th {
      text-align: left;
      padding: 10px 12px;
      background: #F8FAFC;
      color: #475569;
      font-weight: 600;
      border-bottom: 1px solid #E2E8F0;
    }
    .styled-table td {
      padding: 12px;
      border-bottom: 1px solid #F1F5F9;
      color: #1E293B;
    }

    .student-result-card {
      background: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 12px;
      padding: 16px 20px;
      margin-bottom: 12px;
      transition: all 0.15s ease;
    }
    .student-row-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 12px;
      cursor: pointer;
      flex-wrap: wrap;
    }
    .student-name {
      font-weight: 700;
      color: #0F172A;
      font-size: 15px;
    }
    .student-email {
      color: #64748B;
      font-size: 12.5px;
      margin-top: 2px;
    }
    .student-score-tags {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .expand-arrow {
      font-size: 18px;
      color: #94A3B8;
    }
    .student-answers-expanded {
      margin-top: 16px;
      padding-top: 16px;
      border-top: 1px solid #E2E8F0;
      display: grid;
      gap: 12px;
    }
    .student-answer-item {
      padding: 14px;
      border-radius: 10px;
      font-size: 13.5px;
    }
    .answer-header {
      font-weight: 700;
      color: #0F172A;
      margin-bottom: 6px;
    }
    .answer-detail {
      color: #475569;
      margin-top: 4px;
      font-size: 13px;
    }
    .answer-why {
      margin-top: 6px;
      color: #0369A1;
      font-size: 13px;
    }

    /* Modal Styling */
    .modal-overlay {
      position: fixed;
      top: 0;
      left: 0;
      width: 100vw;
      height: 100vh;
      background: rgba(15, 23, 42, 0.6);
      backdrop-filter: blur(4px);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 1000;
      padding: 20px;
      box-sizing: border-box;
    }

    .modal-content-styled {
      background: #FFFFFF;
      border-radius: 18px;
      box-shadow: 0 20px 40px rgba(0, 0, 0, 0.15);
      width: 100%;
      max-width: 680px;
      max-height: 90vh;
      display: flex;
      flex-direction: column;
      overflow: hidden;
      box-sizing: border-box;
    }
    .modal-ai-dialog {
      max-width: 760px;
    }

    .modal-header-styled {
      padding: 20px 24px;
      border-bottom: 1px solid #E2E8F0;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .modal-header-styled h2 {
      margin: 0;
      font-size: 18px;
      font-weight: 700;
      color: #0F172A;
    }
    .btn-close-modal {
      background: transparent;
      border: none;
      font-size: 18px;
      color: #94A3B8;
      cursor: pointer;
      padding: 4px 8px;
      border-radius: 6px;
    }
    .btn-close-modal:hover {
      background: #F1F5F9;
      color: #475569;
    }

    .modal-body-styled {
      padding: 24px;
      overflow-y: auto;
      flex: 1;
    }

    .modal-footer-styled {
      padding: 16px 24px;
      border-top: 1px solid #E2E8F0;
      display: flex;
      justify-content: flex-end;
      gap: 12px;
      background: #F8FAFC;
    }

    .btn-modal-cancel {
      padding: 9px 18px;
      background: #FFFFFF;
      border: 1px solid #CBD5E1;
      border-radius: 8px;
      font-size: 13.5px;
      font-weight: 600;
      color: #475569;
      cursor: pointer;
    }
    .btn-modal-cancel:hover {
      background: #F1F5F9;
    }
    .btn-modal-save {
      padding: 9px 20px;
      background: #0D9488;
      border: none;
      border-radius: 8px;
      font-size: 13.5px;
      font-weight: 600;
      color: #FFFFFF;
      cursor: pointer;
    }
    .btn-modal-save:hover {
      background: #0F766E;
    }

    .form-group-styled {
      margin-bottom: 18px;
    }
    .form-group-styled label {
      display: block;
      font-size: 13px;
      font-weight: 600;
      color: #334155;
      margin-bottom: 6px;
    }
    .form-group-styled textarea,
    .full-width-input,
    .full-width-select {
      width: 100%;
      padding: 10px 14px;
      border: 1px solid #CBD5E1;
      border-radius: 8px;
      font-size: 13.5px;
      box-sizing: border-box;
      font-family: inherit;
    }
    .form-group-styled textarea:focus,
    .full-width-input:focus,
    .full-width-select:focus {
      outline: none;
      border-color: #0D9488;
      box-shadow: 0 0 0 3px rgba(13, 148, 136, 0.15);
    }

    .radio-pill-group {
      display: flex;
      gap: 10px;
      flex-wrap: wrap;
    }
    .radio-pill-group label {
      padding: 7px 14px;
      border: 1.5px solid #E2E8F0;
      border-radius: 8px;
      font-size: 13px;
      font-weight: 500;
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 6px;
      margin: 0;
      transition: all 0.15s ease;
    }
    .radio-pill-group label.selected {
      background: #E6F7F5;
      border-color: #0D9488;
      color: #0D9488;
      font-weight: 700;
    }

    .options-edit-list {
      display: flex;
      flex-direction: column;
      gap: 10px;
      margin-bottom: 12px;
    }
    .option-edit-row {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .opt-edit-index {
      font-weight: 700;
      color: #64748B;
      min-width: 20px;
    }
    .opt-edit-input {
      flex: 1;
      padding: 8px 12px;
      border: 1px solid #CBD5E1;
      border-radius: 8px;
      font-size: 13.5px;
    }
    .opt-correct-checkbox-label {
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      white-space: nowrap;
      color: #059669;
      margin: 0;
    }
    .btn-remove-opt {
      background: #FEE2E2;
      color: #DC2626;
      border: none;
      width: 28px;
      height: 28px;
      border-radius: 6px;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: 700;
    }
    .btn-remove-opt:disabled {
      opacity: 0.3;
      cursor: not-allowed;
    }
    .btn-add-option-row {
      padding: 7px 14px;
      background: #F8FAFC;
      border: 1px solid #CBD5E1;
      border-radius: 8px;
      font-size: 13px;
      font-weight: 600;
      color: #334155;
      cursor: pointer;
    }

    .form-row-2 {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 14px;
    }
    .form-row-3 {
      display: grid;
      grid-template-columns: 1fr 1fr 1fr;
      gap: 14px;
    }

    .modal-error-box {
      margin-top: 12px;
      padding: 10px 14px;
      background: #FEE2E2;
      color: #991B1B;
      border-radius: 8px;
      font-size: 13px;
    }

    /* AI Modal specifics */
    .ai-sparkle-circle {
      width: 36px;
      height: 36px;
      border-radius: 50%;
      background: linear-gradient(135deg, #7C3AED, #6366F1);
      color: #FFFFFF;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 18px;
    }
    .generated-preview-container {
      margin-top: 20px;
      border-top: 1px solid #E2E8F0;
      padding-top: 16px;
    }
    .generated-preview-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 14px;
    }
    .generated-preview-header h3 {
      margin: 0;
      font-size: 15px;
      font-weight: 700;
      color: #0F172A;
    }
    .btn-import-all {
      padding: 8px 18px;
      background: #0D9488;
      color: #FFFFFF;
      border: none;
      border-radius: 8px;
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
    }
    .btn-import-all:hover {
      background: #0F766E;
    }
    .generated-list {
      display: flex;
      flex-direction: column;
      gap: 12px;
      max-height: 400px;
      overflow-y: auto;
    }
    .generated-card {
      background: #F8FAFC;
      border: 1px solid #E2E8F0;
      border-radius: 10px;
      padding: 14px;
    }
    .generated-q-title {
      font-weight: 700;
      font-size: 14px;
      color: #0F172A;
      margin-bottom: 10px;
    }
    .generated-options-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 8px;
      margin-bottom: 8px;
    }
    .generated-opt-item {
      border: 1px solid #E2E8F0;
      background: #FFFFFF;
      border-radius: 6px;
      padding: 6px 10px;
      font-size: 12.5px;
      display: flex;
      align-items: center;
      gap: 6px;
      color: #334155;
    }
    .generated-opt-item.correct-opt {
      background: #ECFDF5;
      border-color: #10B981;
      color: #065F46;
      font-weight: 600;
    }
    .opt-letter-tag {
      font-weight: 700;
      color: #64748B;
    }
    .correct-opt .opt-letter-tag {
      color: #059669;
    }
    .correct-badge-small {
      margin-left: auto;
      color: #059669;
      font-weight: 700;
      font-size: 11.5px;
    }
    .generated-explanation {
      font-size: 12px;
      color: #64748B;
      margin-top: 6px;
      background: #F1F5F9;
      padding: 6px 10px;
      border-radius: 6px;
    }

    /* Responsive */
    @media (max-width: 960px) {
      .assessment-builder-container {
        flex-direction: column;
      }
      .assessment-info-card {
        width: 100%;
      }
    }
  `]
})
export class AssessmentPaperComponent implements OnInit {
  private api = inject(ApiService);
  private confirm = inject(ConfirmService);
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

  // AI Modal properties
  showAiModal = false;
  aiCourses: any[] = [];
  aiSelectedCourseId: number | null = null;
  aiModules: any[] = [];
  aiSelectedLessonId: number | null = null;
  loadingAiLessons = false;
  aiCustomTopic = '';
  aiQuestionCount = 10;
  aiMarksPerQuestion = 1;
  aiDifficulty = 'low';
  generatingAiQuiz = false;
  aiGenError = '';
  generatedQuestions: Array<{
    question: string;
    options: string[];
    correctIndex: number;
    explanation?: string;
  }> = [];
  importingQuestions = false;

  get typeLabel(): string {
    if (this.type === 'exams') return 'Exam';
    if (this.type === 'company-kit') return 'Company Kit';
    return 'Assignment';
  }

  typeBadgeColor(type: QuestionType): { bg: string; fg: string } {
    switch (type) {
      case 'MULTIPLE_ANSWER': return { bg: '#FEF3C7', fg: '#B45309' };
      case 'FILL_IN_BLANK': return { bg: '#ECFDF5', fg: '#047857' };
      case 'CODING': return { bg: '#EDE9FE', fg: '#6D28D9' };
      default: return { bg: '#E6F7F5', fg: '#0D9488' };
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

  async deleteQuestion(q: PaperQuestion) {
    if (!(await this.confirm.confirm('Delete this question? Any answers students already gave for it are removed too.'))) return;
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

  // ------------------------------------------------------------ AI Auto-Quiz Generator

  openAiModal() {
    this.showAiModal = true;
    this.aiGenError = '';
    this.generatedQuestions = [];
    if (this.aiCourses.length === 0) {
      this.api.get<any[]>('/api/courses').subscribe({
        next: (courses) => {
          this.aiCourses = courses || [];
        },
        error: (err) => console.error('Failed to load courses for AI quiz', err)
      });
    }
  }

  closeAiModal(event?: Event) {
    if (event && event.target !== event.currentTarget) return;
    this.showAiModal = false;
  }

  onAiCourseChange() {
    this.aiSelectedLessonId = null;
    this.aiModules = [];
    if (!this.aiSelectedCourseId) return;

    this.loadingAiLessons = true;
    this.api.get<any>(`/api/courses/${this.aiSelectedCourseId}`).subscribe({
      next: (course) => {
        this.aiModules = course?.modules || [];
        this.loadingAiLessons = false;
      },
      error: (err) => {
        console.error('Failed to load course modules', err);
        this.loadingAiLessons = false;
      }
    });
  }

  generateAiQuiz() {
    this.aiGenError = '';
    this.generatingAiQuiz = true;

    const payload = {
      lessonId: this.aiSelectedLessonId,
      topicOrNotes: this.aiCustomTopic,
      count: this.aiQuestionCount,
      difficulty: this.aiDifficulty || 'low'
    };

    this.api.post<any>('/api/ai/generate-quiz', payload).subscribe({
      next: (res) => {
        this.generatedQuestions = res?.questions || [];
        this.generatingAiQuiz = false;
        if (this.generatedQuestions.length === 0) {
          this.aiGenError = 'No questions generated. Please verify your prompt or API key in Settings.';
        }
      },
      error: (err) => {
        this.generatingAiQuiz = false;
        this.aiGenError = err?.error?.error || 'Failed to generate quiz with AI. Please ensure AI configuration is enabled in Settings.';
      }
    });
  }

  importGeneratedQuestions() {
    if (this.generatedQuestions.length === 0 || this.importingQuestions) return;

    this.importingQuestions = true;
    const base = `/api/assessments/${this.type}/${this.assessmentId}/questions/bulk`;

    const payloads = this.generatedQuestions.map(gq => ({
      questionText: gq.question,
      questionType: 'SINGLE_CHOICE',
      explanation: gq.explanation || null,
      marks: Number(this.aiMarksPerQuestion) || 1,
      options: gq.options.map((opt, idx) => ({
        optionText: opt,
        isCorrect: idx === gq.correctIndex
      }))
    }));

    this.api.post<any>(base, payloads).subscribe({
      next: () => {
        this.importingQuestions = false;
        this.showAiModal = false;
        this.loadQuestions();
      },
      error: (err) => {
        console.error('Failed to bulk import questions', err);
        this.importingQuestions = false;
        this.aiGenError = err?.error?.message || 'Failed to import questions. Please check connection and try again.';
      }
    });
  }
}
