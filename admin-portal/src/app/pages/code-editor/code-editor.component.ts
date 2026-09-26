import { Component, OnInit, OnDestroy, inject, HostListener } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { ApiService } from '../../services/api.service';
import { CurrentOrgService } from '../../services/current-org.service';

export interface TestCaseResult {
  testCaseNumber: number;
  passed: boolean;
  input: string;
  expectedOutput: string;
  actualOutput: string;
  errorOutput?: string;
  executionTimeMs: number;
  status: string;
  isSample?: boolean;
}

export interface RunResponse {
  success: boolean;
  verdict: string;
  results: TestCaseResult[];
  error?: string;
}

export interface SubmitResponse {
  success: boolean;
  verdict: string;
  testCasesPassed: number;
  totalTestCases: number;
  marksAwarded: number;
  totalMarks: number;
  scorePercentage: number;
  message: string;
  results: TestCaseResult[];
  error?: string;
}

export interface CodingQuestionData {
  id: number;
  title: string;
  questionText: string;
  explanation?: string;
  marks: number;
  difficulty?: string;
  constraints?: string;
  inputFormat?: string;
  outputFormat?: string;
  starterJava?: string;
  starterPython?: string;
  sampleTestCases?: Array<{
    id?: number;
    input: string;
    expectedOutput: string;
    explanation?: string;
  }>;
  totalTestCases?: number;
  tenantSlug?: string;
  orgName?: string;
  orgLogoUrl?: string;
  orgBrandColor?: string;
}

@Component({
  selector: 'app-code-editor',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './code-editor.component.html',
  styleUrls: ['./code-editor.component.css']
})
export class CodeEditorComponent implements OnInit, OnDestroy {
  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private api = inject(ApiService);
  private currentOrgService = inject(CurrentOrgService);

  // Route & Context Params
  questionId: number | null = null;
  assessmentType: string | null = null;
  assessmentId: number | null = null;
  userId: number | null = null;

  // Question details & Branding
  loadingProblem = true;
  problem: CodingQuestionData | null = null;
  orgName = 'Axisora LMS';
  orgLogoUrl: string | null = null;
  orgBrandColor = '#3B82F6';

  // Coding State
  selectedLanguage: 'JAVA' | 'PYTHON' = 'JAVA';
  sourceCode = '';
  javaCode = '';
  pythonCode = '';
  lineCount = 1;
  lineNumbers: number[] = [1];

  // Editor layout split percentage (left 25%, right 75% by default)
  leftWidthPercent = 28; // slightly generous for comfortable reading, user can resize
  isDraggingDivider = false;

  // Mobile View Switcher ('problem' | 'editor')
  mobileViewTab: 'problem' | 'editor' = 'problem';

  // Left sidebar tabs
  leftTab: 'description' | 'submissions' | 'hints' = 'description';

  // Bottom Console / Test Results
  consoleTab: 'cases' | 'custom' | 'results' = 'cases';
  selectedCaseTab = 0;
  customInput = '';
  useCustomInput = false;

  // Running & Submission State
  isRunning = false;
  isSubmitting = false;
  runResponse: RunResponse | null = null;
  submitResponse: SubmitResponse | null = null;
  activeVerdict: string | null = null;
  activeVerdictColor = '#10B981';
  copyTooltip = '';

  // Theme & font
  editorFontSize = 14;
  copiedIndex: number | null = null;

  ngOnInit(): void {
    this.route.paramMap.subscribe(params => {
      const qIdStr = params.get('questionId');
      if (qIdStr) {
        this.questionId = Number(qIdStr);
      }
    });

    this.route.queryParamMap.subscribe(qParams => {
      if (!this.questionId && qParams.get('questionId')) {
        this.questionId = Number(qParams.get('questionId'));
      }
      this.assessmentType = qParams.get('assessmentType');
      if (qParams.get('assessmentId')) {
        this.assessmentId = Number(qParams.get('assessmentId'));
      }
      if (qParams.get('userId')) {
        this.userId = Number(qParams.get('userId'));
      }
      const tenantParam = qParams.get('tenant') || qParams.get('tenantSlug');
      if (tenantParam && tenantParam.trim()) {
        try {
          localStorage.setItem('tenant_slug', tenantParam.trim().toLowerCase());
        } catch (_) {}
      }
      const tokenParam = qParams.get('token') || qParams.get('authToken') || qParams.get('access_token');
      if (tokenParam && tokenParam.trim()) {
        try {
          localStorage.setItem('access_token', tokenParam.trim());
        } catch (_) {}
      }

      this.loadQuestion();
    });
  }

