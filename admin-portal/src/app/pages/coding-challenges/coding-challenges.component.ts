import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { ApiService } from '../../services/api.service';
import { ConfirmService } from '../../services/confirm.service';

export interface TestCaseItem {
  id?: number;
  input: string;
  expectedOutput: string;
  isSample: boolean;
  explanation?: string;
  displayOrder?: number;
}

export interface CodingChallengeItem {
  id: number;
  title: string;
  questionText: string;
  explanation?: string;
  marks: number;
  difficulty: 'EASY' | 'MEDIUM' | 'HARD';
  constraints?: string;
  inputFormat?: string;
  outputFormat?: string;
  starterJava?: string;
  starterPython?: string;
  testCases?: TestCaseItem[];
  testCaseCount?: number;
}

@Component({
  selector: 'app-coding-challenges',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './coding-challenges.component.html',
  styleUrls: ['./coding-challenges.component.css']
})
export class CodingChallengesComponent implements OnInit {
  private api = inject(ApiService);
  private confirm = inject(ConfirmService);
  private router = inject(Router);

  openPlayground(): void {
    window.open('/code-editor', '_blank');
  }

  challenges: CodingChallengeItem[] = [];
  filteredChallenges: CodingChallengeItem[] = [];
  loading = true;
  searchQuery = '';
  selectedDifficulty = 'ALL';

  // Modal State
  showModal = false;
  isEditing = false;
  editingId: number | null = null;
  saving = false;
  modalTab: 'basic' | 'starter' | 'testcases' = 'basic';
  modalError = '';

  // Form Model
  formTitle = '';
  formQuestionText = '';
  formExplanation = '';
  formMarks = 10;
  formDifficulty: 'EASY' | 'MEDIUM' | 'HARD' = 'EASY';
  formConstraints = '1 <= N <= 10^5\nTime Limit: 5.0s\nMemory Limit: 256MB';
  formInputFormat = 'First line contains an integer T. Subsequent lines contain...';
  formOutputFormat = 'Print the result for each test case on a new line.';
  formStarterJava = `import java.util.Scanner;

public class Solution {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);
        // Write your solution here
        
    }
}`;
  formStarterPython = `import sys

def main():
    input_data = sys.stdin.read().strip()
    # Write your solution here
    print(input_data)

if __name__ == '__main__':
    main()`;

  formTestCases: TestCaseItem[] = [];

  ngOnInit(): void {
    this.loadChallenges();
  }

  loadChallenges(): void {
    this.loading = true;
    this.api.get<any[]>('/api/coding/bank').subscribe({
      next: (data) => {
        this.challenges = (data || []).map(item => ({
          id: item.id,
          title: item.title || item.codingTitle || (item.questionText?.length > 40 ? item.questionText.substring(0, 40) + '...' : item.questionText) || 'Coding Challenge',
          questionText: item.questionText || '',
          explanation: item.explanation || '',
          marks: item.marks || 10,
          difficulty: item.difficulty || item.codingDifficulty || 'EASY',
          constraints: item.constraints || item.codingConstraints || '',
          inputFormat: item.inputFormat || item.codingInputFormat || '',
          outputFormat: item.outputFormat || item.codingOutputFormat || '',
          starterJava: item.starterJava || item.codingStarterJava || '',
          starterPython: item.starterPython || item.codingStarterPython || '',
          testCases: (item.testCases || []).map((tc: any) => ({
            id: tc.id,
            input: tc.input || '',
            expectedOutput: tc.expectedOutput || '',
            isSample: !!tc.isSample,
            explanation: tc.explanation || '',
            displayOrder: tc.displayOrder || 0
          })),
          testCaseCount: item.testCaseCount ?? item.totalTestCases ?? (item.testCases ? item.testCases.length : 0)
        }));
        this.applyFilter();
        this.loading = false;
      },
      error: () => {
        this.challenges = [];
        this.filteredChallenges = [];
        this.loading = false;
      }
    });
  }

  applyFilter(): void {
    let result = [...this.challenges];
    if (this.selectedDifficulty !== 'ALL') {
      result = result.filter(c => c.difficulty === this.selectedDifficulty);
    }
    if (this.searchQuery.trim()) {
      const q = this.searchQuery.toLowerCase();
      result = result.filter(c =>
        c.title.toLowerCase().includes(q) ||
        c.questionText.toLowerCase().includes(q)
      );
    }
    this.filteredChallenges = result;
  }

