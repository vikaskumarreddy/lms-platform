import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';
import { ApiErrorService } from '../../services/api-error.service';
import { ConfirmService } from '../../services/confirm.service';

interface Batch {
  id: number;
  name: string;
  description?: string;
  planId?: number;
  startDate?: string;
  endDate?: string;
  isActive: boolean;
  maxStudents?: number;
  schedule?: string;
  mentorId?: number;
  createdAt?: string;
}

interface Faculty {
  id: number;
  name: string;
  email: string;
}

interface Student {
  id: number;
  name: string;
  email: string;
  phone?: string;
  isActive: boolean;
  planId?: number;
  batchId?: number;
}

interface SubscriptionPlan {
  id: number;
  name: string;
  price: number;
  period: string;
}

@Component({
  selector: 'app-batches',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
      <h1 style="font-size:24px;font-weight:700;">👥 Batches</h1>
      <button class="btn btn-primary" (click)="openAddModal()">+ Create Batch</button>
    </div>

    <div class="card" style="margin-bottom:20px;">
      <table>
        <thead>
          <tr>
            <th>ID</th>
            <th>Batch Name</th>
            <th>Mentor</th>
            <th>Subscription Plan</th>
            <th>Start Date</th>
            <th>End Date</th>
            <th>Students</th>
            <th>Status</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr *ngFor="let b of batches">
            <td>{{b.id}}</td>
            <td style="font-weight:600;">{{b.name}}</td>
            <td>
              <span *ngIf="getMentorName(b.mentorId)" style="font-size:13px;">👨‍🏫 {{getMentorName(b.mentorId)}}</span>
              <span *ngIf="!getMentorName(b.mentorId)" style="color:#64748B;font-size:13px;">No mentor</span>
            </td>
            <td>
              <span *ngIf="getPlanName(b.planId)" class="badge badge-warning">⭐ {{getPlanName(b.planId)}}</span>
              <span *ngIf="!getPlanName(b.planId)" style="color:#64748B;font-size:13px;">No plan</span>
            </td>
            <td>{{formatDate(b.startDate)}}</td>
            <td>{{formatDate(b.endDate)}}</td>
            <td>
              <span class="badge" style="background:#EEF2FF;color:#4338CA;">{{getBatchStudentCount(b.id)}} students</span>
            </td>
            <td>
              <span class="badge" [class.badge-success]="b.isActive" [class.badge-danger]="!b.isActive">
                {{b.isActive ? 'Active' : 'Inactive'}}
              </span>
            </td>
            <td>
              <button class="btn btn-primary" style="padding:4px 12px;font-size:12px;margin-right:8px;" (click)="openBatchChat(b)">💬 Chat</button>
              <button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;margin-right:8px;" (click)="viewBatch(b)">👥 Manage</button>
              <button class="btn btn-secondary" style="padding:4px 12px;font-size:12px;margin-right:8px;" (click)="openEditModal(b)">Edit</button>
              <button class="btn btn-danger" style="padding:4px 12px;font-size:12px;" (click)="deleteBatch(b)">Delete</button>
            </td>
          </tr>
          <tr *ngIf="batches.length === 0">
            <td colspan="9" style="text-align:center;color:#64748B;padding:32px;">No batches found. Click "+ Create Batch" to create one.</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Batch Form Modal (Fieldset + Legend with Tabbed content) -->
    <div class="modal-overlay" *ngIf="showModal" (click)="closeModal($event)">
      <div class="modal-content" style="width:90%;max-width:680px;" (click)="$event.stopPropagation()">
        <div style="display:none;justify-content:flex-end;margin-bottom:0;">
          <button class="btn btn-secondary btn-sm" (click)="closeModal()">✕</button>
        </div>

        <!-- Step indicator -->
        <div class="popup-steps">
          <div class="popup-step" [class.active]="batchTab === 'basic'" [class.completed]="batchTab === 'schedule'">1</div>
          <div class="popup-step-line" [class.completed]="batchTab === 'schedule'"></div>
          <div class="popup-step" [class.active]="batchTab === 'schedule'">2</div>
        </div>

        <!-- Tabs -->
        <div class="popup-tabs">
          <button [class.active]="batchTab === 'basic'" (click)="batchTab = 'basic'">🔑 Basic Details</button>
          <button [class.active]="batchTab === 'schedule'" (click)="batchTab = 'schedule'">📅 Schedule & Access</button>
        </div>

        <form (ngSubmit)="saveBatch()">
          <!-- Basic tab -->
          <fieldset *ngIf="batchTab === 'basic'">
            <legend>{{editingBatch ? 'Edit Batch' : 'Create New Batch'}}</legend>
            <div class="popup-form-grid">
              <div>
                <label>Batch Name *</label>
                <input type="text" [(ngModel)]="batchForm.name" name="name" required placeholder="e.g. Java Full Stack - Jan 2026">
              </div>
              <div class="full-width">
                <label>Description</label>
                <textarea [(ngModel)]="batchForm.description" name="description" rows="2" placeholder="Batch description"></textarea>
              </div>
              <div>
                <label>Subscription Plan</label>
                <select [(ngModel)]="batchForm.planId" name="planId">
                  <option [ngValue]="null">No plan</option>
                  <option *ngFor="let p of plans" [ngValue]="p.id">{{p.name}} - ₹{{p.price}}{{p.period}}</option>
                </select>
              </div>
              <div>
                <label>Mentor / Faculty</label>
                <select [(ngModel)]="batchForm.mentorId" name="mentorId">
                  <option [ngValue]="null">No mentor assigned</option>
                  <option *ngFor="let f of faculty" [ngValue]="f.id">{{f.name}} ({{f.email}})</option>
                </select>
              </div>
            </div>
          </fieldset>

          <!-- Schedule & Access tab -->
          <fieldset *ngIf="batchTab === 'schedule'">
            <legend>Schedule & Access</legend>
            <div class="popup-form-grid">
              <div>
                <label>Start Date</label>
                <input type="datetime-local" [(ngModel)]="batchForm.startDate" name="startDate">
              </div>
              <div>
                <label>End Date</label>
                <input type="datetime-local" [(ngModel)]="batchForm.endDate" name="endDate">
              </div>
              <div>
                <label>Max Students</label>
                <input type="number" [(ngModel)]="batchForm.maxStudents" name="maxStudents" placeholder="e.g. 50">
              </div>
              <div>
                <label>Schedule</label>
                <input type="text" [(ngModel)]="batchForm.schedule" name="schedule" placeholder="e.g. Mon/Wed/Fri 10am-12pm">
              </div>
              <div class="full-width">
                <label>Status</label>
                <select [(ngModel)]="batchForm.isActive" name="isActive">
                  <option [ngValue]="true">Active</option>
                  <option [ngValue]="false">Inactive</option>
                </select>
              </div>
            </div>
          </fieldset>

          <!-- Navigation -->
          <div class="popup-nav">
            <button type="button" class="btn btn-secondary" *ngIf="batchTab === 'schedule'" (click)="batchTab = 'basic'">← Back</button>
            <button type="button" class="btn btn-primary" *ngIf="batchTab === 'basic'" (click)="batchTab = 'schedule'">Next →</button>
            <button type="submit" class="btn btn-accent" *ngIf="batchTab === 'schedule'" [disabled]="loading">{{loading ? 'Saving...' : (editingBatch ? 'Update Batch' : 'Create Batch')}}</button>
            <span style="flex:1"></span>
            <button type="button" class="btn btn-danger" (click)="closeModal()">Cancel</button>
          </div>
        </form>

        <div *ngIf="errorMessage" style="margin-top:16px;padding:12px;background:#FEE2E2;color:#991B1B;border-radius:8px;font-size:14px;">
          {{errorMessage}}
        </div>
      </div>
    </div>

    <!-- Batch Community Chat Modal -->
    <div class="modal-overlay" *ngIf="activeChatBatch" (click)="closeBatchChat($event)">
      <div class="modal-content" style="width:90%;max-width:760px;display:flex;flex-direction:column;height:85vh;max-height:750px;padding:20px;" (click)="$event.stopPropagation()">
        <!-- Header -->
        <div style="display:flex;justify-content:space-between;align-items:center;padding-bottom:12px;border-bottom:1px solid #E2E8F0;">
          <div>
            <div style="display:flex;align-items:center;gap:8px;">
              <h2 style="font-size:18px;font-weight:700;margin:0;">💬 {{ activeChatBatch.name }} Community Channel</h2>
              <span class="badge badge-success" style="font-size:11px;">🟢 Real-Time</span>
            </div>
            <div style="font-size:12px;color:#64748B;margin-top:2px;">
              Mentor: <strong>{{ getMentorName(activeChatBatch.mentorId) || 'Academy Faculty' }}</strong> • {{ getBatchStudentCount(activeChatBatch.id) }} Students
            </div>
          </div>
          <button class="btn btn-secondary btn-sm" (click)="closeBatchChat()">✕</button>
        </div>

        <!-- Chat messages container -->
        <div style="flex:1;overflow-y:auto;padding:16px 8px;display:flex;flex-direction:column;gap:12px;background:#F8FAFC;border-radius:10px;">
          <div *ngIf="chatMessages.length === 0 && !loadingChat" style="text-align:center;color:#94A3B8;padding:40px 16px;">
            💬 No messages yet in this batch channel. Send an announcement or message below!
          </div>

          <div *ngFor="let msg of chatMessages"
               [style.align-self]="msg.messageType === 'ANNOUNCEMENT' ? 'center' : (msg.senderRole === 'ADMIN' || msg.senderRole === 'FACULTY' ? 'flex-end' : 'flex-start')"
               [style.max-width]="msg.messageType === 'ANNOUNCEMENT' ? '96%' : '75%'"
               style="display:flex;flex-direction:column;">

            <!-- ANNOUNCEMENT BANNER (Centered) -->
            <div *ngIf="msg.messageType === 'ANNOUNCEMENT'"
                 style="background:#FFFBEB;border:1.5px solid #FCD34D;border-radius:12px;padding:12px 18px;box-shadow:0 2px 4px rgba(0,0,0,0.06);width:100%;box-sizing:border-box;">
              <div style="display:flex;align-items:center;gap:8px;margin-bottom:6px;">
                <span style="font-size:16px;">📢</span>
                <strong style="font-size:13px;color:#92400E;">ANNOUNCEMENT • {{ msg.senderName }}</strong>
                <span class="badge" style="background:#FDE68A;color:#92400E;font-size:10px;">{{ msg.senderRole }}</span>
                <span style="font-size:11px;color:#B45309;margin-left:auto;">{{ msg.createdAt | date:'short' }}</span>
              </div>
              <div style="font-size:13.5px;color:#78350F;line-height:1.5;white-space:pre-wrap;">{{ msg.content }}</div>
            </div>

            <!-- CODE SNIPPET -->
            <div *ngIf="msg.messageType === 'CODE'"
                 style="background:#1E293B;color:#F8FAFC;border-radius:12px;box-shadow:0 3px 6px rgba(0,0,0,0.15);overflow:hidden;min-width:280px;">
              <div style="display:flex;justify-content:space-between;align-items:center;background:#0F172A;padding:8px 12px;border-bottom:1px solid #334155;">
                <div style="display:flex;align-items:center;gap:6px;">
                  <span style="font-size:13px;color:#38BDF8;">💻</span>
                  <span style="font-size:11.5px;font-weight:600;color:#CBD5E1;">{{ msg.senderName }}</span>
                  <span class="badge" [style.background]="msg.senderRole === 'STUDENT' ? '#38BDF8' : '#818CF8'" style="color:#0F172A;font-size:9.5px;font-weight:700;">{{ msg.senderRole }}</span>
                </div>
                <span style="font-size:10.5px;color:#94A3B8;">{{ msg.createdAt | date:'shortTime' }}</span>
              </div>
              <pre style="margin:0;padding:12px 14px;font-family:monospace;font-size:12.5px;overflow-x:auto;line-height:1.5;color:#38BDF8;background:#030712;"><code>{{ msg.content }}</code></pre>
            </div>

            <!-- REGULAR TEXT BUBBLE (FACULTY/ADMIN on Right, STUDENT on Left) -->
            <div *ngIf="msg.messageType !== 'ANNOUNCEMENT' && msg.messageType !== 'CODE'"
                 [style.background]="msg.senderRole === 'ADMIN' || msg.senderRole === 'FACULTY' ? '#4F46E5' : '#FFFFFF'"
                 [style.color]="msg.senderRole === 'ADMIN' || msg.senderRole === 'FACULTY' ? '#FFFFFF' : '#1E293B'"
                 [style.border]="msg.senderRole === 'ADMIN' || msg.senderRole === 'FACULTY' ? 'none' : '1px solid #E2E8F0'"
                 [style.border-radius]="msg.senderRole === 'ADMIN' || msg.senderRole === 'FACULTY' ? '16px 16px 4px 16px' : '16px 16px 16px 4px'"
                 style="padding:10px 14px;box-shadow:0 2px 4px rgba(0,0,0,0.06);">
              <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:4px;gap:8px;">
                <div style="display:flex;align-items:center;gap:6px;">
                  <strong style="font-size:11.5px;" [style.color]="msg.senderRole === 'ADMIN' || msg.senderRole === 'FACULTY' ? '#E0E7FF' : '#4338CA'">
                    {{ msg.senderName }}
                  </strong>
                  <span class="badge" style="font-size:9.5px;padding:1px 6px;"
                        [style.background]="msg.senderRole === 'ADMIN' || msg.senderRole === 'FACULTY' ? 'rgba(255,255,255,0.25)' : '#EEF2FF'"
                        [style.color]="msg.senderRole === 'ADMIN' || msg.senderRole === 'FACULTY' ? '#FFFFFF' : '#4338CA'">
                    {{ msg.senderRole }}
                  </span>
                </div>
                <span style="font-size:10.5px;" [style.color]="msg.senderRole === 'ADMIN' || msg.senderRole === 'FACULTY' ? 'rgba(255,255,255,0.7)' : '#94A3B8'">
                  {{ msg.createdAt | date:'shortTime' }}
                </span>
              </div>
              <div style="font-size:13.5px;line-height:1.45;white-space:pre-wrap;word-break:break-word;">{{ msg.content }}</div>
            </div>

          </div>
        </div>

        <!-- Compose Box -->
        <div style="border-top:1px solid #E2E8F0;padding-top:12px;margin-top:auto;">
          <div style="display:flex;gap:8px;margin-bottom:8px;align-items:center;">
            <span style="font-size:12px;font-weight:600;color:#64748B;">Message Type:</span>
            <button type="button" class="btn btn-sm" [class.btn-primary]="newMessageType === 'TEXT'" [class.btn-secondary]="newMessageType !== 'TEXT'" (click)="newMessageType = 'TEXT'">💬 Text</button>
            <button type="button" class="btn btn-sm" [class.btn-primary]="newMessageType === 'CODE'" [class.btn-secondary]="newMessageType !== 'CODE'" (click)="newMessageType = 'CODE'">💻 Code Snippet</button>
            <button type="button" class="btn btn-sm" [class.btn-primary]="newMessageType === 'ANNOUNCEMENT'" [class.btn-secondary]="newMessageType !== 'ANNOUNCEMENT'" (click)="newMessageType = 'ANNOUNCEMENT'">📢 Announcement</button>
          </div>
          <div style="display:flex;gap:8px;align-items:flex-end;">
            <textarea [(ngModel)]="newMessageText"
                      [placeholder]="newMessageType === 'ANNOUNCEMENT' ? 'Post an important announcement to all batch members...' : (newMessageType === 'CODE' ? 'Paste code snippet here...' : 'Type a message or answer student doubts...')"
                      rows="2"
                      (keydown.enter)="$event.preventDefault(); sendChatMessage()"
                      style="flex:1;padding:8px 12px;border:1px solid #CBD5E1;border-radius:8px;font-size:13px;resize:none;"></textarea>
            <button class="btn btn-primary" [disabled]="!newMessageText.trim() || sendingMessage" (click)="sendChatMessage()" style="padding:10px 18px;">
              {{ sendingMessage ? '...' : 'Send' }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Batch Detail / Manage Students Modal -->
    <div class="modal-overlay" *ngIf="showBatchDetail" (click)="closeBatchDetail($event)">
      <div class="modal-content" style="width:95%;max-width:850px;max-height:88vh;padding:24px;" (click)="$event.stopPropagation()">
        <div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:20px;gap:16px;">
          <div>
            <h2 style="font-size:20px;font-weight:700;margin:0 0 8px 0;">👥 {{selectedBatch?.name}}</h2>
            <div style="display:flex;gap:12px;flex-wrap:wrap;">
              <span style="font-size:13px;color:#64748B;" *ngIf="getPlanName(selectedBatch?.planId)">⭐ {{getPlanName(selectedBatch?.planId)}}</span>
              <span style="font-size:13px;color:#64748B;" *ngIf="selectedBatch?.startDate">📅 {{formatDate(selectedBatch?.startDate)}} → {{formatDate(selectedBatch?.endDate)}}</span>
              <span style="font-size:13px;color:#64748B;" *ngIf="selectedBatch?.maxStudents">👤 Max: {{selectedBatch?.maxStudents}}</span>
              <span style="font-size:13px;color:#64748B;" *ngIf="selectedBatch?.schedule">🕐 {{selectedBatch?.schedule}}</span>
            </div>
            <div style="margin-top:6px;font-size:13px;color:#64748B;" *ngIf="selectedBatch?.description">{{selectedBatch?.description}}</div>
          </div>
          <button class="btn btn-secondary btn-sm" (click)="closeBatchDetail()">✕</button>
        </div>

        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px;flex-wrap:wrap;gap:8px;">
          <h3 style="font-weight:700;font-size:16px;margin:0;">Students in this batch ({{batchStudents.length}})</h3>
          <button class="btn btn-primary" style="padding:6px 14px;font-size:12px;" (click)="showAddStudent = !showAddStudent">
            {{ showAddStudent ? 'Cancel' : '+ Add Student to Batch' }}
          </button>
        </div>

        <!-- Add student to batch -->
        <div *ngIf="showAddStudent" class="card" style="margin-bottom:16px;padding:16px;background:var(--surface-alt);">
          <div style="display:flex;gap:12px;align-items:center;flex-wrap:wrap;">
            <select [(ngModel)]="selectedStudentId" style="flex:1;min-width:220px;padding:10px;border:1px solid var(--border-light);border-radius:8px;font-size:14px;background:var(--surface);color:var(--text);">
              <option [ngValue]="null">Select a student to add...</option>
              <option *ngFor="let s of availableStudents" [ngValue]="s.id">{{s.name}} ({{s.email}})</option>
            </select>
            <button class="btn btn-primary" (click)="addStudentToBatch()" [disabled]="!selectedStudentId">Add</button>
          </div>
          <div *ngIf="availableStudents.length === 0" style="margin-top:8px;font-size:13px;color:#64748B;">All students are already in this batch or no students exist.</div>
        </div>

        <div *ngIf="loadingBatchStudents" style="text-align:center;padding:32px;color:#64748B;">
          <div style="font-size:14px;">Loading students in this batch...</div>
        </div>

        <div *ngIf="!loadingBatchStudents" class="card" style="padding:0;overflow:hidden;margin-bottom:0;">
          <div style="overflow-x:auto;width:100%;">
            <table style="width:100%;min-width:600px;">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Name</th>
                  <th>Email</th>
                  <th>Phone</th>
                  <th>Plan</th>
                  <th>Status</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                <tr *ngFor="let s of batchStudents">
                  <td>{{s.id}}</td>
                  <td style="font-weight:600;">{{s.name}}</td>
                  <td>{{s.email}}</td>
                  <td>{{s.phone || '-'}}</td>
                  <td>
                    <span *ngIf="getPlanName(s.planId)" class="badge badge-warning">⭐ {{getPlanName(s.planId)}}</span>
                    <span *ngIf="!getPlanName(s.planId)" style="color:#64748B;font-size:13px;">No plan</span>
                  </td>
                  <td>
                    <span class="badge" [class.badge-success]="s.isActive" [class.badge-danger]="!s.isActive">
                      {{s.isActive ? 'Active' : 'Inactive'}}
                    </span>
                  </td>
                  <td>
                    <button class="btn btn-danger" style="padding:4px 12px;font-size:12px;" (click)="removeStudentFromBatch(s)">Remove</button>
                  </td>
                </tr>
                <tr *ngIf="batchStudents.length === 0">
                  <td colspan="7" style="text-align:center;color:#64748B;padding:32px;">No students in this batch yet. Click "+ Add Student to Batch" to assign students.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  `,
  styles: [`
    .modal-overlay {
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(0,0,0,0.6);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 1000;
      padding: 16px;
      backdrop-filter: blur(4px);
    }
    .modal-content {
      background: var(--surface);
      color: var(--text);
      border-radius: 16px;
      padding: 24px;
      box-shadow: 0 20px 25px -5px rgba(0,0,0,0.2);
      max-height: 88vh;
      width: 95%;
      max-width: 800px;
      box-sizing: border-box;
      overflow-y: auto;
      display: flex;
      flex-direction: column;
    }
    .modal-content select, .modal-content input, .modal-content textarea {
      background: var(--surface);
      color: var(--text);
      border-color: var(--border-light);
    }
    @media (max-width: 768px) {
      .modal-content {
        padding: 16px;
        max-height: 94vh;
      }
    }
  `]
})
export class BatchesComponent implements OnInit {
  private api = inject(ApiService);
  private confirm = inject(ConfirmService);
  private errors = inject(ApiErrorService);

  batches: Batch[] = [];
  allStudents: Student[] = [];
  plans: SubscriptionPlan[] = [];
  faculty: Faculty[] = [];

  showModal = false;
  editingBatch: Batch | null = null;
  loading = false;
  errorMessage = '';
  batchTab: 'basic' | 'schedule' = 'basic';

  batchForm: any = {
    name: '',
    description: '',
    planId: null,
    startDate: '',
    endDate: '',
    isActive: true,
    maxStudents: null,
    schedule: '',
    mentorId: null
  };

  // Batch detail / manage students
  showBatchDetail = false;
  selectedBatch: Batch | null = null;
  batchStudents: Student[] = [];
  loadingBatchStudents = false;
  showAddStudent = false;
  selectedStudentId: number | null = null;

  // Batch Community Chat
  activeChatBatch: Batch | null = null;
  chatMessages: any[] = [];
  loadingChat = false;
  newMessageType: 'TEXT' | 'CODE' | 'ANNOUNCEMENT' = 'TEXT';
  newMessageText = '';
  sendingMessage = false;
  private chatPollInterval: any = null;

  openBatchChat(b: Batch) {
    this.activeChatBatch = b;
    this.chatMessages = [];
    this.newMessageType = 'TEXT';
    this.newMessageText = '';
    this.loadChatMessages(b.id);
    if (this.chatPollInterval) clearInterval(this.chatPollInterval);
    this.chatPollInterval = setInterval(() => {
      if (this.activeChatBatch) {
        this.loadChatMessages(this.activeChatBatch.id, true);
      }
    }, 3000);
  }

  closeBatchChat(event?: Event) {
    if (event && event.target !== event.currentTarget) return;
    this.activeChatBatch = null;
    this.chatMessages = [];
    if (this.chatPollInterval) {
      clearInterval(this.chatPollInterval);
      this.chatPollInterval = null;
    }
  }

  loadChatMessages(batchId: number, silent = false) {
    if (!silent) this.loadingChat = true;
    this.api.get<any[]>(`/api/chat/batch/${batchId}`).subscribe({
      next: (msgs) => {
        this.chatMessages = msgs || [];
        this.loadingChat = false;
      },
      error: (err) => {
        if (!silent) {
          console.error('Failed to load chat messages', err);
          this.loadingChat = false;
        }
      }
    });
  }

  sendChatMessage() {
    if (!this.activeChatBatch || !this.newMessageText.trim()) return;
    this.sendingMessage = true;
    const payload = {
      content: this.newMessageText.trim(),
      messageType: this.newMessageType,
      senderRole: 'ADMIN'
    };

    this.api.post<any>(`/api/chat/batch/${this.activeChatBatch.id}`, payload).subscribe({
      next: (saved) => {
        this.chatMessages.push(saved);
        this.newMessageText = '';
        this.sendingMessage = false;
      },
      error: (err) => {
        this.sendingMessage = false;
        this.errors.show(err, 'Could not send chat message');
      }
    });
  }

  ngOnDestroy() {
    if (this.chatPollInterval) {
      clearInterval(this.chatPollInterval);
      this.chatPollInterval = null;
    }
  }

  ngOnInit() {
    this.loadBatches();
    this.loadStudents();
    this.loadPlans();
    this.loadFaculty();
  }

  loadFaculty() {
    this.api.get<Faculty[]>('/api/faculty').subscribe({
      next: (data) => { this.faculty = data; },
      error: (err) => { console.error('Failed to load faculty', err); this.faculty = []; }
    });
  }

  getMentorName(mentorId?: number): string {
    if (!mentorId) return '';
    const f = this.faculty.find(x => x.id === mentorId);
    return f ? f.name : '';
  }

  loadBatches() {
    this.api.get<Batch[]>('/api/batches').subscribe({
      next: (data) => { this.batches = data; },
      error: (err) => { console.error('Failed to load batches', err); this.batches = []; }
    });
  }

  loadStudents() {
    this.api.get<Student[]>('/api/students').subscribe({
      next: (data) => { this.allStudents = data; },
      error: (err) => { console.error('Failed to load students', err); this.allStudents = []; }
    });
  }

  loadPlans() {
    this.api.get<SubscriptionPlan[]>('/api/subscription-plans/admin/all').subscribe({
      next: (data) => { this.plans = data; },
      error: (err) => { console.error('Failed to load subscription plans', err); this.plans = []; }
    });
  }

  getPlanName(planId?: number): string {
    if (!planId) return '';
    const plan = this.plans.find(p => p.id === planId);
    return plan ? plan.name : '';
  }

  formatDate(date?: string): string {
    if (!date) return '-';
    try {
      return new Date(date).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
    } catch {
      return date;
    }
  }

  getBatchStudentCount(batchId: number): number {
    return this.allStudents.filter(s => s.batchId === batchId).length;
  }

  openAddModal() {
    this.editingBatch = null;
    this.errorMessage = '';
    this.batchTab = 'basic';
    this.batchForm = {
      name: '',
      description: '',
      planId: null,
      startDate: '',
      endDate: '',
      isActive: true,
      maxStudents: null,
      schedule: '',
      mentorId: null
    };
    this.showModal = true;
  }

  openEditModal(batch: Batch) {
    this.editingBatch = batch;
    this.errorMessage = '';
    this.batchTab = 'basic';
    this.batchForm = {
      name: batch.name,
      description: batch.description || '',
      planId: batch.planId || null,
      startDate: batch.startDate ? new Date(batch.startDate).toISOString().slice(0, 16) : '',
      endDate: batch.endDate ? new Date(batch.endDate).toISOString().slice(0, 16) : '',
      isActive: batch.isActive,
      maxStudents: batch.maxStudents || null,
      schedule: batch.schedule || '',
      mentorId: batch.mentorId || null
    };
    this.showModal = true;
  }

  closeModal(event?: any) {
    this.showModal = false;
    this.editingBatch = null;
    this.errorMessage = '';
  }

  saveBatch() {
    if (!this.batchForm.name) {
      this.errorMessage = 'Batch name is required';
      return;
    }
    this.loading = true;
    this.errorMessage = '';

    const payload = { ...this.batchForm };

    if (this.editingBatch) {
      this.api.put(`/api/batches/${this.editingBatch.id}`, payload).subscribe({
        next: () => {
          this.loading = false;
          this.loadBatches();
          this.closeModal();
        },
        error: (err) => {
          this.loading = false;
          console.error('Failed to update batch', err);
          this.errorMessage = 'Failed to update batch. ' + (err.error?.message || 'Please check the details and try again.');
        }
      });
    } else {
      this.api.post('/api/batches', payload).subscribe({
        next: () => {
          this.loading = false;
          this.loadBatches();
          this.closeModal();
        },
        error: (err) => {
          this.loading = false;
          console.error('Failed to create batch', err);
          this.errorMessage = 'Failed to create batch. ' + (err.error?.message || 'Please check the details and try again.');
        }
      });
    }
  }

  async deleteBatch(batch: Batch) {
    if (!(await this.confirm.confirm(`Are you sure you want to delete batch "${batch.name}"? Students will remain but will be unassigned from this batch.`))) return;
    this.api.delete(`/api/batches/${batch.id}`).subscribe({
      next: () => { this.loadBatches(); },
      error: (err) => { this.errors.show(err, 'Failed to delete batch'); }
    });
  }

  // Batch detail / student management
  viewBatch(batch: Batch) {
    this.selectedBatch = batch;
    this.showAddStudent = false;
    this.selectedStudentId = null;
    this.showBatchDetail = true;
    this.loadBatchStudents(batch.id);
  }

  loadBatchStudents(batchId: number) {
    this.loadingBatchStudents = true;
    this.api.get<Student[]>(`/api/batches/${batchId}/students`).subscribe({
      next: (students) => {
        this.batchStudents = students || [];
        this.loadingBatchStudents = false;
      },
      error: (err) => {
        console.error('Failed to load batch students from API, using fallback', err);
        this.batchStudents = this.allStudents.filter(s => s.batchId === batchId);
        this.loadingBatchStudents = false;
      }
    });
  }

  closeBatchDetail(event?: any) {
    this.showBatchDetail = false;
    this.selectedBatch = null;
    this.batchStudents = [];
    this.showAddStudent = false;
    this.selectedStudentId = null;
  }

  get availableStudents(): Student[] {
    if (!this.selectedBatch) return [];
    const enrolledIds = new Set(this.batchStudents.map(s => s.id));
    return this.allStudents.filter(s => !enrolledIds.has(s.id));
  }

  addStudentToBatch() {
    if (!this.selectedBatch || !this.selectedStudentId) return;
    const student = this.allStudents.find(s => s.id === this.selectedStudentId);
    if (!student) return;

    this.api.put(`/api/students/${student.id}`, {
      name: student.name,
      email: student.email,
      phone: student.phone || '',
      isActive: student.isActive,
      planId: student.planId || null,
      batchId: this.selectedBatch.id
    }).subscribe({
      next: () => {
        this.loadStudents();
        if (this.selectedBatch) this.loadBatchStudents(this.selectedBatch.id);
        this.selectedStudentId = null;
        this.showAddStudent = false;
      },
      error: (err) => {
        this.errors.show(err, 'Failed to add student to batch');
      }
    });
  }

  async removeStudentFromBatch(student: Student) {
    if (!this.selectedBatch) return;
    if (!(await this.confirm.confirm(`Remove "${student.name}" from batch "${this.selectedBatch.name}"?`))) return;

    this.api.put(`/api/students/${student.id}`, {
      name: student.name,
      email: student.email,
      phone: student.phone || '',
      isActive: student.isActive,
      planId: student.planId || null,
      batchId: null
    }).subscribe({
      next: () => {
        this.loadStudents();
        if (this.selectedBatch) this.loadBatchStudents(this.selectedBatch.id);
      },
      error: (err) => {
        this.errors.show(err, 'Failed to remove student from batch');
      }
    });
  }
}