  ngOnDestroy(): void {
    this.cancelAutoRedirect();
  }

  loadQuestion(): void {
    if (!this.questionId) {
      // Load clean boilerplate starter if no questionId
      this.problem = this.getDefaultProblem();
      this.initCodeTemplates();
      this.loadingProblem = false;
      return;
    }

    this.loadingProblem = true;
    const tenantParam = this.route.snapshot.queryParamMap.get('tenant') || this.route.snapshot.queryParamMap.get('tenantSlug');
    const query = tenantParam ? `?tenant=${encodeURIComponent(tenantParam.trim().toLowerCase())}` : '';
    this.api.get<CodingQuestionData>(`/api/coding/questions/${this.questionId}${query}`).subscribe({
      next: (data) => {
        this.problem = data;
        if (data.orgName) this.orgName = data.orgName;
        if (data.orgLogoUrl) this.orgLogoUrl = data.orgLogoUrl;
        if (data.orgBrandColor) this.orgBrandColor = data.orgBrandColor;
        if (data.tenantSlug) {
          try {
            localStorage.setItem('tenant_slug', data.tenantSlug.toLowerCase());
          } catch (_) {}
        }
        this.initCodeTemplates();
        this.loadingProblem = false;
      },
      error: (err) => {
        console.warn('Failed to load coding question from backend:', err);
        this.problem = {
          id: this.questionId || 0,
          title: `Coding Challenge #${this.questionId || ''}`,
          marks: 10,
          difficulty: 'MEDIUM',
          questionText: err?.status === 404
            ? `Question #${this.questionId} could not be found in the current organization bank.`
            : 'Unable to load question details. Please ensure the backend is running.',
          starterJava: `import java.util.*;\n\npublic class Solution {\n    public static void main(String[] args) {\n        Scanner scanner = new Scanner(System.in);\n        // Write your solution here\n        \n    }\n}`,
          starterPython: `import sys\n\ndef main():\n    # Write your solution here\n    pass\n\nif __name__ == '__main__':\n    main()\n`,
          sampleTestCases: [],
          totalTestCases: 0,
          orgName: this.orgName
        };
        this.initCodeTemplates();
        this.loadingProblem = false;
      }
    });
  }

  private getDefaultProblem(): CodingQuestionData {
    return {
      id: 0,
      title: 'Coding Playground',
      difficulty: 'EASY',
      marks: 10,
      questionText: 'Welcome to the Realtime Coding Playground. Write and execute Java or Python solutions with custom inputs or verify against test cases.',
      inputFormat: 'Read from standard input (stdin).',
      outputFormat: 'Print result to standard output (stdout).',
      constraints: 'Time Limit: 5.0 seconds\nMemory Limit: 256 MB',
      starterJava: `import java.util.*;\n\npublic class Solution {\n    public static void main(String[] args) {\n        Scanner scanner = new Scanner(System.in);\n        // Write your solution here\n        \n    }\n}`,
      starterPython: `import sys\n\ndef main():\n    # Write your solution here\n    pass\n\nif __name__ == '__main__':\n    main()\n`,
      sampleTestCases: [],
      totalTestCases: 0,
      orgName: this.orgName || 'Axisora LMS'
    };
  }

  private initCodeTemplates(): void {
    const javaDefault = this.problem?.starterJava ||
`import java.util.Scanner;

public class Solution {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);
        // Write your solution here
        
    }
}`;

    const pythonDefault = this.problem?.starterPython ||
`import sys

def main():
    # Read input from standard input
    input_data = sys.stdin.read().strip()
    # Write your solution here
    print(input_data)

if __name__ == '__main__':
    main()`;

    this.javaCode = javaDefault;
    this.pythonCode = pythonDefault;
    this.sourceCode = this.selectedLanguage === 'JAVA' ? this.javaCode : this.pythonCode;
    this.updateLineNumbers();

    if (this.problem?.sampleTestCases && this.problem.sampleTestCases.length > 0) {
      this.customInput = this.problem.sampleTestCases[0].input || '';
      this.consoleTab = 'cases';
    } else {
      this.consoleTab = 'custom';
      this.useCustomInput = true;
    }
  }