  openCreateModal(): void {
    this.isEditing = false;
    this.editingId = null;
    this.modalTab = 'basic';
    this.modalError = '';

    this.formTitle = '';
    this.formQuestionText = '';
    this.formExplanation = '';
    this.formMarks = 10;
    this.formDifficulty = 'EASY';
    this.formConstraints = '1 <= N <= 10^5\nTime Limit: 5.0 seconds\nMemory Limit: 256 MB';
    this.formInputFormat = 'First line contains an integer T denoting number of test cases.';
    this.formOutputFormat = 'Print the calculated answer on a single line.';

    this.formStarterJava = `import java.util.Scanner;

public class Solution {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);
        // Write your solution here
        
    }
}`;

    this.formStarterPython = `import sys

def main():
    # Read all input from standard input
    # Write your solution here
    pass

if __name__ == '__main__':
    main()`;

    this.formTestCases = [
      {
        input: '5 7',
        expectedOutput: '12',
        isSample: true,
        explanation: '5 + 7 = 12'
      },
      {
        input: '10 -3',
        expectedOutput: '7',
        isSample: false,
        explanation: 'Hidden test case for negative integers'
      }
    ];

    this.showModal = true;
  }

  openEditModal(challenge: CodingChallengeItem): void {
    this.isEditing = true;
    this.editingId = challenge.id;
    this.modalTab = 'basic';
    this.modalError = '';

    this.formTitle = challenge.title;
    this.formQuestionText = challenge.questionText;
    this.formExplanation = challenge.explanation || '';
    this.formMarks = challenge.marks || 10;
    this.formDifficulty = challenge.difficulty || 'EASY';
    this.formConstraints = challenge.constraints || '';
    this.formInputFormat = challenge.inputFormat || '';
    this.formOutputFormat = challenge.outputFormat || '';
    this.formStarterJava = challenge.starterJava || '';
    this.formStarterPython = challenge.starterPython || '';
    this.formTestCases = (challenge.testCases || []).map(tc => ({ ...tc }));

    if (this.formTestCases.length === 0) {
      this.api.get<TestCaseItem[]>(`/api/coding/test-cases/${challenge.id}`).subscribe({
        next: (tcs) => {
          this.formTestCases = tcs || [];
        }
      });
    }

    this.showModal = true;
  }

  closeModal(): void {
    this.showModal = false;
    this.saving = false;
    this.modalError = '';
  }

  addTestCase(): void {
    this.formTestCases.push({
      input: '',
      expectedOutput: '',
      isSample: false,
      explanation: ''
    });
  }

  removeTestCase(index: number): void {
    this.formTestCases.splice(index, 1);
  }

  saveChallenge(): void {
    if (!this.formTitle.trim()) {
      this.modalError = 'Please provide a title for the question.';
      this.modalTab = 'basic';
      return;
    }
    if (!this.formQuestionText.trim()) {
      this.modalError = 'Please provide the problem statement / question text.';
      this.modalTab = 'basic';
      return;
    }
    if (this.formTestCases.length === 0) {
      this.modalError = 'Please provide at least one test case with input and expected output.';
      this.modalTab = 'testcases';
      return;
    }

    for (let i = 0; i < this.formTestCases.length; i++) {
      const tc = this.formTestCases[i];
      if (tc.expectedOutput === undefined || tc.expectedOutput === null) {
        this.modalError = `Test Case #${i + 1} must have an expected output.`;
        this.modalTab = 'testcases';
        return;
      }
    }

    this.saving = true;
    this.modalError = '';

    const payload = {
      id: this.editingId,
      title: this.formTitle.trim(),
      codingTitle: this.formTitle.trim(),
      questionText: this.formQuestionText.trim(),
      explanation: this.formExplanation.trim() || null,
      marks: this.formMarks || 10,
      difficulty: this.formDifficulty,
      codingDifficulty: this.formDifficulty,
      constraints: this.formConstraints.trim() || null,
      codingConstraints: this.formConstraints.trim() || null,
      inputFormat: this.formInputFormat.trim() || null,
      codingInputFormat: this.formInputFormat.trim() || null,
      outputFormat: this.formOutputFormat.trim() || null,
      codingOutputFormat: this.formOutputFormat.trim() || null,
      starterJava: this.formStarterJava || null,
      codingStarterJava: this.formStarterJava || null,
      starterPython: this.formStarterPython || null,
      codingStarterPython: this.formStarterPython || null,
      testCases: this.formTestCases.map((tc, index) => ({
        id: tc.id,
        input: tc.input || '',
        expectedOutput: tc.expectedOutput || '',
        isSample: !!tc.isSample,
        explanation: tc.explanation || null,
        displayOrder: index + 1
      }))
    };

    this.api.post<any>('/api/coding/bank', payload).subscribe({
      next: () => {
        this.saving = false;
        this.showModal = false;
        this.loadChallenges();
      },
      error: (err) => {
        this.saving = false;
        this.modalError = err?.error?.message || 'Failed to save coding question. Please try again.';
      }
    });
  }

  openInEditor(id: number): void {
    window.open(`/code-editor/${id}`, '_blank');
  }

  async deleteChallenge(c: CodingChallengeItem): Promise<void> {
    const ok = await this.confirm.confirm(`Delete "${c.title}"? This cannot be undone.`);
    if (!ok) return;

    this.api.delete(`/api/coding/bank/${c.id}`).subscribe({
      next: () => this.loadChallenges(),
      error: () => this.loadChallenges()
    });
  }
}
