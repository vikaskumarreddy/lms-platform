import { Component, OnInit, OnDestroy, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';
import { ApiErrorService } from '../../services/api-error.service';

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
}

interface ChatMessage {
  id: number;
  batchId: number;
  senderId: number;
  senderName: string;
  senderRole: string;
  content: string;
  messageType?: string;
  createdAt?: string;
}

@Component({
  selector: 'app-batch-community',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:20px;">
      <div>
        <h1 style="font-size:24px;font-weight:700;margin:0;display:flex;align-items:center;gap:10px;">
          💬 Batch Community
          <span class="badge badge-success" style="font-size:12px;">Real-Time</span>
        </h1>
        <p style="color:#64748B;font-size:13px;margin:4px 0 0 0;">
          Direct communication and announcements with your assigned batches and students.
        </p>
      </div>
    </div>

    <!-- Loading State -->
    <div *ngIf="loadingBatches" style="padding:40px;text-align:center;color:#64748B;">
      Loading assigned batches...
    </div>

    <!-- Empty State -->
    <div *ngIf="!loadingBatches && batches.length === 0" class="card" style="padding:40px;text-align:center;color:#64748B;">
      <div style="font-size:40px;margin-bottom:12px;">👥</div>
      <h3 style="font-size:18px;font-weight:600;color:#1E293B;margin-bottom:6px;">No Batches Assigned</h3>
      <p style="font-size:14px;max-width:400px;margin:0 auto;">
        You currently have no batches assigned to your faculty profile. Please contact an administrator to be assigned as a batch mentor.
      </p>
    </div>

    <!-- Main Layout: Batch Selector on Left, Chat Channel on Right -->
    <div *ngIf="!loadingBatches && batches.length > 0" style="display:grid;grid-template-columns:280px 1fr;gap:20px;height:calc(100vh - 160px);min-height:550px;">
      <!-- Batch List Column -->
      <div class="card" style="display:flex;flex-direction:column;padding:16px;overflow-y:auto;height:100%;box-sizing:border-box;">
        <h2 style="font-size:14px;font-weight:700;color:#64748B;text-transform:uppercase;letter-spacing:0.5px;margin:0 0 12px 0;">
          My Batches ({{ batches.length }})
        </h2>

        <div style="display:flex;flex-direction:column;gap:8px;">
          <div *ngFor="let b of batches"
               (click)="selectBatch(b)"
               [style.background]="selectedBatch?.id === b.id ? '#EEF2FF' : '#F8FAFC'"
               [style.border-color]="selectedBatch?.id === b.id ? '#6366F1' : '#E2E8F0'"
               style="padding:12px 14px;border-radius:10px;border-width:1.5px;border-style:solid;cursor:pointer;transition:all 0.15s ease;">
            <div style="display:flex;justify-content:space-between;align-items:center;">
              <strong [style.color]="selectedBatch?.id === b.id ? '#4338CA' : '#1E293B'" style="font-size:14px;">
                {{ b.name }}
              </strong>
              <span class="badge" [ngClass]="b.isActive ? 'badge-success' : 'badge-danger'" style="font-size:10px;">
                {{ b.isActive ? 'Active' : 'Archived' }}
              </span>
            </div>
            <div *ngIf="b.schedule" style="font-size:12px;color:#64748B;margin-top:4px;">
              ⏱️ {{ b.schedule }}
            </div>
          </div>
        </div>
      </div>

      <!-- Chat Channel Column -->
      <div class="card" style="display:flex;flex-direction:column;padding:0;height:100%;overflow:hidden;box-sizing:border-box;" *ngIf="selectedBatch">
        <!-- Channel Header -->
        <div style="padding:16px 20px;border-bottom:1px solid #E2E8F0;background:#FFFFFF;display:flex;justify-content:space-between;align-items:center;">
          <div>
            <div style="display:flex;align-items:center;gap:10px;">
              <h2 style="font-size:18px;font-weight:700;margin:0;color:#0F172A;">
                💬 {{ selectedBatch.name }} Community
              </h2>
              <span class="badge badge-success" style="font-size:11px;">🟢 Online</span>
            </div>
            <div style="font-size:12.5px;color:#64748B;margin-top:2px;">
              Faculty & Student discussion channel
            </div>
          </div>
          <button class="btn btn-secondary btn-sm" (click)="loadMessages(selectedBatch.id)" [disabled]="loadingChat">
            🔄 Refresh
          </button>
        </div>

        <!-- Chat Messages Area -->
        <div #chatScrollContainer style="flex:1;overflow-y:auto;padding:20px;display:flex;flex-direction:column;gap:14px;background:#F8FAFC;">
          <div *ngIf="chatMessages.length === 0 && !loadingChat" style="text-align:center;color:#94A3B8;padding:60px 20px;">
            <div style="font-size:36px;margin-bottom:8px;">💭</div>
            <p style="font-size:14px;margin:0;">No messages yet in this batch channel. Start the discussion below!</p>
          </div>

          <div *ngFor="let msg of chatMessages"
               [style.align-self]="msg.messageType === 'ANNOUNCEMENT' ? 'center' : (isFacultyOrAdmin(msg) ? 'flex-end' : 'flex-start')"
               [style.max-width]="msg.messageType === 'ANNOUNCEMENT' ? '96%' : '72%'"
               style="display:flex;flex-direction:column;">

            <!-- ANNOUNCEMENT BANNER -->
            <div *ngIf="msg.messageType === 'ANNOUNCEMENT'"
                 style="background:#FFFBEB;border:1.5px solid #FCD34D;border-radius:12px;padding:12px 18px;box-shadow:0 2px 4px rgba(0,0,0,0.06);width:100%;box-sizing:border-box;">
              <div style="display:flex;align-items:center;gap:8px;margin-bottom:6px;">
                <span style="font-size:16px;">📢</span>
                <strong style="font-size:13px;color:#92400E;">FACULTY ANNOUNCEMENT • {{ msg.senderName }}</strong>
                <span class="badge" style="background:#FDE68A;color:#92400E;font-size:10px;">{{ msg.senderRole }}</span>
                <span style="font-size:11px;color:#B45309;margin-left:auto;">{{ msg.createdAt | date:'short' }}</span>
              </div>
              <div style="font-size:13.5px;color:#78350F;line-height:1.5;white-space:pre-wrap;">{{ msg.content }}</div>
            </div>

            <!-- CODE SNIPPET -->
            <div *ngIf="msg.messageType === 'CODE'"
                 style="background:#1E293B;color:#F8FAFC;border-radius:12px;box-shadow:0 3px 6px rgba(0,0,0,0.15);overflow:hidden;min-width:300px;">
              <div style="display:flex;justify-content:space-between;align-items:center;background:#0F172A;padding:8px 12px;border-bottom:1px solid #334155;">
                <div style="display:flex;align-items:center;gap:6px;">
                  <span style="font-size:13px;color:#38BDF8;">💻</span>
                  <span style="font-size:11.5px;font-weight:600;color:#CBD5E1;">{{ msg.senderName }}</span>
                  <span class="badge" [style.background]="isFacultyOrAdmin(msg) ? '#818CF8' : '#38BDF8'" style="color:#0F172A;font-size:9.5px;font-weight:700;">{{ msg.senderRole }}</span>
                </div>
                <span style="font-size:10.5px;color:#94A3B8;">{{ msg.createdAt | date:'shortTime' }}</span>
              </div>
              <pre style="margin:0;padding:12px 14px;font-family:monospace;font-size:12.5px;overflow-x:auto;line-height:1.5;color:#38BDF8;background:#030712;"><code>{{ msg.content }}</code></pre>
            </div>

            <!-- REGULAR TEXT BUBBLE -->
            <div *ngIf="msg.messageType !== 'ANNOUNCEMENT' && msg.messageType !== 'CODE'"
                 [style.background]="isFacultyOrAdmin(msg) ? '#4F46E5' : '#FFFFFF'"
                 [style.color]="isFacultyOrAdmin(msg) ? '#FFFFFF' : '#1E293B'"
                 [style.border]="isFacultyOrAdmin(msg) ? 'none' : '1px solid #E2E8F0'"
                 style="padding:10px 14px;border-radius:12px;box-shadow:0 1px 3px rgba(0,0,0,0.06);line-height:1.45;">
              <div style="display:flex;justify-content:space-between;align-items:center;gap:12px;margin-bottom:4px;">
                <div style="display:flex;align-items:center;gap:6px;">
                  <strong style="font-size:11.5px;" [style.color]="isFacultyOrAdmin(msg) ? '#E0E7FF' : '#475569'">
                    {{ msg.senderName }}
                  </strong>
                  <span class="badge"
                        [style.background]="isFacultyOrAdmin(msg) ? 'rgba(255,255,255,0.2)' : '#E2E8F0'"
                        [style.color]="isFacultyOrAdmin(msg) ? '#FFFFFF' : '#475569'"
                        style="font-size:9px;padding:2px 5px;">
                    {{ msg.senderRole }}
                  </span>
                </div>
                <span style="font-size:10px;" [style.color]="isFacultyOrAdmin(msg) ? '#C7D2FE' : '#94A3B8'">
                  {{ msg.createdAt | date:'shortTime' }}
                </span>
              </div>
              <div style="font-size:13.5px;white-space:pre-wrap;">{{ msg.content }}</div>
            </div>
          </div>
        </div>

        <!-- Compose / Input Area -->
        <div style="padding:14px 18px;border-top:1px solid #E2E8F0;background:#FFFFFF;">
          <!-- Format Controls -->
          <div style="display:flex;align-items:center;gap:10px;margin-bottom:8px;">
            <button type="button"
                    (click)="chatMessageType = (chatMessageType === 'ANNOUNCEMENT' ? 'TEXT' : 'ANNOUNCEMENT')"
                    [style.background]="chatMessageType === 'ANNOUNCEMENT' ? '#FEF3C7' : '#F1F5F9'"
                    [style.border-color]="chatMessageType === 'ANNOUNCEMENT' ? '#F59E0B' : '#CBD5E1'"
                    [style.color]="chatMessageType === 'ANNOUNCEMENT' ? '#B45309' : '#475569'"
                    style="border:1px solid;border-radius:6px;padding:4px 10px;font-size:11.5px;font-weight:600;cursor:pointer;">
              📢 Announcement Mode
            </button>
            <button type="button"
                    (click)="chatMessageType = (chatMessageType === 'CODE' ? 'TEXT' : 'CODE')"
                    [style.background]="chatMessageType === 'CODE' ? '#E0F2FE' : '#F1F5F9'"
                    [style.border-color]="chatMessageType === 'CODE' ? '#0284C7' : '#CBD5E1'"
                    [style.color]="chatMessageType === 'CODE' ? '#0369A1' : '#475569'"
                    style="border:1px solid;border-radius:6px;padding:4px 10px;font-size:11.5px;font-weight:600;cursor:pointer;">
              💻 Code Snippet Mode
            </button>
            <span *ngIf="chatMessageType !== 'TEXT'" style="font-size:11px;color:#64748B;">
              (Active: {{ chatMessageType }})
            </span>
          </div>

          <!-- Input Row -->
          <div style="display:flex;gap:10px;">
            <textarea [(ngModel)]="newChatMessage"
                      (keydown.enter)="onEnterPress($event)"
                      rows="2"
                      placeholder="Type your message, query, or announcement to this batch... (Shift+Enter for new line)"
                      style="flex:1;border:1px solid #CBD5E1;border-radius:8px;padding:10px 12px;font-size:13.5px;font-family:inherit;resize:none;outline:none;">
            </textarea>
            <button class="btn btn-primary"
                    (click)="sendMessage()"
                    [disabled]="sendingMessage || !newChatMessage.trim()"
                    style="min-width:100px;align-self:stretch;">
              {{ sendingMessage ? 'Sending...' : 'Send' }}
            </button>
          </div>
        </div>
      </div>
    </div>
  `
})
export class BatchCommunityComponent implements OnInit, OnDestroy {
  private api = inject(ApiService);
  private errors = inject(ApiErrorService);

  batches: Batch[] = [];
  selectedBatch: Batch | null = null;
  chatMessages: ChatMessage[] = [];

  loadingBatches = true;
  loadingChat = false;
  sendingMessage = false;

  newChatMessage = '';
  chatMessageType = 'TEXT';
  private pollInterval: any = null;

  ngOnInit() {
    this.loadBatches();
    // Poll active chat every 4 seconds
    this.pollInterval = setInterval(() => {
      if (this.selectedBatch) {
        this.loadMessages(this.selectedBatch.id, true);
      }
    }, 4000);
  }

  ngOnDestroy() {
    if (this.pollInterval) {
      clearInterval(this.pollInterval);
    }
  }

  loadBatches() {
    this.loadingBatches = true;
    this.api.get<Batch[]>('/api/batches').subscribe({
      next: (data) => {
        this.batches = data || [];
        this.loadingBatches = false;
        if (this.batches.length > 0 && !this.selectedBatch) {
          this.selectBatch(this.batches[0]);
        }
      },
      error: (err) => {
        this.errors.show(err, 'Failed to load batches');
        this.loadingBatches = false;
      }
    });
  }

  selectBatch(batch: Batch) {
    this.selectedBatch = batch;
    this.loadMessages(batch.id);
  }

  loadMessages(batchId: number, silent = false) {
    if (!silent) this.loadingChat = true;
    this.api.get<ChatMessage[]>(`/api/chat/batch/${batchId}`).subscribe({
      next: (msgs) => {
        this.chatMessages = msgs || [];
        this.loadingChat = false;
      },
      error: (err) => {
        if (!silent) this.errors.show(err, 'Failed to load batch chat');
        this.loadingChat = false;
      }
    });
  }

  isFacultyOrAdmin(msg: ChatMessage): boolean {
    const role = (msg.senderRole || '').toUpperCase();
    return role === 'ADMIN' || role === 'FACULTY' || role === 'INSTRUCTOR' || role === 'SUPER_ADMIN';
  }

  onEnterPress(event: Event) {
    const ke = event as KeyboardEvent;
    if (!ke.shiftKey) {
      ke.preventDefault();
      this.sendMessage();
    }
  }

  sendMessage() {
    if (!this.selectedBatch || !this.newChatMessage.trim() || this.sendingMessage) return;

    this.sendingMessage = true;
    const payload = {
      batchId: this.selectedBatch.id,
      content: this.newChatMessage.trim(),
      messageType: this.chatMessageType
    };

    this.api.post<ChatMessage>(`/api/chat/batch/${this.selectedBatch.id}`, payload).subscribe({
      next: (saved) => {
        this.chatMessages.push(saved);
        this.newChatMessage = '';
        this.chatMessageType = 'TEXT';
        this.sendingMessage = false;
      },
      error: (err) => {
        this.errors.show(err, 'Failed to send message');
        this.sendingMessage = false;
      }
    });
  }
}