  switchConsoleTab(tab: 'cases' | 'custom' | 'results'): void {
    this.consoleTab = tab;
    if (tab === 'custom') {
      this.useCustomInput = true;
    }
  }

  onCustomInputChange(): void {
    if (this.customInput && this.customInput.trim().length > 0) {
      this.useCustomInput = true;
    }
  }

  onLanguageChange(lang: 'JAVA' | 'PYTHON'): void {
    // Save current code
    if (this.selectedLanguage === 'JAVA') {
      this.javaCode = this.sourceCode;
    } else {
      this.pythonCode = this.sourceCode;
    }

    this.selectedLanguage = lang;
    this.sourceCode = lang === 'JAVA' ? this.javaCode : this.pythonCode;
    this.updateLineNumbers();
  }

  onCodeInput(): void {
    if (this.selectedLanguage === 'JAVA') {
      this.javaCode = this.sourceCode;
    } else {
      this.pythonCode = this.sourceCode;
    }
    this.updateLineNumbers();
  }

  updateLineNumbers(): void {
    const lines = this.sourceCode.split('\n');
    this.lineCount = Math.max(lines.length, 1);
    this.lineNumbers = Array.from({ length: this.lineCount }, (_, i) => i + 1);
  }

  // Handle Tab key indentation inside editor
  onKeyDown(event: KeyboardEvent, textarea: HTMLTextAreaElement): void {
    // Tab key handling
    if (event.key === 'Tab') {
      event.preventDefault();
      const start = textarea.selectionStart;
      const end = textarea.selectionEnd;
      const indent = '    '; // 4 spaces
      this.sourceCode = this.sourceCode.substring(0, start) + indent + this.sourceCode.substring(end);
      setTimeout(() => {
        textarea.selectionStart = textarea.selectionEnd = start + indent.length;
        this.onCodeInput();
      }, 0);
      return;
    }

    // Ctrl+Enter / Cmd+Enter: Run Code
    if ((event.ctrlKey || event.metaKey) && event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      this.runCode();
      return;
    }

    // Ctrl+Shift+Enter / Cmd+Shift+Enter: Submit Code
    if ((event.ctrlKey || event.metaKey) && event.key === 'Enter' && event.shiftKey) {
      event.preventDefault();
      this.submitCode();
      return;
    }
  }

  syncScroll(textarea: HTMLTextAreaElement, gutter: HTMLDivElement): void {
    gutter.scrollTop = textarea.scrollTop;
  }

  resetCode(): void {
    if (confirm('Reset to initial starter template? Your current code changes will be lost.')) {
      if (this.selectedLanguage === 'JAVA') {
        this.sourceCode = this.problem?.starterJava || this.getDefaultProblem().starterJava!;
        this.javaCode = this.sourceCode;
      } else {
        this.sourceCode = this.problem?.starterPython || this.getDefaultProblem().starterPython!;
        this.pythonCode = this.sourceCode;
      }
      this.updateLineNumbers();
    }
  }

