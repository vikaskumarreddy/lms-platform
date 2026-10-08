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
    <!-- Top Bar on Desktop -->
    <div class="desktop-only" style="margin-bottom:16px;">
      <h1 style="font-size:22px;font-weight:700;margin:0;display:flex;align-items:center;gap:10px;">
        💬 Batch Community
        <span class="badge badge-success" style="font-size:12px;">Real-Time</span>
      </h1>
      <p style="color:#64748B;font-size:13px;margin:4px 0 0 0;">
        Direct communication and announcements with your assigned batches and students.
      </p>
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

    <!-- Main WhatsApp Container -->
    <div *ngIf="!loadingBatches && batches.length > 0" class="wa-container" [class.wa-mobile-chat-open]="mobileChatOpen">

      <!-- ================= LEFT: BATCH LIST (WhatsApp Chats Tab) ================= -->
      <div class="wa-sidebar">
        <!-- WhatsApp-styled Header -->
        <div class="wa-sidebar-header">
          <div style="display:flex;align-items:center;gap:10px;">
            <div class="wa-header-avatar">💬</div>
            <div>
              <div style="font-weight:700;font-size:16px;color:#fff;">Chats</div>
              <div style="font-size:11px;color:rgba(255,255,255,0.8);">{{ batches.length }} Batch Channels</div>
            </div>
          </div>
          <span class="badge" style="background:rgba(255,255,255,0.2);color:#fff;font-size:11px;">Active</span>
        </div>

        <!-- Search / Info Subbar -->
        <div class="wa-search-bar">
          <input type="text" [(ngModel)]="batchSearch" placeholder="Search or start new chat" class="wa-search-input">
        </div>

        <!-- Chat List Items -->
        <div class="wa-chat-list">
          <div *ngFor="let b of filteredBatches"
               (click)="selectBatch(b)"
               class="wa-chat-item"
               [class.active]="selectedBatch?.id === b.id">
            <div class="wa-avatar" [style.background]="getAvatarColor(b.name)">
              {{ (b.name || 'B').charAt(0).toUpperCase() }}
            </div>
            <div class="wa-chat-info">
              <div class="wa-chat-top">
                <span class="wa-chat-name">{{ b.name }}</span>
                <span class="wa-chat-badge" [class.badge-success]="b.isActive" [class.badge-danger]="!b.isActive">
                  {{ b.isActive ? 'Active' : 'Archived' }}
                </span>
              </div>
              <div class="wa-chat-bottom">
                <span class="wa-last-msg">
                  {{ b.schedule ? '⏱️ ' + b.schedule : 'Tap to open discussion' }}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- ================= RIGHT: CHAT WINDOW (WhatsApp Conversation) ================= -->
      <div class="wa-chat-window" *ngIf="selectedBatch">
        <!-- WhatsApp Chat Top Bar -->
        <div class="wa-chat-header">
          <!-- Back button on mobile to return to chat list -->
          <button type="button" class="wa-back-btn" (click)="backToBatchList()" title="Back to chats">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <line x1="19" y1="12" x2="5" y2="12"></line>
              <polyline points="12 19 5 12 12 5"></polyline>
            </svg>
          </button>

          <div class="wa-avatar" [style.background]="getAvatarColor(selectedBatch.name)" style="width:38px;height:38px;font-size:15px;flex-shrink:0;">
            {{ (selectedBatch.name || 'B').charAt(0).toUpperCase() }}
          </div>

          <div class="wa-header-details">
            <div class="wa-header-name">{{ selectedBatch.name }} Community</div>
            <div class="wa-header-status">
              <span class="wa-online-dot"></span> online · Faculty & Students
            </div>
          </div>

          <button class="wa-icon-action" (click)="loadMessages(selectedBatch.id)" [disabled]="loadingChat" title="Refresh messages">
            🔄
          </button>
        </div>

        <!-- WhatsApp Wallpaper Messages Body -->
        <div #chatScrollContainer class="wa-messages-body">
          <div class="wa-encryption-notice">
            🔒 Messages in this batch channel are visible to enrolled students and faculty mentors.
          </div>

          <div *ngIf="chatMessages.length === 0 && !loadingChat" style="text-align:center;color:#64748B;padding:40px 16px;">
            <div style="font-size:32px;margin-bottom:8px;">💬</div>
            <p style="font-size:13.5px;margin:0;">No messages yet. Say hello or post an announcement below!</p>
          </div>

          <!-- Message Bubbles -->
          <div *ngFor="let msg of chatMessages"
               class="wa-bubble-row"
               [class.wa-outgoing]="isFacultyOrAdmin(msg)"
               [class.wa-announcement]="msg.messageType === 'ANNOUNCEMENT'">

            <!-- ANNOUNCEMENT BANNER (Centered) -->
            <div *ngIf="msg.messageType === 'ANNOUNCEMENT'" class="wa-announcement-card">
              <div class="wa-announcement-head">
                <span>📢</span>
                <strong>ANNOUNCEMENT • {{ msg.senderName }}</strong>
                <span class="badge" style="background:#FDE68A;color:#92400E;font-size:10px;">{{ msg.senderRole }}</span>
                <span class="wa-time" style="margin-left:auto;">{{ msg.createdAt | date:'short' }}</span>
              </div>
              <div class="wa-announcement-body">{{ msg.content }}</div>
            </div>

            <!-- CODE SNIPPET -->
            <div *ngIf="msg.messageType === 'CODE'" class="wa-code-card">
              <div class="wa-code-header">
                <span style="color:#38BDF8;">💻 {{ msg.senderName }} ({{ msg.senderRole }})</span>
                <span class="wa-time">{{ msg.createdAt | date:'shortTime' }}</span>
              </div>
              <pre class="wa-code-block"><code>{{ msg.content }}</code></pre>
            </div>

            <!-- REGULAR WHATSAPP SPEECH BUBBLE -->
            <div *ngIf="msg.messageType !== 'ANNOUNCEMENT' && msg.messageType !== 'CODE'"
                 class="wa-bubble"
                 [class.wa-bubble-out]="isFacultyOrAdmin(msg)"
                 [class.wa-bubble-in]="!isFacultyOrAdmin(msg)">
              <div *ngIf="!isFacultyOrAdmin(msg)" class="wa-sender-label">
                {{ msg.senderName }}
                <span class="wa-sender-role">({{ msg.senderRole }})</span>
              </div>
              <div class="wa-msg-text">{{ msg.content }}</div>
              <div class="wa-bubble-meta">
                <span class="wa-time">{{ msg.createdAt | date:'shortTime' }}</span>
                <span *ngIf="isFacultyOrAdmin(msg)" class="wa-ticks">✓✓</span>
              </div>
            </div>

          </div>
        </div>

        <!-- WhatsApp Compose / Input Bar -->
        <div class="wa-footer">
          <!-- Quick Mode Pills -->
          <div class="wa-modes">
            <button type="button"
                    (click)="chatMessageType = (chatMessageType === 'ANNOUNCEMENT' ? 'TEXT' : 'ANNOUNCEMENT')"
                    [class.active]="chatMessageType === 'ANNOUNCEMENT'"
                    class="wa-mode-pill wa-mode-announcement">
              📢 Announcement
            </button>
            <button type="button"
                    (click)="chatMessageType = (chatMessageType === 'CODE' ? 'TEXT' : 'CODE')"
                    [class.active]="chatMessageType === 'CODE'"
                    class="wa-mode-pill wa-mode-code">
              💻 Code Snippet
            </button>
            <span *ngIf="chatMessageType !== 'TEXT'" class="wa-mode-indicator">
              Mode: {{ chatMessageType }}
            </span>
          </div>

          <!-- Input Row -->
          <div class="wa-input-row">
            <textarea [(ngModel)]="newChatMessage"
                      (keydown.enter)="onEnterPress($event)"
                      rows="1"
                      placeholder="Type a message..."
                      class="wa-input-field">
            </textarea>
            <button type="button"
                    (click)="sendMessage()"
                    [disabled]="sendingMessage || !newChatMessage.trim()"
                    class="wa-send-btn"
                    title="Send message">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <line x1="22" y1="2" x2="11" y2="13"></line>
                <polygon points="22 2 15 22 11 13 2 9 22 2"></polygon>
              </svg>
            </button>
          </div>
        </div>

      </div>

    </div>
  `,
  styles: [`
    /* ================= WhatsApp Container Layout ================= */
    .wa-container {
      display: grid;
      grid-template-columns: 340px 1fr;
      height: calc(100vh - 120px);
      min-height: 520px;
      max-height: 900px;
      background: #FFFFFF;
      border-radius: 14px;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
      overflow: hidden;
      border: 1px solid #E2E8F0;
    }

    /* --- Sidebar: Batch list --- */
    .wa-sidebar {
      background: #FFFFFF;
      border-right: 1px solid #E2E8F0;
      display: flex;
      flex-direction: column;
      height: 100%;
      overflow: hidden;
    }
    .wa-sidebar-header {
      background: #008069;
      color: #FFFFFF;
      padding: 14px 16px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-shrink: 0;
    }
    .wa-header-avatar {
      width: 36px;
      height: 36px;
      border-radius: 50%;
      background: rgba(255, 255, 255, 0.2);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 18px;
    }
    .wa-search-bar {
      padding: 8px 12px;
      background: #F0F2F5;
      border-bottom: 1px solid #E2E8F0;
      flex-shrink: 0;
    }
    .wa-search-input {
      width: 100%;
      box-sizing: border-box;
      padding: 7px 12px;
      border-radius: 8px;
      border: 1px solid #E2E8F0;
      background: #FFFFFF;
      font-size: 13px;
      outline: none;
    }
    .wa-chat-list {
      flex: 1;
      overflow-y: auto;
      background: #FFFFFF;
    }
    .wa-chat-item {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 12px 16px;
      cursor: pointer;
      border-bottom: 1px solid #F0F2F5;
      transition: background 0.15s ease;
    }
    .wa-chat-item:hover {
      background: #F5F7FB;
    }
    .wa-chat-item.active {
      background: #EBF7F4;
      border-left: 4px solid #00A884;
    }
    .wa-avatar {
      width: 44px;
      height: 44px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: 700;
      color: #FFFFFF;
      font-size: 17px;
      flex-shrink: 0;
    }
    .wa-chat-info {
      flex: 1;
      min-width: 0;
    }
    .wa-chat-top {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 3px;
    }
    .wa-chat-name {
      font-weight: 700;
      font-size: 14.5px;
      color: #111B21;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .wa-chat-badge {
      font-size: 10.5px;
      padding: 2px 7px;
      border-radius: 10px;
    }
    .wa-chat-bottom {
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .wa-last-msg {
      font-size: 12.5px;
      color: #667781;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    /* --- Chat Window --- */
    .wa-chat-window {
      display: flex;
      flex-direction: column;
      height: 100%;
      background: #EFEAE2;
      overflow: hidden;
    }
    .wa-chat-header {
      background: #008069;
      color: #FFFFFF;
      padding: 10px 16px;
      display: flex;
      align-items: center;
      gap: 12px;
      flex-shrink: 0;
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
    }
    .wa-back-btn {
      display: none;
      background: none;
      border: none;
      color: #FFFFFF;
      padding: 4px;
      cursor: pointer;
      align-items: center;
      justify-content: center;
    }
    .wa-header-details {
      flex: 1;
      min-width: 0;
    }
    .wa-header-name {
      font-weight: 700;
      font-size: 15.5px;
      color: #FFFFFF;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .wa-header-status {
      font-size: 11.5px;
      color: rgba(255, 255, 255, 0.85);
      display: flex;
      align-items: center;
      gap: 4px;
    }
    .wa-online-dot {
      width: 7px;
      height: 7px;
      border-radius: 50%;
      background: #25D366;
      display: inline-block;
    }
    .wa-icon-action {
      background: rgba(255, 255, 255, 0.15);
      border: none;
      color: #FFFFFF;
      border-radius: 8px;
      padding: 6px 10px;
      font-size: 14px;
      cursor: pointer;
    }

    /* --- Messages Body (WhatsApp Wallpaper) --- */
    .wa-messages-body {
      flex: 1;
      overflow-y: auto;
      padding: 16px 20px;
      display: flex;
      flex-direction: column;
      gap: 10px;
      background-color: #EFEAE2;
      background-image: radial-gradient(#D5CEBE 1px, transparent 1px);
      background-size: 20px 20px;
    }
    .wa-encryption-notice {
      align-self: center;
      background: #FFEECD;
      color: #54656F;
      font-size: 11px;
      padding: 6px 14px;
      border-radius: 8px;
      box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
      text-align: center;
      max-width: 85%;
      margin-bottom: 6px;
    }
    .wa-bubble-row {
      display: flex;
      flex-direction: column;
      align-self: flex-start;
      max-width: 75%;
    }
    .wa-bubble-row.wa-outgoing {
      align-self: flex-end;
    }
    .wa-bubble-row.wa-announcement {
      align-self: center;
      max-width: 90%;
      width: 100%;
    }

    /* Bubbles */
    .wa-bubble {
      padding: 8px 12px 6px 12px;
      border-radius: 8px;
      box-shadow: 0 1px 2px rgba(0, 0, 0, 0.12);
      position: relative;
      word-break: break-word;
    }
    .wa-bubble-in {
      background: #FFFFFF;
      color: #111B21;
      border-top-left-radius: 0;
    }
    .wa-bubble-out {
      background: #D9FDD3;
      color: #111B21;
      border-top-right-radius: 0;
    }
    .wa-sender-label {
      font-size: 12px;
      font-weight: 700;
      color: #128C7E;
      margin-bottom: 3px;
    }
    .wa-sender-role {
      font-size: 10px;
      font-weight: 400;
      color: #667781;
    }
    .wa-msg-text {
      font-size: 13.5px;
      line-height: 1.4;
      white-space: pre-wrap;
    }
    .wa-bubble-meta {
      display: flex;
      align-items: center;
      justify-content: flex-end;
      gap: 3px;
      margin-top: 2px;
    }
    .wa-time {
      font-size: 10.5px;
      color: #667781;
    }
    .wa-ticks {
      font-size: 11px;
      color: #53BDEB;
      font-weight: 700;
    }

    /* Announcement & Code special styles */
    .wa-announcement-card {
      background: #FFFBEB;
      border: 1px solid #FCD34D;
      border-radius: 10px;
      padding: 10px 14px;
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.08);
    }
    .wa-announcement-head {
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 12px;
      color: #92400E;
      margin-bottom: 4px;
    }
    .wa-announcement-body {
      font-size: 13px;
      color: #78350F;
      line-height: 1.45;
      white-space: pre-wrap;
    }
    .wa-code-card {
      background: #111B21;
      color: #F8FAFC;
      border-radius: 10px;
      box-shadow: 0 2px 5px rgba(0, 0, 0, 0.15);
      overflow: hidden;
      min-width: 260px;
    }
    .wa-code-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      background: #0B141A;
      padding: 6px 12px;
      font-size: 11px;
    }
    .wa-code-block {
      margin: 0;
      padding: 10px 12px;
      font-family: monospace;
      font-size: 12px;
      color: #38BDF8;
      background: #030712;
      overflow-x: auto;
    }

    /* --- WhatsApp Input Footer --- */
    .wa-footer {
      background: #F0F2F5;
      border-top: 1px solid #E2E8F0;
      padding: 8px 12px;
      flex-shrink: 0;
    }
    .wa-modes {
      display: flex;
      align-items: center;
      gap: 6px;
      margin-bottom: 6px;
      flex-wrap: wrap;
    }
    .wa-mode-pill {
      border: 1px solid #CBD5E1;
      background: #FFFFFF;
      color: #475569;
      padding: 3px 8px;
      border-radius: 14px;
      font-size: 11px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.15s;
    }
    .wa-mode-pill.active {
      background: #008069;
      color: #FFFFFF;
      border-color: #008069;
    }
    .wa-mode-indicator {
      font-size: 10.5px;
      color: #008069;
      font-weight: 600;
    }
    .wa-input-row {
      display: flex;
      align-items: flex-end;
      gap: 8px;
    }
    .wa-input-field {
      flex: 1;
      border: none;
      outline: none;
      background: #FFFFFF;
      border-radius: 20px;
      padding: 10px 16px;
      font-size: 14px;
      font-family: inherit;
      resize: none;
      box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
      max-height: 100px;
      line-height: 1.35;
      box-sizing: border-box;
    }
    .wa-send-btn {
      width: 42px;
      height: 42px;
      border-radius: 50%;
      background: #00A884;
      color: #FFFFFF;
      border: none;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      flex-shrink: 0;
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.15);
      transition: background 0.15s ease;
    }
    .wa-send-btn:hover {
      background: #008069;
    }
    .wa-send-btn:disabled {
      background: #94A3B8;
      cursor: not-allowed;
    }

    /* ================= Responsive Master-Detail Breakpoint ================= */
    @media (max-width: 768px) {
      .wa-container {
        grid-template-columns: 1fr;
        height: calc(100vh - 120px);
        border-radius: 10px;
      }
      /* By default on mobile: Show list, hide chat window */
      .wa-sidebar {
        display: flex;
        width: 100%;
      }
      .wa-chat-window {
        display: none;
        width: 100%;
      }
      /* When a chat is opened on mobile: Hide list, show chat window */
      .wa-container.wa-mobile-chat-open .wa-sidebar {
        display: none;
      }
      .wa-container.wa-mobile-chat-open .wa-chat-window {
        display: flex;
      }
      .wa-back-btn {
        display: inline-flex;
      }
      .wa-bubble-row {
        max-width: 88%;
      }
    }
  `]
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
  batchSearch = '';
  mobileChatOpen = false;
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

  get filteredBatches(): Batch[] {
    if (!this.batchSearch.trim()) return this.batches;
    const q = this.batchSearch.toLowerCase();
    return this.batches.filter(b => (b.name && b.name.toLowerCase().includes(q)) || (b.schedule && b.schedule.toLowerCase().includes(q)));
  }

  loadBatches() {
    this.loadingBatches = true;
    this.api.get<Batch[]>('/api/batches').subscribe({
      next: (data) => {
        this.batches = data || [];
        this.loadingBatches = false;
        // On desktop, auto-select first batch; on mobile, wait for user tap
        if (this.batches.length > 0 && !this.selectedBatch) {
          if (window.innerWidth >= 769) {
            this.selectBatch(this.batches[0]);
          }
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
    this.mobileChatOpen = true;
    this.loadMessages(batch.id);
  }

  backToBatchList() {
    this.mobileChatOpen = false;
  }

  getAvatarColor(name?: string): string {
    const colors = ['#00A884', '#128C7E', '#25D366', '#0284C7', '#6366F1', '#D97706', '#DC2626'];
    if (!name) return colors[0];
    let hash = 0;
    for (let i = 0; i < name.length; i++) hash += name.charCodeAt(i);
    return colors[hash % colors.length];
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

