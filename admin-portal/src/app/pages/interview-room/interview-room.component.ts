import {
  Component,
  OnInit,
  OnDestroy,
  ElementRef,
  ViewChild,
  inject,
  HostListener
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { HttpClient } from '@angular/common/http';
import { environment } from '../../../environments/environment';

interface ChatMessage {
  id?: string;
  sender: string;
  senderRole: string;
  message: string;
  timestamp: number;
}

interface TestCaseResult {
  testCaseNumber: number;
  passed: boolean;
  input: string;
  expectedOutput: string;
  actualOutput: string;
  errorOutput?: string;
  executionTimeMs: number;
  status: string;
}

interface RunResult {
  success: boolean;
  verdict: string;
  results?: TestCaseResult[];
  error?: string;
}

@Component({
  selector: 'app-interview-room',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="meet-container" [class.layout-split]="activeTab !== 'none'">
      <!-- TOP NAVIGATION BAR (Google Meet Style) -->
      <header class="meet-header">
        <div class="header-left">
          <div class="brand-pill">
            <span class="live-dot" [class.active]="roomStatus === 'LIVE'"></span>
            <span class="brand-text">1-ON-1 INTERVIEW</span>
          </div>

          <div class="meeting-details">
            <h1 class="room-title">{{ roomTitle || 'Technical Interview Session' }}</h1>
            <div class="meta-row">
              <span class="room-code-badge" (click)="copyRoomLink()" title="Click to copy meeting link">
                <span class="code-text">{{ roomCode }}</span>
                <span class="copy-icon">📋</span>
              </span>
              <span class="timer-badge">
                ⏱ {{ formatDuration(callSeconds) }}
              </span>
              <span class="company-badge" *ngIf="companyName">
                🏢 {{ companyName }} <span *ngIf="driveRole">({{ driveRole }})</span>
              </span>
            </div>
          </div>
        </div>

        <div class="header-center" *ngIf="candidateName">
          <div class="candidate-summary-chip">
            <div class="cand-avatar">{{ candidateInitials }}</div>
            <div class="cand-info">
              <div class="cand-name-row">
                <span class="cand-name">{{ candidateName }}</span>
                <span class="role-badge">Candidate</span>
              </div>
              <div class="cand-meta">
                <span class="cand-email" *ngIf="candidateEmail">✉ {{ candidateEmail }}</span>
                <span class="cand-batch" *ngIf="candidateBatch">👥 {{ candidateBatch }}</span>
                <span class="cand-phone" *ngIf="candidatePhone">📞 {{ candidatePhone }}</span>
              </div>
            </div>
          </div>
        </div>

        <div class="header-right">
          <!-- Participants Online Status Indicators -->
          <div class="presence-badges">
            <div class="presence-tag" [class.online]="interviewerOnline">
              <span class="dot"></span>
              <span>Interviewer: {{ interviewerName || 'Mentor' }}</span>
            </div>
            <div class="presence-tag" [class.online]="candidateOnline">
              <span class="dot"></span>
              <span>Candidate: {{ candidateName || 'Student' }}</span>
            </div>
          </div>

          <!-- Quick Layout / Drawer Toggles -->
          <div class="drawer-toggles">
            <button
              class="top-icon-btn"
              [class.active]="activeTab === 'code'"
              (click)="toggleTab('code')"
              title="Collaborative Code Editor"
            >
              💻 Code
            </button>
            <button
              class="top-icon-btn"
              [class.active]="activeTab === 'problem'"
              (click)="toggleTab('problem')"
              title="Problem Description"
            >
              📝 Problem
            </button>
            <button
              class="top-icon-btn"
              [class.active]="activeTab === 'rubric'"
              (click)="toggleTab('rubric')"
              title="Evaluation Rubric"
            >
              ⭐ Rubric
            </button>
            <button
              class="top-icon-btn"
              [class.active]="activeTab === 'chat'"
              (click)="toggleTab('chat')"
              title="Meeting Chat"
            >
              💬 Chat <span class="badge-count" *ngIf="unreadChatCount > 0">{{ unreadChatCount }}</span>
            </button>
          </div>
        </div>
      </header>

      <!-- MAIN STAGE: VIDEO GRID + WORKBENCH -->
      <main class="meet-main">
        <!-- VIDEO AREA (Google Meet Adaptive Tiles) -->
        <section class="video-stage" [class.compressed]="activeTab !== 'none'">
          <div class="video-grid" [class.single-peer]="!remoteStreamActive && !screenShareActive">
            <!-- REMOTE PARTICIPANT (Candidate or Interviewer) -->
            <div class="video-tile remote-tile" [class.speaking]="remoteSpeaking">
              <video
                #remoteVideo
                class="video-element"
                autoplay
                playsinline
                [style.display]="remoteStreamActive ? 'block' : 'none'"
              ></video>

              <!-- Placeholder Avatar when remote video is inactive/disabled -->
              <div class="tile-placeholder" *ngIf="!remoteStreamActive">
                <div class="pulse-ring" *ngIf="remoteSpeaking"></div>
                <div class="large-avatar">
                  {{ remoteInitials }}
                </div>
                <div class="waiting-label">
                  {{ candidateOnline ? (role === 'interviewer' ? candidateName : interviewerName) : 'Waiting for participant to join...' }}
                </div>
              </div>

              <!-- Stream Info Overlay -->
              <div class="tile-bar">
                <div class="tile-name">
                  <span>{{ role === 'interviewer' ? (candidateName || 'Candidate') : (interviewerName || 'Interviewer') }}</span>
                  <span class="audio-indicator" [class.muted]="remoteAudioMuted">
                    {{ remoteAudioMuted ? '🔇' : '🎙️' }}
                  </span>
                </div>
                <div class="tile-network-badge" [class.online]="candidateOnline">
                  {{ candidateOnline ? 'HD' : 'Connecting' }}
                </div>
              </div>
            </div>

            <!-- LOCAL PARTICIPANT (You) -->
            <div class="video-tile local-tile" [class.speaking]="localSpeaking" [class.pip]="activeTab === 'none' && remoteStreamActive">
              <video
                #localVideo
                class="video-element mirror"
                autoplay
                playsinline
                muted
                [style.display]="cameraEnabled && localStreamActive ? 'block' : 'none'"
              ></video>

              <!-- Local Avatar when camera is turned off -->
              <div class="tile-placeholder" *ngIf="!cameraEnabled || !localStreamActive">
                <div class="pulse-ring" *ngIf="localSpeaking"></div>
                <div class="large-avatar local-avatar">
                  {{ myInitials }}
                </div>
                <div class="waiting-label">You (Camera off)</div>
              </div>

              <!-- Local Info Overlay -->
              <div class="tile-bar">
                <div class="tile-name">
                  <span>You ({{ role === 'interviewer' ? 'Interviewer' : 'Candidate' }})</span>
                  <span class="audio-indicator" [class.muted]="!micEnabled">
                    {{ micEnabled ? '🎙️' : '🔇' }}
                  </span>
                </div>
              </div>
            </div>

            <!-- SCREEN SHARE TILE (If Screen Sharing is active) -->
            <div class="video-tile screen-tile" *ngIf="screenShareActive">
              <video
                #screenVideo
                class="video-element"
                autoplay
                playsinline
              ></video>
              <div class="tile-bar">
                <div class="tile-name">
                  <span>🖥️ Screen Share (You)</span>
                </div>
              </div>
            </div>
          </div>
        </section>

        <!-- WORKBENCH DRAWER (Google Meet Right Side Panel) -->
        <aside class="workbench-drawer" *ngIf="activeTab !== 'none'">
          <div class="drawer-header">
            <div class="drawer-nav">
              <button
                class="tab-btn"
                [class.active]="activeTab === 'code'"
                (click)="activeTab = 'code'"
              >
                💻 Live Code
              </button>
              <button
                class="tab-btn"
                [class.active]="activeTab === 'problem'"
                (click)="activeTab = 'problem'"
              >
                📝 Problem
              </button>
              <button
                class="tab-btn"
                [class.active]="activeTab === 'rubric'"
                (click)="activeTab = 'rubric'"
              >
                ⭐ Rubric
              </button>
              <button
                class="tab-btn"
                [class.active]="activeTab === 'chat'"
                (click)="activeTab = 'chat'; unreadChatCount = 0"
              >
                💬 Chat
              </button>
            </div>
            <button class="btn-close-drawer" (click)="activeTab = 'none'" title="Close panel">✕</button>
          </div>

          <!-- TAB 1: LIVE COLLABORATIVE CODE EDITOR -->
          <div class="drawer-content code-tab" *ngIf="activeTab === 'code'">
            <div class="code-toolbar">
              <div class="toolbar-left">
                <label>Language:</label>
                <select class="lang-select" [(ngModel)]="codeLanguage" (change)="onLanguageChange()">
                  <option value="java">Java 21</option>
                  <option value="python">Python 3.11</option>
                  <option value="javascript">JavaScript (Node)</option>
                  <option value="cpp">C++ 20</option>
                </select>
                <span class="sync-badge" [class.synced]="isCodeSynced">
                  {{ isCodeSynced ? '● Synced' : '○ Syncing...' }}
                </span>
              </div>
              <div class="toolbar-right">
                <button class="btn-reset" (click)="resetStarterCode()" title="Reset to initial problem template">
                  ↺ Reset
                </button>
                <button class="btn-run" [disabled]="isRunningCode" (click)="runLiveCode()">
                  <span *ngIf="!isRunningCode">▶ Run Code</span>
                  <span *ngIf="isRunningCode">⏳ Running...</span>
                </button>
              </div>
            </div>

            <div class="editor-container">
              <textarea
                class="code-textarea"
                [(ngModel)]="currentCode"
                (ngModelChange)="onCodeChanged($event)"
                placeholder="Write code here in real-time..."
                spellcheck="false"
              ></textarea>
            </div>

            <!-- Terminal Output Section -->
            <div class="terminal-panel">
              <div class="terminal-header">
                <span class="term-title">Execution Console</span>
                <span
                  class="verdict-tag"
                  *ngIf="runResult"
                  [ngClass]="runResult.verdict === 'PASSED' || runResult.success ? 'passed' : 'failed'"
                >
                  {{ runResult.verdict || (runResult.success ? 'SUCCESS' : 'ERROR') }}
                </span>
              </div>
              <div class="terminal-body">
                <div *ngIf="!runResult && !isRunningCode" class="term-placeholder">
                  Press "Run Code" to compile and execute candidate solution.
                </div>
                <div *ngIf="isRunningCode" class="term-running">
                  <div class="spinner"></div> Executing solution in sandbox...
                </div>
                <div *ngIf="runResult" class="term-output">
                  <div *ngIf="runResult.error" class="term-error">
                    {{ runResult.error }}
                  </div>
                  <div *ngIf="runResult.results && runResult.results.length > 0">
                    <div
                      class="test-case-item"
                      *ngFor="let tc of runResult.results"
                      [class.passed]="tc.passed"
                      [class.failed]="!tc.passed"
                    >
                      <div class="tc-header">
                        <span>Case #{{ tc.testCaseNumber }}</span>
                        <span class="tc-status">{{ tc.passed ? 'PASSED' : 'FAILED' }} ({{ tc.executionTimeMs }}ms)</span>
                      </div>
                      <div class="tc-details">
                        <div><strong>Input:</strong> {{ tc.input }}</div>
                        <div><strong>Expected:</strong> {{ tc.expectedOutput }}</div>
                        <div><strong>Actual:</strong> {{ tc.actualOutput }}</div>
                        <div *ngIf="tc.errorOutput" class="tc-err"><strong>Error:</strong> {{ tc.errorOutput }}</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- TAB 2: PROBLEM PROMPT -->
          <div class="drawer-content problem-tab" *ngIf="activeTab === 'problem'">
            <div class="problem-card">
              <div class="problem-top">
                <h2 class="problem-title">{{ problemTitle || 'Interview Challenge' }}</h2>
                <span class="diff-badge" [ngClass]="(problemDifficulty || 'Medium').toLowerCase()">
                  {{ problemDifficulty || 'Medium' }}
                </span>
              </div>

              <div class="problem-body">
                <div class="problem-section">
                  <h3>Description</h3>
                  <div class="problem-desc-text">
                    {{ problemDescription || 'Discuss the algorithmic approach with the candidate and code the optimal solution.' }}
                  </div>
                </div>

                <div class="problem-section" *ngIf="problemConstraints">
                  <h3>Constraints</h3>
                  <pre class="pre-constraints">{{ problemConstraints }}</pre>
                </div>

                <div class="problem-section" *ngIf="sampleInput">
                  <h3>Sample Test Case</h3>
                  <div class="sample-box">
                    <div class="sample-label">Input:</div>
                    <pre class="sample-pre">{{ sampleInput }}</pre>
                    <div class="sample-label">Expected Output:</div>
                    <pre class="sample-pre">{{ sampleOutput }}</pre>
                  </div>
                </div>
              </div>

              <div class="problem-footer" *ngIf="availableProblems.length > 1">
                <label>Change Problem:</label>
                <select class="problem-select" (change)="selectProblem($event)">
                  <option *ngFor="let p of availableProblems; let idx = index" [value]="idx">
                    {{ p.title }} ({{ p.difficulty }})
                  </option>
                </select>
              </div>
            </div>
          </div>

          <!-- TAB 3: EVALUATION & RUBRIC -->
          <div class="drawer-content rubric-tab" *ngIf="activeTab === 'rubric'">
            <div class="rubric-form">
              <div class="rubric-heading">
                <h2>Interviewer Rubric & Decision</h2>
                <p>Submit live scores and recommendations. Feedback syncs in real-time with placement records.</p>
              </div>

              <!-- Score 1: Problem Solving -->
              <div class="score-group">
                <div class="score-label-row">
                  <span class="score-title">1. Problem Solving & Algorithms</span>
                  <span class="score-val">{{ rubric.problemSolvingScore }}/5</span>
                </div>
                <input
                  type="range"
                  min="1"
                  max="5"
                  step="1"
                  [(ngModel)]="rubric.problemSolvingScore"
                  class="score-slider"
                />
                <div class="score-ticks">
                  <span>1 (Poor)</span>
                  <span>3 (Competent)</span>
                  <span>5 (Mastery)</span>
                </div>
              </div>

              <!-- Score 2: Technical Competency -->
              <div class="score-group">
                <div class="score-label-row">
                  <span class="score-title">2. Technical Competency & Syntax</span>
                  <span class="score-val">{{ rubric.technicalCompetencyScore }}/5</span>
                </div>
                <input
                  type="range"
                  min="1"
                  max="5"
                  step="1"
                  [(ngModel)]="rubric.technicalCompetencyScore"
                  class="score-slider"
                />
                <div class="score-ticks">
                  <span>1 (Weak)</span>
                  <span>3 (Proficient)</span>
                  <span>5 (Expert)</span>
                </div>
              </div>

              <!-- Score 3: Code Quality -->
              <div class="score-group">
                <div class="score-label-row">
                  <span class="score-title">3. Code Quality, Modularity & Edge Cases</span>
                  <span class="score-val">{{ rubric.codeQualityScore }}/5</span>
                </div>
                <input
                  type="range"
                  min="1"
                  max="5"
                  step="1"
                  [(ngModel)]="rubric.codeQualityScore"
                  class="score-slider"
                />
                <div class="score-ticks">
                  <span>1 (Messy)</span>
                  <span>3 (Clean)</span>
                  <span>5 (Production Grade)</span>
                </div>
              </div>

              <!-- Score 4: Communication -->
              <div class="score-group">
                <div class="score-label-row">
                  <span class="score-title">4. Communication & Thought Process</span>
                  <span class="score-val">{{ rubric.communicationScore }}/5</span>
                </div>
                <input
                  type="range"
                  min="1"
                  max="5"
                  step="1"
                  [(ngModel)]="rubric.communicationScore"
                  class="score-slider"
                />
                <div class="score-ticks">
                  <span>1 (Silent)</span>
                  <span>3 (Clear)</span>
                  <span>5 (Articulate)</span>
                </div>
              </div>

              <!-- Overall Recommendation -->
              <div class="form-group decision-group">
                <label class="form-label">Hiring Recommendation</label>
                <select class="decision-select" [(ngModel)]="rubric.hiringDecision">
                  <option value="STRONG_HIRE">🌟 Strong Hire</option>
                  <option value="HIRE">✅ Hire</option>
                  <option value="LEAN_HIRE">👍 Lean Hire</option>
                  <option value="LEAN_NO_HIRE">👎 Lean No Hire</option>
                  <option value="STRONG_NO_HIRE">❌ Strong Reject</option>
                </select>
              </div>

              <!-- Interviewer Notes -->
              <div class="form-group notes-group">
                <label class="form-label">Private Interviewer Notes & Constructive Feedback</label>
                <textarea
                  class="notes-textarea"
                  rows="4"
                  [(ngModel)]="rubric.interviewerNotes"
                  placeholder="Summarize candidate's technical strengths, problem-solving speed, areas to improve..."
                ></textarea>
              </div>

              <!-- Action Buttons -->
              <div class="rubric-actions">
                <button
                  class="btn-save-eval"
                  [disabled]="isSubmittingEvaluation"
                  (click)="submitEvaluation(false)"
                >
                  💾 Save Draft
                </button>
                <button
                  class="btn-finalize-eval"
                  [disabled]="isSubmittingEvaluation"
                  (click)="submitEvaluation(true)"
                >
                  🏁 Finalize & Complete Round
                </button>
              </div>

              <div *ngIf="evaluationStatusMessage" class="eval-message" [class.success]="evalSuccess">
                {{ evaluationStatusMessage }}
              </div>
            </div>
          </div>

          <!-- TAB 4: LIVE CHAT -->
          <div class="drawer-content chat-tab" *ngIf="activeTab === 'chat'">
            <div class="chat-messages" #chatScrollContainer>
              <div *ngIf="chatMessages.length === 0" class="no-messages">
                No messages yet. Send a message to the candidate or interviewer!
              </div>
              <div
                class="chat-bubble-row"
                *ngFor="let msg of chatMessages"
                [class.own-msg]="msg.senderRole === role"
              >
                <div class="chat-bubble">
                  <div class="chat-sender">
                    {{ msg.sender }} ({{ msg.senderRole }})
                    <span class="chat-time">{{ formatTime(msg.timestamp) }}</span>
                  </div>
                  <div class="chat-text">{{ msg.message }}</div>
                </div>
              </div>
            </div>

            <div class="chat-input-bar">
              <input
                type="text"
                class="chat-input"
                [(ngModel)]="newChatMessage"
                (keyup.enter)="sendChatMessage()"
                placeholder="Type a message to participants..."
              />
              <button class="btn-send-chat" (click)="sendChatMessage()">
                ➤
              </button>
            </div>
          </div>
        </aside>
      </main>

      <!-- BOTTOM CONTROL BAR (Google Meet Signature Control Dock) -->
      <footer class="meet-footer">
        <div class="footer-left">
          <div class="room-info-pill">
            <span class="lock-icon">🔒</span>
            <span class="room-pill-code">{{ roomCode }}</span>
            <button class="btn-copy-chip" (click)="copyRoomLink()" title="Copy Meeting URL">
              📋
            </button>
          </div>
        </div>

        <div class="footer-center">
          <!-- Audio Mic Toggle -->
          <button
            class="control-btn"
            [class.off]="!micEnabled"
            (click)="toggleMicrophone()"
            [title]="micEnabled ? 'Mute microphone' : 'Unmute microphone'"
          >
            <span class="icon">{{ micEnabled ? '🎙️' : '🔇' }}</span>
          </button>

          <!-- Video Camera Toggle -->
          <button
            class="control-btn"
            [class.off]="!cameraEnabled"
            (click)="toggleCamera()"
            [title]="cameraEnabled ? 'Turn camera off' : 'Turn camera on'"
          >
            <span class="icon">{{ cameraEnabled ? '📹' : '🚫' }}</span>
          </button>

          <!-- Screen Share Toggle -->
          <button
            class="control-btn"
            [class.active-screen]="screenShareActive"
            (click)="toggleScreenShare()"
            [title]="screenShareActive ? 'Stop sharing screen' : 'Share entire screen'"
          >
            <span class="icon">🖥️</span>
          </button>

          <!-- End Call / Leave Room Button -->
          <button
            class="control-btn end-call-btn"
            (click)="leaveRoom()"
            title="Leave call"
          >
            <span class="icon">📞</span>
          </button>
        </div>

        <div class="footer-right">
          <button
            class="dock-action-btn"
            [class.active]="activeTab === 'code'"
            (click)="toggleTab('code')"
            title="Open Collaborative Code Editor"
          >
            💻 Code
          </button>
          <button
            class="dock-action-btn"
            [class.active]="activeTab === 'problem'"
            (click)="toggleTab('problem')"
            title="View Problem Details"
          >
            📝 Problem
          </button>
          <button
            class="dock-action-btn"
            [class.active]="activeTab === 'rubric'"
            (click)="toggleTab('rubric')"
            title="Open Rubric Evaluation"
          >
            ⭐ Rubric
          </button>
          <button
            class="dock-action-btn"
            [class.active]="activeTab === 'chat'"
            (click)="toggleTab('chat')"
            title="Open In-Call Chat"
          >
            💬 Chat
            <span class="chat-unread-dot" *ngIf="unreadChatCount > 0"></span>
          </button>
        </div>
      </footer>
    </div>
  `,
  styles: [`
    :host {
      display: block;
      width: 100vw;
      height: 100vh;
      overflow: hidden;
      background-color: #131314;
      color: #e3e3e3;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
    }

    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }

    .meet-container {
      display: flex;
      flex-direction: column;
      width: 100%;
      height: 100%;
      background: radial-gradient(circle at 50% 20%, #1e1f20 0%, #131314 100%);
    }

    /* TOP HEADER */
    .meet-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      height: 64px;
      padding: 0 20px;
      background-color: rgba(30, 31, 32, 0.85);
      backdrop-filter: blur(12px);
      border-bottom: 1px solid #2f3133;
      z-index: 10;
    }

    .header-left {
      display: flex;
      align-items: center;
      gap: 14px;
    }

    .brand-pill {
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 6px 12px;
      background: #25272a;
      border: 1px solid #3c4043;
      border-radius: 20px;
    }

    .live-dot {
      width: 10px;
      height: 10px;
      border-radius: 50%;
      background-color: #80868b;
    }

    .live-dot.active {
      background-color: #34a853;
      box-shadow: 0 0 10px #34a853;
      animation: pulse-dot 1.8s infinite;
    }

    @keyframes pulse-dot {
      0%, 100% { opacity: 1; transform: scale(1); }
      50% { opacity: 0.6; transform: scale(1.2); }
    }

    .brand-text {
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 0.8px;
      color: #9aa0a6;
    }

    .meeting-details {
      display: flex;
      flex-direction: column;
      gap: 2px;
    }

    .room-title {
      font-size: 15px;
      font-weight: 600;
      color: #f1f3f4;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      max-width: 280px;
    }

    .meta-row {
      display: flex;
      align-items: center;
      gap: 10px;
    }

    .room-code-badge {
      display: inline-flex;
      align-items: center;
      gap: 5px;
      font-size: 12px;
      font-family: monospace;
      color: #8ab4f8;
      cursor: pointer;
      background: rgba(138, 180, 248, 0.12);
      padding: 2px 8px;
      border-radius: 6px;
      transition: background 0.2s;
    }

    .room-code-badge:hover {
      background: rgba(138, 180, 248, 0.25);
    }

    .timer-badge {
      font-size: 12px;
      color: #9aa0a6;
      font-variant-numeric: tabular-nums;
    }

    .company-badge {
      font-size: 11px;
      color: #fbbc04;
      background: rgba(251, 188, 4, 0.12);
      padding: 2px 8px;
      border-radius: 6px;
    }

    /* HEADER CENTER (Candidate Profile Card) */
    .header-center {
      display: flex;
      align-items: center;
    }

    .candidate-summary-chip {
      display: flex;
      align-items: center;
      gap: 10px;
      background: #25272a;
      border: 1px solid #3c4043;
      padding: 6px 14px;
      border-radius: 24px;
    }

    .cand-avatar {
      width: 32px;
      height: 32px;
      border-radius: 50%;
      background: linear-gradient(135deg, #1a73e8, #8ab4f8);
      color: #ffffff;
      font-weight: 700;
      font-size: 13px;
      display: flex;
      align-items: center;
      justify-content: center;
    }

    .cand-info {
      display: flex;
      flex-direction: column;
    }

    .cand-name-row {
      display: flex;
      align-items: center;
      gap: 6px;
    }

    .cand-name {
      font-size: 13px;
      font-weight: 600;
      color: #ffffff;
    }

    .role-badge {
      font-size: 10px;
      background: #1e8e3e;
      color: white;
      padding: 1px 6px;
      border-radius: 10px;
      text-transform: uppercase;
      font-weight: 700;
    }

    .cand-meta {
      display: flex;
      gap: 8px;
      font-size: 11px;
      color: #9aa0a6;
    }

    /* HEADER RIGHT */
    .header-right {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .presence-badges {
      display: flex;
      gap: 8px;
    }

    .presence-tag {
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 11px;
      padding: 4px 8px;
      border-radius: 12px;
      background: #202124;
      border: 1px solid #3c4043;
      color: #80868b;
    }

    .presence-tag .dot {
      width: 7px;
      height: 7px;
      border-radius: 50%;
      background-color: #80868b;
    }

    .presence-tag.online {
      color: #e8eaed;
      border-color: #34a853;
    }

    .presence-tag.online .dot {
      background-color: #34a853;
      box-shadow: 0 0 6px #34a853;
    }

    .drawer-toggles {
      display: flex;
      gap: 6px;
    }

    .top-icon-btn {
      background: #25272a;
      border: 1px solid #3c4043;
      color: #e3e3e3;
      padding: 6px 12px;
      border-radius: 8px;
      font-size: 12px;
      font-weight: 500;
      cursor: pointer;
      position: relative;
      transition: all 0.2s;
    }

    .top-icon-btn:hover {
      background: #303134;
      border-color: #5f6368;
    }

    .top-icon-btn.active {
      background: #8ab4f8;
      color: #202124;
      border-color: #8ab4f8;
      font-weight: 600;
    }

    .badge-count {
      position: absolute;
      top: -4px;
      right: -4px;
      background: #ea4335;
      color: white;
      font-size: 10px;
      border-radius: 10px;
      padding: 1px 5px;
      font-weight: bold;
    }

    /* MAIN STAGE */
    .meet-main {
      flex: 1;
      display: flex;
      position: relative;
      overflow: hidden;
      padding: 12px;
      gap: 12px;
    }

    /* VIDEO STAGE */
    .video-stage {
      flex: 1;
      display: flex;
      flex-direction: column;
      height: 100%;
      transition: all 0.3s ease;
      position: relative;
    }

    .video-grid {
      flex: 1;
      display: grid;
      grid-template-columns: 1fr;
      grid-template-rows: 1fr;
      gap: 12px;
      height: 100%;
      width: 100%;
    }

    /* Adaptive Grid: When split view is open or multiple video tiles */
    .video-tile {
      position: relative;
      background: #1e1f20;
      border: 2px solid transparent;
      border-radius: 16px;
      overflow: hidden;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: border-color 0.2s ease, transform 0.2s ease;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.4);
    }

    .video-tile.speaking {
      border-color: #34a853;
      box-shadow: 0 0 16px rgba(52, 168, 83, 0.4);
    }

    .video-element {
      width: 100%;
      height: 100%;
      object-fit: cover;
      background-color: #000000;
    }

    .video-element.mirror {
      transform: scaleX(-1);
    }

    /* Google Meet Local Picture-in-Picture floating */
    .video-tile.local-tile.pip {
      position: absolute;
      bottom: 16px;
      right: 16px;
      width: 220px;
      height: 140px;
      z-index: 5;
      border: 1px solid #3c4043;
      box-shadow: 0 8px 24px rgba(0, 0, 0, 0.6);
    }

    /* Video Tile Placeholder */
    .tile-placeholder {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      gap: 14px;
      position: relative;
      width: 100%;
      height: 100%;
      background: radial-gradient(circle, #28292a 0%, #1e1f20 100%);
    }

    .large-avatar {
      width: 90px;
      height: 90px;
      border-radius: 50%;
      background: linear-gradient(135deg, #4285f4, #1a73e8);
      color: white;
      font-size: 32px;
      font-weight: 700;
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 2;
      box-shadow: 0 4px 12px rgba(0,0,0,0.3);
    }

    .large-avatar.local-avatar {
      background: linear-gradient(135deg, #34a853, #1e8e3e);
    }

    .pulse-ring {
      position: absolute;
      width: 110px;
      height: 110px;
      border-radius: 50%;
      border: 3px solid #34a853;
      animation: ripple 1.4s infinite ease-out;
      z-index: 1;
    }

    @keyframes ripple {
      0% { transform: scale(0.9); opacity: 1; }
      100% { transform: scale(1.4); opacity: 0; }
    }

    .waiting-label {
      font-size: 13px;
      color: #9aa0a6;
      font-weight: 500;
    }

    /* Tile Bar (Name & Mic Overlay) */
    .tile-bar {
      position: absolute;
      bottom: 12px;
      left: 14px;
      right: 14px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      pointer-events: none;
      z-index: 3;
    }

    .tile-name {
      display: flex;
      align-items: center;
      gap: 6px;
      background: rgba(0, 0, 0, 0.65);
      backdrop-filter: blur(8px);
      padding: 4px 10px;
      border-radius: 20px;
      font-size: 12px;
      font-weight: 500;
      color: #f1f3f4;
    }

    .audio-indicator.muted {
      color: #ea4335;
    }

    .tile-network-badge {
      font-size: 11px;
      background: rgba(0, 0, 0, 0.65);
      padding: 4px 8px;
      border-radius: 6px;
      color: #9aa0a6;
    }

    .tile-network-badge.online {
      color: #34a853;
      font-weight: 600;
    }

    /* WORKBENCH DRAWER (Google Meet Right Pane) */
    .workbench-drawer {
      width: 580px;
      height: 100%;
      background: #1e1f20;
      border: 1px solid #2f3133;
      border-radius: 16px;
      display: flex;
      flex-direction: column;
      overflow: hidden;
      box-shadow: -4px 0 24px rgba(0, 0, 0, 0.5);
      animation: slideInRight 0.25s ease-out;
    }

    @keyframes slideInRight {
      from { transform: translateX(20px); opacity: 0; }
      to { transform: translateX(0); opacity: 1; }
    }

    .drawer-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 10px 16px;
      background: #25272a;
      border-bottom: 1px solid #2f3133;
    }

    .drawer-nav {
      display: flex;
      gap: 6px;
    }

    .tab-btn {
      background: transparent;
      border: none;
      color: #9aa0a6;
      font-size: 13px;
      font-weight: 600;
      padding: 6px 12px;
      border-radius: 6px;
      cursor: pointer;
      transition: all 0.15s;
    }

    .tab-btn:hover {
      color: #e3e3e3;
      background: rgba(255, 255, 255, 0.05);
    }

    .tab-btn.active {
      color: #8ab4f8;
      background: rgba(138, 180, 248, 0.12);
    }

    .btn-close-drawer {
      background: transparent;
      border: none;
      color: #9aa0a6;
      font-size: 16px;
      cursor: pointer;
      padding: 4px 8px;
      border-radius: 4px;
    }

    .btn-close-drawer:hover {
      background: rgba(255, 255, 255, 0.1);
      color: white;
    }

    .drawer-content {
      flex: 1;
      display: flex;
      flex-direction: column;
      overflow-y: auto;
      padding: 14px;
      gap: 12px;
    }

    /* CODE TAB */
    .code-tab {
      padding: 0;
      gap: 0;
    }

    .code-toolbar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 8px 14px;
      background: #282a2d;
      border-bottom: 1px solid #3c4043;
    }

    .toolbar-left, .toolbar-right {
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .toolbar-left label {
      font-size: 12px;
      color: #9aa0a6;
    }

    .lang-select {
      background: #1e1f20;
      color: #e3e3e3;
      border: 1px solid #3c4043;
      padding: 4px 8px;
      border-radius: 6px;
      font-size: 12px;
      cursor: pointer;
    }

    .sync-badge {
      font-size: 11px;
      color: #fbbc04;
    }

    .sync-badge.synced {
      color: #34a853;
    }

    .btn-reset {
      background: #303134;
      border: 1px solid #3c4043;
      color: #e3e3e3;
      padding: 5px 10px;
      border-radius: 6px;
      font-size: 12px;
      cursor: pointer;
    }

    .btn-run {
      background: #34a853;
      border: none;
      color: white;
      font-weight: 600;
      padding: 6px 14px;
      border-radius: 6px;
      font-size: 12px;
      cursor: pointer;
      transition: background 0.2s;
    }

    .btn-run:hover:not(:disabled) {
      background: #2d9247;
    }

    .btn-run:disabled {
      opacity: 0.6;
      cursor: not-allowed;
    }

    .editor-container {
      flex: 1;
      min-height: 240px;
      background: #18191a;
      position: relative;
    }

    .code-textarea {
      width: 100%;
      height: 100%;
      background: transparent;
      color: #a9b7c6;
      font-family: 'Consolas', 'Fira Code', 'Monaco', monospace;
      font-size: 13px;
      line-height: 1.5;
      padding: 12px;
      border: none;
      resize: none;
      outline: none;
      tab-size: 4;
      white-space: pre;
    }

    /* Terminal Console */
    .terminal-panel {
      height: 180px;
      background: #141517;
      border-top: 1px solid #2f3133;
      display: flex;
      flex-direction: column;
    }

    .terminal-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 6px 12px;
      background: #1c1d1f;
      border-bottom: 1px solid #282a2d;
    }

    .term-title {
      font-size: 11px;
      font-weight: 700;
      color: #80868b;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }

    .verdict-tag {
      font-size: 11px;
      font-weight: 700;
      padding: 2px 8px;
      border-radius: 4px;
    }

    .verdict-tag.passed {
      background: rgba(52, 168, 83, 0.2);
      color: #34a853;
    }

    .verdict-tag.failed {
      background: rgba(234, 67, 53, 0.2);
      color: #ea4335;
    }

    .terminal-body {
      flex: 1;
      overflow-y: auto;
      padding: 10px 14px;
      font-family: monospace;
      font-size: 12px;
    }

    .term-placeholder {
      color: #5f6368;
      font-style: italic;
    }

    .term-error {
      color: #f28b82;
      white-space: pre-wrap;
    }

    .test-case-item {
      padding: 6px 10px;
      background: #1e1f20;
      border-left: 3px solid #5f6368;
      border-radius: 4px;
      margin-bottom: 8px;
    }

    .test-case-item.passed {
      border-left-color: #34a853;
    }

    .test-case-item.failed {
      border-left-color: #ea4335;
    }

    .tc-header {
      display: flex;
      justify-content: space-between;
      font-weight: 600;
      margin-bottom: 4px;
    }

    .tc-details {
      color: #9aa0a6;
      line-height: 1.4;
    }

    /* PROBLEM TAB */
    .problem-card {
      background: #25272a;
      border: 1px solid #3c4043;
      border-radius: 12px;
      padding: 16px;
      display: flex;
      flex-direction: column;
      gap: 14px;
    }

    .problem-top {
      display: flex;
      justify-content: space-between;
      align-items: center;
    }

    .problem-title {
      font-size: 18px;
      font-weight: 600;
      color: #ffffff;
    }

    .diff-badge {
      font-size: 11px;
      font-weight: 700;
      padding: 3px 10px;
      border-radius: 12px;
      text-transform: uppercase;
    }

    .diff-badge.easy { background: rgba(52, 168, 83, 0.2); color: #34a853; }
    .diff-badge.medium { background: rgba(251, 188, 4, 0.2); color: #fbbc04; }
    .diff-badge.hard { background: rgba(234, 67, 53, 0.2); color: #ea4335; }

    .problem-section h3 {
      font-size: 13px;
      font-weight: 700;
      color: #8ab4f8;
      margin-bottom: 6px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }

    .problem-desc-text {
      font-size: 13px;
      line-height: 1.6;
      color: #e3e3e3;
      white-space: pre-line;
    }

    .pre-constraints {
      background: #18191a;
      padding: 10px;
      border-radius: 6px;
      font-size: 12px;
      color: #fbbc04;
      font-family: monospace;
    }

    .sample-box {
      background: #18191a;
      padding: 10px;
      border-radius: 6px;
      font-family: monospace;
      font-size: 12px;
    }

    .sample-label {
      color: #80868b;
      margin-top: 4px;
    }

    .sample-pre {
      color: #e3e3e3;
      margin-bottom: 6px;
    }

    .problem-footer {
      display: flex;
      align-items: center;
      gap: 10px;
      margin-top: 8px;
      padding-top: 10px;
      border-top: 1px solid #3c4043;
    }

    .problem-select {
      flex: 1;
      background: #18191a;
      color: white;
      border: 1px solid #3c4043;
      padding: 6px 10px;
      border-radius: 6px;
    }

    /* RUBRIC TAB */
    .rubric-form {
      display: flex;
      flex-direction: column;
      gap: 16px;
    }

    .rubric-heading h2 {
      font-size: 16px;
      font-weight: 600;
      color: #ffffff;
    }

    .rubric-heading p {
      font-size: 12px;
      color: #9aa0a6;
      margin-top: 2px;
    }

    .score-group {
      background: #25272a;
      padding: 12px;
      border-radius: 10px;
      border: 1px solid #3c4043;
    }

    .score-label-row {
      display: flex;
      justify-content: space-between;
      margin-bottom: 8px;
    }

    .score-title {
      font-size: 13px;
      font-weight: 600;
      color: #f1f3f4;
    }

    .score-val {
      font-size: 13px;
      font-weight: 700;
      color: #8ab4f8;
    }

    .score-slider {
      width: 100%;
      accent-color: #8ab4f8;
      cursor: pointer;
    }

    .score-ticks {
      display: flex;
      justify-content: space-between;
      font-size: 10px;
      color: #80868b;
      margin-top: 4px;
    }

    .form-label {
      display: block;
      font-size: 12px;
      font-weight: 600;
      color: #e3e3e3;
      margin-bottom: 6px;
    }

    .decision-select, .notes-textarea {
      width: 100%;
      background: #25272a;
      border: 1px solid #3c4043;
      border-radius: 8px;
      color: white;
      padding: 8px 12px;
      font-size: 13px;
    }

    .rubric-actions {
      display: flex;
      gap: 10px;
      margin-top: 6px;
    }

    .btn-save-eval {
      flex: 1;
      background: #3c4043;
      border: none;
      color: white;
      padding: 10px;
      border-radius: 8px;
      font-weight: 600;
      cursor: pointer;
      transition: background 0.2s;
    }

    .btn-save-eval:hover {
      background: #4f5358;
    }

    .btn-finalize-eval {
      flex: 1.5;
      background: #1a73e8;
      border: none;
      color: white;
      padding: 10px;
      border-radius: 8px;
      font-weight: 600;
      cursor: pointer;
      transition: background 0.2s;
    }

    .btn-finalize-eval:hover {
      background: #1557b0;
    }

    .eval-message {
      padding: 8px 12px;
      border-radius: 6px;
      font-size: 12px;
      background: #25272a;
      color: #fbbc04;
      text-align: center;
    }

    .eval-message.success {
      background: rgba(52, 168, 83, 0.15);
      color: #34a853;
      border: 1px solid rgba(52, 168, 83, 0.3);
    }

    /* CHAT TAB */
    .chat-tab {
      padding: 0;
      gap: 0;
    }

    .chat-messages {
      flex: 1;
      overflow-y: auto;
      padding: 14px;
      display: flex;
      flex-direction: column;
      gap: 10px;
    }

    .no-messages {
      color: #80868b;
      font-size: 12px;
      text-align: center;
      margin-top: 30px;
      font-style: italic;
    }

    .chat-bubble-row {
      display: flex;
      justify-content: flex-start;
    }

    .chat-bubble-row.own-msg {
      justify-content: flex-end;
    }

    .chat-bubble {
      max-width: 80%;
      background: #282a2d;
      border-radius: 12px;
      padding: 8px 12px;
    }

    .own-msg .chat-bubble {
      background: #1a73e8;
    }

    .chat-sender {
      font-size: 11px;
      color: #9aa0a6;
      margin-bottom: 2px;
      display: flex;
      justify-content: space-between;
      gap: 8px;
    }

    .own-msg .chat-sender {
      color: #d2e3fc;
    }

    .chat-text {
      font-size: 13px;
      color: #ffffff;
      word-break: break-word;
    }

    .chat-input-bar {
      display: flex;
      padding: 10px 14px;
      background: #25272a;
      border-top: 1px solid #2f3133;
      gap: 8px;
    }

    .chat-input {
      flex: 1;
      background: #18191a;
      border: 1px solid #3c4043;
      border-radius: 20px;
      padding: 8px 14px;
      color: white;
      font-size: 13px;
      outline: none;
    }

    .btn-send-chat {
      width: 36px;
      height: 36px;
      border-radius: 50%;
      background: #1a73e8;
      border: none;
      color: white;
      cursor: pointer;
      font-size: 14px;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: background 0.2s;
    }

    .btn-send-chat:hover {
      background: #1557b0;
    }

    /* BOTTOM CONTROLS FOOTER (Google Meet Classic Floating Dock) */
    .meet-footer {
      height: 76px;
      padding: 0 24px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      background: rgba(19, 19, 20, 0.95);
      border-top: 1px solid #2f3133;
      z-index: 10;
    }

    .footer-left {
      width: 250px;
    }

    .room-info-pill {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      background: #25272a;
      padding: 6px 12px;
      border-radius: 18px;
      border: 1px solid #3c4043;
      font-size: 12px;
    }

    .room-pill-code {
      font-family: monospace;
      color: #8ab4f8;
      font-weight: 600;
    }

    .btn-copy-chip {
      background: transparent;
      border: none;
      color: #9aa0a6;
      cursor: pointer;
      font-size: 12px;
    }

    .btn-copy-chip:hover {
      color: white;
    }

    .footer-center {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .control-btn {
      width: 48px;
      height: 48px;
      border-radius: 50%;
      background: #3c4043;
      border: none;
      color: white;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 18px;
      transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    }

    .control-btn:hover {
      background: #4f5358;
      transform: scale(1.06);
    }

    .control-btn.off {
      background: #ea4335;
      color: white;
    }

    .control-btn.active-screen {
      background: #8ab4f8;
      color: #202124;
    }

    .control-btn.end-call-btn {
      width: 68px;
      border-radius: 24px;
      background: #ea4335;
      color: white;
    }

    .control-btn.end-call-btn:hover {
      background: #d93025;
      transform: scale(1.06);
    }

    .footer-right {
      display: flex;
      gap: 8px;
      justify-content: flex-end;
      width: 250px;
    }

    .dock-action-btn {
      background: #25272a;
      border: 1px solid #3c4043;
      color: #e3e3e3;
      padding: 8px 12px;
      border-radius: 10px;
      font-size: 12px;
      font-weight: 500;
      cursor: pointer;
      position: relative;
      transition: all 0.2s;
    }

    .dock-action-btn:hover {
      background: #303134;
      border-color: #5f6368;
    }

    .dock-action-btn.active {
      background: #8ab4f8;
      color: #202124;
      border-color: #8ab4f8;
      font-weight: 600;
    }

    .chat-unread-dot {
      position: absolute;
      top: 4px;
      right: 4px;
      width: 8px;
      height: 8px;
      background: #ea4335;
      border-radius: 50%;
    }
  `]
})
export class InterviewRoomComponent implements OnInit, OnDestroy {
  @ViewChild('localVideo') localVideoRef!: ElementRef<HTMLVideoElement>;
  @ViewChild('remoteVideo') remoteVideoRef!: ElementRef<HTMLVideoElement>;
  @ViewChild('screenVideo') screenVideoRef!: ElementRef<HTMLVideoElement>;
  @ViewChild('chatScrollContainer') chatScrollContainer!: ElementRef<HTMLDivElement>;

  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private http = inject(HttpClient);

  // Meeting Identifiers & Parameters
  roomCode: string = '';
  role: 'interviewer' | 'candidate' = 'interviewer';
  roomTitle: string = '';
  roomStatus: string = 'LIVE';
  companyName: string = '';
  driveRole: string = '';

  // Candidate Real-time Details
  candidateName: string = '';
  candidateEmail: string = '';
  candidatePhone: string = '';
  candidateBatch: string = '';
  candidateId: number | null = null;

  // Interviewer Real-time Details
  interviewerName: string = '';
  interviewerEmail: string = '';
  interviewerId: number | null = null;

  // Presence State
  interviewerOnline: boolean = false;
  candidateOnline: boolean = false;

  // WebRTC & Media State
  micEnabled: boolean = true;
  cameraEnabled: boolean = true;
  screenShareActive: boolean = false;

  localStream: MediaStream | null = null;
  remoteStream: MediaStream | null = null;
  screenStream: MediaStream | null = null;
  peerConnection: RTCPeerConnection | null = null;

  localStreamActive: boolean = false;
  remoteStreamActive: boolean = false;
  remoteAudioMuted: boolean = false;

  // Audio Analyser & Speaking Rings
  localSpeaking: boolean = false;
  remoteSpeaking: boolean = false;
  private audioCtx: AudioContext | null = null;
  private localAnalyser: AnalyserNode | null = null;
  private remoteAnalyser: AnalyserNode | null = null;
  private speakingInterval: any = null;

  // Workbench Navigation ('code' | 'problem' | 'rubric' | 'chat' | 'none')
  activeTab: 'code' | 'problem' | 'rubric' | 'chat' | 'none' = 'code';

  // Live Collaborative Code Editor
  codeLanguage: string = 'java';
  currentCode: string = '';
  isCodeSynced: boolean = true;
  private codeSyncTimeout: any = null;
  private lastSyncedCode: string = '';
  isRunningCode: boolean = false;
  runResult: RunResult | null = null;

  // Problem Details
  problemId: number = 1;
  problemTitle: string = 'Two Sum - Target Pair';
  problemDifficulty: string = 'Easy';
  problemDescription: string = '';
  problemConstraints: string = '';
  sampleInput: string = '';
  sampleOutput: string = '';
  availableProblems: any[] = [];

  // Interviewer Evaluation Rubric
  rubric = {
    problemSolvingScore: 4,
    technicalCompetencyScore: 4,
    codeQualityScore: 4,
    communicationScore: 4,
    hiringDecision: 'HIRE',
    interviewerNotes: ''
  };
  isSubmittingEvaluation: boolean = false;
  evaluationStatusMessage: string = '';
  evalSuccess: boolean = false;

  // Live Chat
  chatMessages: ChatMessage[] = [];
  newChatMessage: string = '';
  unreadChatCount: number = 0;
  private lastChatTimestamp: number = 0;

  // Timers & Polling
  callSeconds: number = 0;
  private callTimer: any = null;
  private presenceTimer: any = null;
  private syncTimer: any = null;
  private signalTimestamp: number = 0;

  private get apiUrl(): string {
    return environment.production ? window.location.origin : 'http://localhost:8080';
  }

  ngOnInit(): void {
    // 1. Resolve roomCode from params or URL fragment/query
    this.roomCode = this.route.snapshot.paramMap.get('roomCode') || '';
    if (!this.roomCode) {
      this.route.queryParams.subscribe(params => {
        if (params['roomCode']) this.roomCode = params['roomCode'];
        if (params['code']) this.roomCode = params['code'];
      });
    }

    const queryRole = this.route.snapshot.queryParamMap.get('role');
    if (queryRole === 'candidate') {
      this.role = 'candidate';
    } else {
      this.role = 'interviewer';
    }

    if (!this.roomCode) {
      this.roomCode = 'AXIS-DEMO';
    }

    // 2. Fetch room metadata, problem bank, and initialize session
    this.loadRoomDetails();
    this.loadQuestionBank();

    // 3. Initialize Media & WebRTC
    this.initMediaAndWebRTC();

    // 4. Start Background Heartbeat, Polling & Timer
    this.startCallTimer();
    this.startPresenceAndSyncPolling();
  }

  ngOnDestroy(): void {
    this.cleanup();
  }

  @HostListener('window:beforeunload')
  onBeforeUnload(): void {
    this.cleanup();
  }

  private cleanup(): void {
    if (this.callTimer) clearInterval(this.callTimer);
    if (this.presenceTimer) clearInterval(this.presenceTimer);
    if (this.syncTimer) clearInterval(this.syncTimer);
    if (this.speakingInterval) clearInterval(this.speakingInterval);

    // Stop all media tracks
    if (this.localStream) {
      this.localStream.getTracks().forEach(t => t.stop());
    }
    if (this.screenStream) {
      this.screenStream.getTracks().forEach(t => t.stop());
    }
    if (this.peerConnection) {
      this.peerConnection.close();
    }
    if (this.audioCtx) {
      try { this.audioCtx.close(); } catch (_) {}
    }
  }

  // --- API & DATA INITIALIZATION ---

  private loadRoomDetails(): void {
    this.http.get<any>(`${this.apiUrl}/api/interview/rooms/${this.roomCode}`).subscribe({
      next: (data) => {
        this.applyRoomData(data);
      },
      error: () => {
        // Fallback: Create or join room automatically
        this.http.post<any>(`${this.apiUrl}/api/interview/rooms/${this.roomCode}/join`, {
          role: this.role,
          name: this.role === 'interviewer' ? 'Lead Interviewer' : 'Candidate'
        }).subscribe({
          next: (data) => this.applyRoomData(data),
          error: (err) => console.warn('Could not auto-create room', err)
        });
      }
    });
  }

  private applyRoomData(data: any): void {
    if (!data) return;
    this.roomTitle = data.title || this.roomTitle || '1-on-1 Placement Interview';
    this.roomStatus = data.status || 'LIVE';
    this.companyName = data.companyName || '';
    this.driveRole = data.role || data.driveRole || '';

    // Candidate details
    this.candidateName = data.candidateName || this.candidateName || 'Candidate';
    this.candidateEmail = data.candidateEmail || this.candidateEmail;
    this.candidatePhone = data.candidatePhone || '';
    this.candidateBatch = data.batchName || '';
    this.candidateId = data.candidateId || null;

    // Interviewer details
    this.interviewerName = data.interviewerName || this.interviewerName || 'Lead Mentor';
    this.interviewerEmail = data.interviewerEmail || this.interviewerEmail;
    this.interviewerId = data.interviewerId || null;

    // Problem details
    if (data.problemTitle) this.problemTitle = data.problemTitle;
    if (data.problemDifficulty) this.problemDifficulty = data.problemDifficulty;
    if (data.problemDescription) this.problemDescription = data.problemDescription;

    // Existing code
    if (data.submittedCode && !this.currentCode) {
      this.currentCode = data.submittedCode;
      this.lastSyncedCode = data.submittedCode;
    }
    if (data.codeLanguage) {
      this.codeLanguage = data.codeLanguage;
    }

    // Existing evaluation rubric
    if (data.problemSolvingScore) this.rubric.problemSolvingScore = data.problemSolvingScore;
    if (data.technicalCompetencyScore) this.rubric.technicalCompetencyScore = data.technicalCompetencyScore;
    if (data.codeQualityScore) this.rubric.codeQualityScore = data.codeQualityScore;
    if (data.communicationScore) this.rubric.communicationScore = data.communicationScore;
    if (data.hiringDecision) this.rubric.hiringDecision = data.hiringDecision;
    if (data.interviewerNotes) this.rubric.interviewerNotes = data.interviewerNotes;

    // If no code exists yet, load starter code
    if (!this.currentCode) {
      this.resetStarterCode();
    }
  }

  private loadQuestionBank(): void {
    this.http.get<any[]>(`${this.apiUrl}/api/interview/questions`).subscribe({
      next: (questions) => {
        if (questions && questions.length > 0) {
          this.availableProblems = questions;
        }
      },
      error: () => {}
    });
  }

  selectProblem(event: any): void {
    const idx = event.target.value;
    const selected = this.availableProblems[idx];
    if (selected) {
      this.problemId = selected.id || 1;
      this.problemTitle = selected.title;
      this.problemDifficulty = selected.difficulty;
      this.problemDescription = selected.description;
      this.resetStarterCode();
    }
  }

  // --- WEBRTC & MEDIA STREAM MANAGEMENT ---

  private async initMediaAndWebRTC(): Promise<void> {
    try {
      // 1. Get User Media (Camera & Microphone)
      this.localStream = await navigator.mediaDevices.getUserMedia({
        video: { width: { ideal: 1280 }, height: { ideal: 720 } },
        audio: true
      });
      this.localStreamActive = true;

      // Attach to local video element
      setTimeout(() => {
        if (this.localVideoRef?.nativeElement && this.localStream) {
          this.localVideoRef.nativeElement.srcObject = this.localStream;
        }
      }, 200);

      // 2. Setup Audio Speaking Analyzer
      this.setupAudioAnalysis();

      // 3. Initialize PeerConnection
      this.setupPeerConnection();

    } catch (err) {
      console.warn('Media access error (falling back to audio or placeholder mode):', err);
      // Try audio only if video failed
      try {
        this.localStream = await navigator.mediaDevices.getUserMedia({ audio: true });
        this.cameraEnabled = false;
        this.localStreamActive = true;
        this.setupAudioAnalysis();
        this.setupPeerConnection();
      } catch (audioErr) {
        console.warn('Audio access error:', audioErr);
        this.cameraEnabled = false;
        this.micEnabled = false;
      }
    }
  }

  private setupPeerConnection(): void {
    const config: RTCConfiguration = {
      iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
        { urls: 'stun:stun1.l.google.com:19302' }
      ]
    };

    this.peerConnection = new RTCPeerConnection(config);

    // Add local tracks to peer connection
    if (this.localStream) {
      this.localStream.getTracks().forEach(track => {
        this.peerConnection?.addTrack(track, this.localStream!);
      });
    }

    // Handle remote stream tracks
    this.peerConnection.ontrack = (event) => {
      if (event.streams && event.streams[0]) {
        this.remoteStream = event.streams[0];
        this.remoteStreamActive = true;
        setTimeout(() => {
          if (this.remoteVideoRef?.nativeElement && this.remoteStream) {
            this.remoteVideoRef.nativeElement.srcObject = this.remoteStream;
          }
        }, 150);
        this.setupRemoteAudioAnalysis();
      }
    };

    // Handle ICE Candidates
    this.peerConnection.onicecandidate = (event) => {
      if (event.candidate) {
        this.sendSignal({
          type: 'candidate',
          candidate: event.candidate,
          from: this.role,
          to: this.role === 'interviewer' ? 'candidate' : 'interviewer'
        });
      }
    };

    // If interviewer, initiate WebRTC Offer
    if (this.role === 'interviewer') {
      setTimeout(() => this.createOffer(), 1500);
    }
  }

  private async createOffer(): Promise<void> {
    if (!this.peerConnection) return;
    try {
      const offer = await this.peerConnection.createOffer();
      await this.peerConnection.setLocalDescription(offer);
      this.sendSignal({
        type: 'offer',
        sdp: offer.sdp,
        from: this.role,
        to: 'candidate'
      });
    } catch (err) {
      console.warn('Create offer error:', err);
    }
  }

  private async handleSignal(signal: any): Promise<void> {
    if (!this.peerConnection || !signal) return;

    try {
      if (signal.type === 'offer' && this.role === 'candidate') {
        await this.peerConnection.setRemoteDescription(new RTCSessionDescription({ type: 'offer', sdp: signal.sdp }));
        const answer = await this.peerConnection.createAnswer();
        await this.peerConnection.setLocalDescription(answer);
        this.sendSignal({
          type: 'answer',
          sdp: answer.sdp,
          from: this.role,
          to: 'interviewer'
        });
      } else if (signal.type === 'answer' && this.role === 'interviewer') {
        await this.peerConnection.setRemoteDescription(new RTCSessionDescription({ type: 'answer', sdp: signal.sdp }));
      } else if (signal.type === 'candidate' && signal.candidate) {
        await this.peerConnection.addIceCandidate(new RTCIceCandidate(signal.candidate));
      }
    } catch (e) {
      console.warn('Signal handling error:', e);
    }
  }

  private sendSignal(payload: any): void {
    this.http.post(`${this.apiUrl}/api/interview/rooms/${this.roomCode}/signal`, payload).subscribe({
      error: () => {}
    });
  }

  // --- AUDIO SPEAKING RING VISUALIZATION ---

  private setupAudioAnalysis(): void {
    if (!this.localStream) return;
    try {
      const AudioCtxClass = window.AudioContext || (window as any).webkitAudioContext;
      this.audioCtx = new AudioCtxClass();
      const audioSource = this.audioCtx.createMediaStreamSource(this.localStream);
      this.localAnalyser = this.audioCtx.createAnalyser();
      this.localAnalyser.fftSize = 64;
      audioSource.connect(this.localAnalyser);

      // Polling speaking levels
      this.speakingInterval = setInterval(() => {
        if (this.micEnabled && this.localAnalyser) {
          const buffer = new Uint8Array(this.localAnalyser.frequencyBinCount);
          this.localAnalyser.getByteFrequencyData(buffer);
          let sum = 0;
          for (let i = 0; i < buffer.length; i++) sum += buffer[i];
          const avg = sum / buffer.length;
          this.localSpeaking = avg > 20;
        } else {
          this.localSpeaking = false;
        }
      }, 150);
    } catch (_) {}
  }

  private setupRemoteAudioAnalysis(): void {
    if (!this.remoteStream || !this.audioCtx) return;
    try {
      const remoteSource = this.audioCtx.createMediaStreamSource(this.remoteStream);
      this.remoteAnalyser = this.audioCtx.createAnalyser();
      this.remoteAnalyser.fftSize = 64;
      remoteSource.connect(this.remoteAnalyser);
    } catch (_) {}
  }

  // --- CONTROLS: MIC, CAMERA, SCREEN SHARE, LEAVE ---

  toggleMicrophone(): void {
    if (!this.localStream) return;
    this.micEnabled = !this.micEnabled;
    this.localStream.getAudioTracks().forEach(track => {
      track.enabled = this.micEnabled;
    });
  }

  toggleCamera(): void {
    if (!this.localStream) return;
    this.cameraEnabled = !this.cameraEnabled;
    this.localStream.getVideoTracks().forEach(track => {
      track.enabled = this.cameraEnabled;
    });
  }

  async toggleScreenShare(): Promise<void> {
    if (this.screenShareActive) {
      // Stop screen share
      if (this.screenStream) {
        this.screenStream.getTracks().forEach(t => t.stop());
      }
      this.screenStream = null;
      this.screenShareActive = false;
    } else {
      try {
        this.screenStream = await navigator.mediaDevices.getDisplayMedia({ video: true });
        this.screenShareActive = true;
        setTimeout(() => {
          if (this.screenVideoRef?.nativeElement && this.screenStream) {
            this.screenVideoRef.nativeElement.srcObject = this.screenStream;
          }
        }, 150);

        this.screenStream.getVideoTracks()[0].onended = () => {
          this.screenShareActive = false;
          this.screenStream = null;
        };
      } catch (e) {
        console.warn('Screen share cancelled/denied', e);
      }
    }
  }

  leaveRoom(): void {
    if (confirm('Are you sure you want to leave this interview call?')) {
      this.cleanup();
      this.router.navigate(['/interviews']);
    }
  }

  toggleTab(tab: 'code' | 'problem' | 'rubric' | 'chat'): void {
    if (this.activeTab === tab) {
      this.activeTab = 'none';
    } else {
      this.activeTab = tab;
      if (tab === 'chat') this.unreadChatCount = 0;
    }
  }

  copyRoomLink(): void {
    const link = `${window.location.origin}/#/interview/${this.roomCode}?role=candidate`;
    navigator.clipboard.writeText(link).then(() => {
      alert(`Interview link copied to clipboard!\n${link}`);
    });
  }

  // --- LIVE CODE EDITOR & SYNC ---

  onCodeChanged(newCode: string): void {
    this.isCodeSynced = false;
    if (this.codeSyncTimeout) clearTimeout(this.codeSyncTimeout);
    this.codeSyncTimeout = setTimeout(() => {
      this.syncCodeToBackend(newCode);
    }, 800);
  }

  private syncCodeToBackend(code: string): void {
    this.lastSyncedCode = code;
    this.http.post(`${this.apiUrl}/api/interview/rooms/${this.roomCode}/code`, {
      code,
      language: this.codeLanguage
    }).subscribe({
      next: () => {
        this.isCodeSynced = true;
      },
      error: () => {
        this.isCodeSynced = false;
      }
    });
  }

  onLanguageChange(): void {
    this.resetStarterCode();
    this.syncCodeToBackend(this.currentCode);
  }

  resetStarterCode(): void {
    if (this.codeLanguage === 'java') {
      this.currentCode = `public class Solution {
    public static int[] twoSum(int[] nums, int target) {
        // Implement optimal solution here
        for (int i = 0; i < nums.length; i++) {
            for (int j = i + 1; j < nums.length; j++) {
                if (nums[i] + nums[j] == target) {
                    return new int[]{i, j};
                }
            }
        }
        return new int[]{};
    }

    public static void main(String[] args) {
        int[] nums = {2, 7, 11, 15};
        int target = 9;
        int[] result = twoSum(nums, target);
        System.out.println("[" + result[0] + ", " + result[1] + "]");
    }
}`;
    } else if (this.codeLanguage === 'python') {
      this.currentCode = `def two_sum(nums, target):
    # Implement optimal hash map solution
    seen = {}
    for i, num in enumerate(nums):
        complement = target - num
        if complement in seen:
            return [seen[complement], i]
        seen[num] = i
    return []

if __name__ == "__main__":
    nums = [2, 7, 11, 15]
    target = 9
    print(two_sum(nums, target))
`;
    } else if (this.codeLanguage === 'javascript') {
      this.currentCode = `function twoSum(nums, target) {
    const map = new Map();
    for (let i = 0; i < nums.length; i++) {
        const comp = target - nums[i];
        if (map.has(comp)) return [map.get(comp), i];
        map.set(nums[i], i);
    }
    return [];
}

console.log(twoSum([2, 7, 11, 15], 9));
`;
    } else {
      this.currentCode = `#include <iostream>
#include <vector>
#include <unordered_map>

using namespace std;

vector<int> twoSum(vector<int>& nums, int target) {
    unordered_map<int, int> seen;
    for (int i = 0; i < nums.size(); ++i) {
        int comp = target - nums[i];
        if (seen.count(comp)) return {seen[comp], i};
        seen[nums[i]] = i;
    }
    return {};
}

int main() {
    vector<int> nums = {2, 7, 11, 15};
    int target = 9;
    vector<int> ans = twoSum(nums, target);
    cout << "[" << ans[0] << ", " << ans[1] << "]" << endl;
    return 0;
}
`;
    }
    this.isCodeSynced = false;
    this.syncCodeToBackend(this.currentCode);
  }

  runLiveCode(): void {
    this.isRunningCode = true;
    this.runResult = null;

    const payload = {
      questionId: this.problemId,
      language: this.codeLanguage,
      code: this.currentCode,
      sourceCode: this.currentCode,
      customInput: ''
    };

    this.http.post<RunResult>(`${this.apiUrl}/api/coding/run`, payload).subscribe({
      next: (res) => {
        this.runResult = res;
        this.isRunningCode = false;
      },
      error: (err) => {
        this.runResult = {
          success: false,
          verdict: 'EXECUTION_ERROR',
          error: err?.error?.message || 'Sandbox compilation or execution failed.'
        };
        this.isRunningCode = false;
      }
    });
  }

  // --- RUBRIC EVALUATION ---

  submitEvaluation(finalize: boolean): void {
    this.isSubmittingEvaluation = true;
    this.evaluationStatusMessage = '';

    const payload = {
      problemSolvingScore: this.rubric.problemSolvingScore,
      technicalCompetencyScore: this.rubric.technicalCompetencyScore,
      codeQualityScore: this.rubric.codeQualityScore,
      communicationScore: this.rubric.communicationScore,
      hiringDecision: this.rubric.hiringDecision,
      interviewerNotes: this.rubric.interviewerNotes,
      submittedCode: this.currentCode,
      codeLanguage: this.codeLanguage,
      finalize
    };

    this.http.post<any>(`${this.apiUrl}/api/interview/rooms/${this.roomCode}/evaluation`, payload).subscribe({
      next: (res) => {
        this.isSubmittingEvaluation = false;
        this.evalSuccess = true;
        this.evaluationStatusMessage = finalize
          ? '🎉 Round completed & final decision saved!'
          : '✅ Evaluation draft saved successfully!';
        if (finalize) {
          this.roomStatus = 'COMPLETED';
        }
      },
      error: (err) => {
        this.isSubmittingEvaluation = false;
        this.evalSuccess = false;
        this.evaluationStatusMessage = 'Error saving evaluation: ' + (err?.error?.message || 'Server error');
      }
    });
  }

  // --- CHAT MESSAGING ---

  sendChatMessage(): void {
    const text = this.newChatMessage?.trim();
    if (!text) return;

    const payload = {
      sender: this.role === 'interviewer' ? (this.interviewerName || 'Interviewer') : (this.candidateName || 'Candidate'),
      senderRole: this.role,
      message: text
    };

    this.http.post<any>(`${this.apiUrl}/api/interview/rooms/${this.roomCode}/chat`, payload).subscribe({
      next: (saved) => {
        this.newChatMessage = '';
        if (saved) {
          this.chatMessages.push(saved);
          this.scrollToBottom();
        }
      },
      error: () => {}
    });
  }

  private scrollToBottom(): void {
    setTimeout(() => {
      if (this.chatScrollContainer?.nativeElement) {
        this.chatScrollContainer.nativeElement.scrollTop = this.chatScrollContainer.nativeElement.scrollHeight;
      }
    }, 100);
  }

  // --- BACKGROUND POLLING & HEARTBEATS ---

  private startCallTimer(): void {
    this.callTimer = setInterval(() => {
      this.callSeconds++;
    }, 1000);
  }

  private startPresenceAndSyncPolling(): void {
    // 1. Send Presence Heartbeat immediately & every 4 seconds
    this.sendPresenceHeartbeat();
    this.presenceTimer = setInterval(() => {
      this.sendPresenceHeartbeat();
    }, 4000);

    // 2. Poll Code, Chat, and Signals every 2.5 seconds
    this.syncTimer = setInterval(() => {
      this.pollChat();
      this.pollCodeSync();
      this.pollSignals();
    }, 2500);
  }

  private sendPresenceHeartbeat(): void {
    const payload = {
      role: this.role,
      name: this.role === 'interviewer' ? (this.interviewerName || 'Interviewer') : (this.candidateName || 'Candidate')
    };

    this.http.post<any>(`${this.apiUrl}/api/interview/rooms/${this.roomCode}/presence`, payload).subscribe({
      next: (res) => {
        if (res) {
          this.interviewerOnline = !!res.interviewerOnline;
          this.candidateOnline = !!res.candidateOnline;
        }
      },
      error: () => {}
    });
  }

  private pollChat(): void {
    this.http.get<ChatMessage[]>(`${this.apiUrl}/api/interview/rooms/${this.roomCode}/chat?since=${this.lastChatTimestamp}`).subscribe({
      next: (messages) => {
        if (messages && messages.length > 0) {
          let hasNew = false;
          for (const m of messages) {
            if (!this.chatMessages.some(existing => existing.id === m.id || (existing.timestamp === m.timestamp && existing.message === m.message))) {
              this.chatMessages.push(m);
              hasNew = true;
              if (this.activeTab !== 'chat' && m.senderRole !== this.role) {
                this.unreadChatCount++;
              }
            }
            if (m.timestamp > this.lastChatTimestamp) {
              this.lastChatTimestamp = m.timestamp;
            }
          }
          if (hasNew) this.scrollToBottom();
        }
      },
      error: () => {}
    });
  }

  private pollCodeSync(): void {
    // Only update code from peer if local user is not actively typing
    if (!this.isCodeSynced) return;

    this.http.get<any>(`${this.apiUrl}/api/interview/rooms/${this.roomCode}/code`).subscribe({
      next: (res) => {
        if (res && res.code && res.code !== this.currentCode && res.code !== this.lastSyncedCode) {
          this.currentCode = res.code;
          this.lastSyncedCode = res.code;
        }
        if (res && res.language && res.language !== this.codeLanguage) {
          this.codeLanguage = res.language;
        }
      },
      error: () => {}
    });
  }

  private pollSignals(): void {
    this.http.get<any[]>(`${this.apiUrl}/api/interview/rooms/${this.roomCode}/signal?role=${this.role}&since=${this.signalTimestamp}`).subscribe({
      next: (signals) => {
        if (signals && signals.length > 0) {
          for (const s of signals) {
            this.handleSignal(s);
            if (s.timestamp && s.timestamp > this.signalTimestamp) {
              this.signalTimestamp = s.timestamp;
            }
          }
        }
      },
      error: () => {}
    });
  }

  // --- HELPERS & FORMATTERS ---

  get candidateInitials(): string {
    if (!this.candidateName) return 'C';
    const parts = this.candidateName.trim().split(' ');
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return this.candidateName.substring(0, 2).toUpperCase();
  }

  get myInitials(): string {
    return this.role === 'interviewer' ? 'YOU' : 'C';
  }

  get remoteInitials(): string {
    return this.role === 'interviewer' ? this.candidateInitials : 'FAC';
  }

  formatDuration(seconds: number): string {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  }

  formatTime(timestamp: number): string {
    if (!timestamp) return '';
    const d = new Date(timestamp);
    return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }
}