  runCode(): void {
    if (this.isRunning || this.isSubmitting) return;

    const userWasOnCustomTab = this.consoleTab === 'custom';
    this.isRunning = true;
    this.mobileViewTab = 'editor';
    this.consoleTab = 'results';
    this.runResponse = null;
    this.activeVerdict = 'RUNNING';

    const payload: any = {
      language: this.selectedLanguage,
      code: this.sourceCode,
      sourceCode: this.sourceCode
    };

    const hasCustomInput = !!(this.customInput && this.customInput.trim().length > 0);
    const hasSampleCases = !!(this.problem?.sampleTestCases && this.problem.sampleTestCases.length > 0);
    const shouldUseCustom = this.useCustomInput || userWasOnCustomTab || (!hasSampleCases && hasCustomInput);

    if (shouldUseCustom && hasCustomInput) {
      payload.customInput = this.customInput;
    } else {
      if (this.questionId && this.questionId > 0) {
        payload.questionId = this.questionId;
      }
      if (hasSampleCases && this.problem?.sampleTestCases) {
        payload.customTestCases = this.problem.sampleTestCases;
      } else if (hasCustomInput) {
        payload.customInput = this.customInput;
      }
    }

    this.api.post<any>('/api/coding/run', payload).subscribe({
      next: (res: any) => {
        this.isRunning = false;
        const verdict = res.verdict || res.overallStatus || (res.success ? 'SUCCESS' : 'WRONG_ANSWER');
        const rawResults = res.results || [];
        const mappedResults: TestCaseResult[] = rawResults.map((r: any, idx: number) => ({
          testCaseNumber: r.testCaseNumber || r.testCaseIndex || (idx + 1),
          passed: !!r.passed,
          input: r.input || '',
          expectedOutput: r.expectedOutput || '',
          actualOutput: r.actualOutput || '',
          errorOutput: r.errorOutput || r.error || '',
          executionTimeMs: r.executionTimeMs || 0,
          status: r.status || (r.passed ? 'SUCCESS' : 'FAILED'),
          isSample: r.isSample
        }));

        this.runResponse = {
          success: res.success !== undefined ? res.success : (verdict === 'SUCCESS' || verdict === 'ACCEPTED'),
          verdict: verdict,
          results: mappedResults,
          error: res.error || res.compilationError
        };
        this.activeVerdict = verdict;
        this.setVerdictColor(verdict);
        if (mappedResults.length > 0) {
          this.selectedCaseTab = 0;
        }
      },
      error: (err) => {
        this.isRunning = false;
        this.activeVerdict = 'ERROR';
        this.runResponse = {
          success: false,
          verdict: 'RUNTIME_ERROR',
          results: [],
          error: err?.error?.message || 'Execution service unreachable. Please ensure the backend is running.'
        };
      }
    });
  }

  submitCode(): void {
    if (this.isRunning || this.isSubmitting) return;

    this.isSubmitting = true;
    this.mobileViewTab = 'editor';
    this.consoleTab = 'results';
    this.submitResponse = null;
    this.activeVerdict = 'EVALUATING';

    const payload: any = {
      questionId: this.questionId || (this.problem ? this.problem.id : 0),
      language: this.selectedLanguage,
      code: this.sourceCode,
      sourceCode: this.sourceCode,
      assessmentType: this.assessmentType,
      assessmentId: this.assessmentId,
      userId: this.userId
    };

    if (this.problem?.sampleTestCases && this.problem.sampleTestCases.length > 0) {
      payload.customTestCases = this.problem.sampleTestCases;
    }

    this.api.post<any>('/api/coding/submit', payload).subscribe({
      next: (res: any) => {
        this.isSubmitting = false;
        const verdict = res.verdict || res.status || (res.allPassed ? 'ACCEPTED' : 'WRONG_ANSWER');
        const rawResults = res.results || [];
        const mappedResults: TestCaseResult[] = rawResults.map((r: any, idx: number) => ({
          testCaseNumber: r.testCaseNumber || r.testCaseIndex || (idx + 1),
          passed: !!r.passed,
          input: r.input || '',
          expectedOutput: r.expectedOutput || '',
          actualOutput: r.actualOutput || '',
          errorOutput: r.errorOutput || r.error || '',
          executionTimeMs: r.executionTimeMs || 0,
          status: r.status || (r.passed ? 'PASSED' : 'FAILED'),
          isSample: r.isSample
        }));

        const passedCount = res.testCasesPassed ?? res.passedTestCases ?? 0;
        const totalCount = res.totalTestCases ?? (mappedResults.length > 0 ? mappedResults.length : (this.problem?.totalTestCases || 0));
        const totalMarks = res.totalMarks ?? (this.problem?.marks || 10);
        const marksAwarded = res.marksAwarded ?? (totalCount > 0 ? Math.round((passedCount / totalCount) * totalMarks) : 0);
        const scorePercent = res.scorePercentage ?? (totalCount > 0 ? Math.round((passedCount / totalCount) * 100) : 0);

        this.submitResponse = {
          success: !!(res.success || res.allPassed || verdict === 'ACCEPTED'),
          verdict: verdict,
          testCasesPassed: passedCount,
          totalTestCases: totalCount,
          marksAwarded: marksAwarded,
          totalMarks: totalMarks,
          scorePercentage: scorePercent,
          message: res.message || `${passedCount}/${totalCount} test cases passed.`,
          results: mappedResults,
          error: res.error || res.compilationError
        };
        this.activeVerdict = verdict;
        this.setVerdictColor(verdict);
        this.leftTab = 'submissions';
        if (mappedResults.length > 0) {
          this.selectedCaseTab = 0;
        }

        if (this.assessmentType && this.assessmentId) {
          this.startAutoRedirectCountdown();
        }
      },
      error: (err) => {
        this.isSubmitting = false;
        this.activeVerdict = 'ERROR';
        this.submitResponse = {
          success: false,
          verdict: 'RUNTIME_ERROR',
          testCasesPassed: 0,
          totalTestCases: 0,
          marksAwarded: 0,
          totalMarks: this.problem?.marks || 10,
          scorePercentage: 0,
          message: err?.error?.message || 'Submission failed. Please try again.',
          results: []
        };
      }
    });
  }

