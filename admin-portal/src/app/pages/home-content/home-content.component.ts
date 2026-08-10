import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

@Component({
  selector: 'app-home-content',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div style="margin-bottom:24px;">
      <h1 style="font-size:24px;font-weight:700;">🏠 Home Content</h1>
      <p style="color:#64748B;">Manage the content displayed on the mobile app home screen</p>
    </div>

    <!-- Welcome Banner -->
    <div class="card" style="margin-bottom:20px;">
      <h3 style="font-weight:700;margin-bottom:16px;">Welcome Banner</h3>
      <div style="display:grid;gap:16px;">
        <input [(ngModel)]="banner.title" placeholder="Banner Title" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <input [(ngModel)]="banner.subtitle" placeholder="Banner Subtitle" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <input [(ngModel)]="banner.buttonText" placeholder="Button Text" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
        <input [(ngModel)]="banner.buttonLink" placeholder="Button Link (route)" style="width:100%;padding:10px;border:1px solid #E2E8F0;border-radius:8px;">
      </div>
      <button class="btn btn-primary" style="margin-top:16px;" (click)="saveBanner()">Save Banner</button>
    </div>

    <!-- Quick Stats -->
    <div class="card" style="margin-bottom:20px;">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px;">
        <h3 style="font-weight:700;">Quick Stats</h3>
        <button class="btn btn-primary" (click)="addStat()">+ Add Stat</button>
      </div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;">
        <div *ngFor="let s of stats; let i = index" style="display:flex;gap:8px;align-items:center;">
          <input [(ngModel)]="s.label" placeholder="Label" style="flex:1;padding:8px;border:1px solid #E2E8F0;border-radius:8px;">
          <input [(ngModel)]="s.value" placeholder="Value" style="width:80px;padding:8px;border:1px solid #E2E8F0;border-radius:8px;">
          <input [(ngModel)]="s.icon" placeholder="Icon" style="width:60px;padding:8px;border:1px solid #E2E8F0;border-radius:8px;">
          <button class="btn" style="background:#FEE2E2;color:#991B1B;padding:8px;" (click)="removeStat(i)">✕</button>
        </div>
      </div>
      <button class="btn btn-primary" style="margin-top:16px;" (click)="saveStats()">Save Stats</button>
    </div>

    <!-- Quick Links -->
    <div class="card" style="margin-bottom:20px;">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px;">
        <h3 style="font-weight:700;">Quick Links</h3>
        <button class="btn btn-primary" (click)="addLink()">+ Add Link</button>
      </div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;">
        <div *ngFor="let l of quickLinks; let i = index" style="display:flex;gap:8px;align-items:center;">
          <input [(ngModel)]="l.title" placeholder="Title" style="flex:1;padding:8px;border:1px solid #E2E8F0;border-radius:8px;">
          <input [(ngModel)]="l.route" placeholder="Route" style="flex:1;padding:8px;border:1px solid #E2E8F0;border-radius:8px;">
          <input [(ngModel)]="l.icon" placeholder="Icon" style="width:60px;padding:8px;border:1px solid #E2E8F0;border-radius:8px;">
          <button class="btn" style="background:#FEE2E2;color:#991B1B;padding:8px;" (click)="removeLink(i)">✕</button>
        </div>
      </div>
      <button class="btn btn-primary" style="margin-top:16px;" (click)="saveLinks()">Save Links</button>
    </div>

    <!-- Upcoming Items -->
    <div class="card">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px;">
        <h3 style="font-weight:700;">Upcoming Items</h3>
        <button class="btn btn-primary" (click)="addUpcoming()">+ Add Item</button>
      </div>
      <div style="display:grid;gap:12px;">
        <div *ngFor="let u of upcoming; let i = index" style="display:flex;gap:8px;align-items:center;">
          <input [(ngModel)]="u.title" placeholder="Title" style="flex:1;padding:8px;border:1px solid #E2E8F0;border-radius:8px;">
          <input [(ngModel)]="u.date" placeholder="Date" style="width:120px;padding:8px;border:1px solid #E2E8F0;border-radius:8px;">
          <select [(ngModel)]="u.type" style="width:120px;padding:8px;border:1px solid #E2E8F0;border-radius:8px;">
            <option value="Class">Class</option><option value="Exam">Exam</option><option value="Assignment">Assignment</option><option value="Event">Event</option>
          </select>
          <button class="btn" style="background:#FEE2E2;color:#991B1B;padding:8px;" (click)="removeUpcoming(i)">✕</button>
        </div>
      </div>
      <button class="btn btn-primary" style="margin-top:16px;" (click)="saveUpcoming()">Save Items</button>
    </div>
  `
})
export class HomeContentComponent {
  banner = { title: 'Welcome back, Student!', subtitle: 'Continue your learning journey', buttonText: 'Resume Learning', buttonLink: '/courses' };
  
  stats: any[] = [
    { label: 'Courses', value: '5', icon: '📚' },
    { label: 'Assignments', value: '3', icon: '📝' },
    { label: 'Attendance', value: '85%', icon: '✅' },
    { label: 'Achievements', value: '12', icon: '🏆' },
  ];

  quickLinks: any[] = [
    { title: 'Courses', route: '/courses', icon: '📚' },
    { title: 'Calendar', route: '/calendar', icon: '📅' },
    { title: 'Placements', route: '/placements', icon: '💼' },
    { title: 'Assignments', route: '/assignments', icon: '📝' },
    { title: 'Achievements', route: '/achievements', icon: '🏆' },
    { title: 'Q&A', route: '/qa', icon: '💬' },
  ];

  upcoming: any[] = [
    { title: 'Live Class - Java Basics', date: '28 Jul', type: 'Class' },
    { title: 'Java Mid-Term Exam', date: '20 Jan', type: 'Exam' },
    { title: 'OOP Assignment Due', date: '20 Jan', type: 'Assignment' },
  ];

  addStat() { this.stats.push({ label: '', value: '', icon: '📊' }); }
  removeStat(i: number) { this.stats.splice(i, 1); }
  saveStats() { alert('Stats saved!'); }

  addLink() { this.quickLinks.push({ title: '', route: '', icon: '🔗' }); }
  removeLink(i: number) { this.quickLinks.splice(i, 1); }
  saveLinks() { alert('Quick links saved!'); }

  addUpcoming() { this.upcoming.push({ title: '', date: '', type: 'Class' }); }
  removeUpcoming(i: number) { this.upcoming.splice(i, 1); }
  saveUpcoming() { alert('Upcoming items saved!'); }

  saveBanner() { alert('Banner saved!'); }
}