  setVerdictColor(verdict: string): void {
    switch (verdict) {
      case 'ACCEPTED':
        this.activeVerdictColor = '#10B981';
        break;
      case 'WRONG_ANSWER':
        this.activeVerdictColor = '#EF4444';
        break;
      case 'COMPILATION_ERROR':
        this.activeVerdictColor = '#F59E0B';
        break;
      case 'TIME_LIMIT_EXCEEDED':
        this.activeVerdictColor = '#EAB308';
        break;
      case 'RUNTIME_ERROR':
      default:
        this.activeVerdictColor = '#F43F5E';
        break;
    }
  }

  copySampleInput(input: string, index: number): void {
    navigator.clipboard.writeText(input);
    this.copiedIndex = index;
    setTimeout(() => {
      if (this.copiedIndex === index) this.copiedIndex = null;
    }, 2000);
  }

  // Divider resize handlers
  startResize(event: MouseEvent): void {
    this.isDraggingDivider = true;
    event.preventDefault();
  }

  @HostListener('window:mousemove', ['$event'])
  onMouseMove(event: MouseEvent): void {
    if (!this.isDraggingDivider) return;
    const windowWidth = window.innerWidth;
    const newWidthPercent = (event.clientX / windowWidth) * 100;
    if (newWidthPercent >= 18 && newWidthPercent <= 60) {
      this.leftWidthPercent = Math.round(newWidthPercent * 10) / 10;
    }
  }

  @HostListener('window:mouseup')
  onMouseUp(): void {
    this.isDraggingDivider = false;
  }

  autoRedirectCountdown: number = 0;
  private redirectTimer: any = null;

  startAutoRedirectCountdown(): void {
    this.cancelAutoRedirect();
    this.autoRedirectCountdown = 3;
    this.redirectTimer = setInterval(() => {
      this.autoRedirectCountdown--;
      if (this.autoRedirectCountdown <= 0) {
        this.cancelAutoRedirect();
        this.returnToAssessment();
      }
    }, 1000);
  }

  cancelAutoRedirect(): void {
    if (this.redirectTimer) {
      clearInterval(this.redirectTimer);
      this.redirectTimer = null;
    }
    this.autoRedirectCountdown = 0;
  }

  navigateBack(): void {
    this.returnToAssessment();
  }

  returnToAssessment(): void {
    this.cancelAutoRedirect();

    // 1. Notify Flutter in_app_browser via JS handler
    try {
      if ((window as any).flutter_inappwebview?.callHandler) {
        (window as any).flutter_inappwebview.callHandler('returnToPaper', {
          questionId: this.questionId,
          score: this.submitResponse?.marksAwarded,
          allPassed: this.submitResponse?.success,
          code: this.sourceCode
        });
        return;
      }
    } catch (_) {}

    // 2. Post message to parent window (if in popup / iframe)
    try {
      if (window.opener) {
        window.opener.postMessage({
          type: 'CODING_SUBMISSION_COMPLETE',
          questionId: this.questionId,
          score: this.submitResponse?.marksAwarded,
          verdict: this.submitResponse?.verdict,
          code: this.sourceCode
        }, '*');
        window.close();
        return;
      }
    } catch (_) {}

    // 3. Fallback to browser history back or custom scheme
    if (window.history.length > 1) {
      window.history.back();
    } else {
      window.location.href = `lms://return-to-paper?questionId=${this.questionId}&score=${this.submitResponse?.marksAwarded || 0}&assessmentId=${this.assessmentId || 0}&type=${this.assessmentType || ''}`;
    }
  }
}
