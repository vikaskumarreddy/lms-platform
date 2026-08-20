import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { ApiService } from '../../services/api.service';

interface Course {
  id: number;
  title: string;
  description: string;
  thumbnailUrl: string;
  instructorId?: number;
  instructorName?: string;
  isPublished: boolean;
  planId?: number;
  modules: any[];
  studentsCount?: number;
  lessonsCount?: number;
}

interface SubscriptionPlan {
  id: number;
  name: string;
  price: number;
  period: string;
}

interface Faculty {
  id: number;
  name: string;
  email: string;
}

/**
 * Courses list page. Clicking a course now navigates to a dedicated
 * Course Detail page (/courses/:id) instead of opening one giant scrolling
 * modal with every module & lesson field inline.
 */
@Component({
  selector: 'app-courses',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
      <h1 style="font-size:24px;font-weight:700;">Courses</h1>
      <button class="btn btn-primary" (click)="openCourseModal()">+ Add Course</button>
    </div>

    <div class="grid-2">
      <div class="card" *ngFor="let c of courses" (click)="goToCourse(c)" style="cursor:pointer;">
        <div style="display:flex;align-items:center;gap:16px;">
          <div *ngIf="c.thumbnailUrl; else noThumb" style="width:56px;height:56px;border-radius:12px;overflow:hidden;flex-shrink:0;">
            <img [src]="c.thumbnailUrl" alt="{{c.title}}" style="width:100%;height:100%;object-fit:cover;" (error)="c.thumbnailUrl = ''">
          </div>
          <ng-template #noThumb>
            <div style="width:56px;height:56px;border-radius:12px;background:#0F172A10;display:flex;align-items:center;justify-content:center;font-size:28px;">📚</div>
          </ng-template>
          <div>
            <h3 style="font-weight:700;font-size:18px;">{{c.title}}</h3>
            <p style="color:#64748B;font-size:14px;">{{c.description | slice:0:60}}...</p>
            <p style="color:#64748B;font-size:12px;margin-top:4px;">{{c.instructorName || 'No instructor'}}</p>
            <p *ngIf="getPlanName(c.planId)" style="color:#EAB308;font-size:12px;margin-top:2px;">⭐ {{getPlanName(c.planId)}}</p>
          </div>
        </div>
        <div style="margin-top:16px;display:flex;gap:12px;align-items:center;">
          <span class="badge" [class.badge-success]="c.isPublished" [class.badge-warning]="!c.isPublished">
            {{c.isPublished ? 'Published' : 'Draft'}}
          </span>
          <span class="badge badge-info">{{c.modules?.length || 0}} modules</span>
          <span class="badge badge-secondary">{{c.lessonsCount || 0}} lessons</span>
          <button class="btn btn-secondary" style="margin-left:auto;padding:4px 12px;font-size:12px;" (click)="$event.stopPropagation(); goToCourse(c)">Manage Content →</button>
          <button class="btn btn-danger" style="padding:4px 12px;font-size:12px;" (click)="$event.stopPropagation(); deleteCourse(c)">Delete</button>
        </div>
      </div>
      <div *ngIf="courses.length === 0" class="card" style="text-align:center;color:#64748B;padding:32px;grid-column:1/-1;">
        No courses yet. Click "+ Add Course" to create one.
      </div>
    </div>

    <!-- Course Modal (Fieldset + Legend) -->
    <div class="modal-overlay" *ngIf="showModal" (click)="closeModal($event)">
      <div class="modal-content" style="width:90%;max-width:560px;" (click)="$event.stopPropagation()">
        <div style="display:flex;justify-content:flex-end;margin-bottom:0;">
          <button class="btn btn-secondary btn-sm" (click)="closeModal()">✕</button>
        </div>

        <form (ngSubmit)="saveCourse()">
          <fieldset>
            <legend>{{editingCourse ? 'Edit Course' : 'Add New Course'}}</legend>
            <div class="popup-form-grid">
              <div class="full-width">
                <label>Course Title</label>
                <input type="text" [(ngModel)]="courseForm.title" name="title" required placeholder="Enter course title">
              </div>
              <div class="full-width">
                <label>Description</label>
                <textarea [(ngModel)]="courseForm.description" name="description" rows="3" placeholder="Enter course description"></textarea>
              </div>
              <div>
                <label>Thumbnail URL</label>
                <input type="text" [(ngModel)]="courseForm.thumbnailUrl" name="thumbnailUrl" placeholder="https://example.com/image.jpg">
              </div>
              <div *ngIf="courseForm.thumbnailUrl" class="full-width">
                <img [src]="courseForm.thumbnailUrl" alt="Thumbnail preview" style="max-width:200px;max-height:100px;border-radius:8px;object-fit:cover;" (error)="onThumbError($event)">
              </div>
              <div>
                <label>Subscription Plan</label>
                <select [(ngModel)]="courseForm.planId" name="planId">
                  <option [ngValue]="null">No plan (free access)</option>
                  <option *ngFor="let p of plans" [ngValue]="p.id">{{p.name}} - ₹{{p.price}}{{p.period}}</option>
                </select>
              </div>
              <div>
                <label>Instructor</label>
                <select [(ngModel)]="courseForm.instructorId" name="instructorId">
                  <option [ngValue]="null">No instructor assigned</option>
                  <option *ngFor="let f of faculty" [ngValue]="f.id">{{f.name}} ({{f.email}})</option>
                </select>
              </div>
              <div *ngIf="editingCourse" class="full-width">
                <div style="padding:12px 14px;background:#EFF6FF;border-radius:8px;font-size:13px;color:#1D4ED8;">
                  💡 Modules & lessons are managed from the Course Detail page. Click "Manage Content" on the course card.
                </div>
              </div>
            </div>
          </fieldset>

          <div class="popup-nav">
            <span style="flex:1"></span>
            <button type="button" class="btn btn-danger" (click)="closeModal()">Cancel</button>
            <button type="submit" class="btn btn-accent" [disabled]="saving">{{saving ? 'Saving...' : (editingCourse ? 'Update Course' : 'Create Course')}}</button>
          </div>
        </form>

        <div *ngIf="errorMessage" style="margin-top:16px;padding:12px;background:#FEE2E2;color:#991B1B;border-radius:8px;font-size:14px;">
          {{errorMessage}}
        </div>
      </div>
    </div>
  `,
  styles: [`
    .modal-overlay { position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.5); display: flex; align-items: center; justify-content: center; z-index: 1000; }
    .modal-content { background: white; border-radius: 16px; padding: 32px; box-shadow: 0 20px 25px -5px rgba(0,0,0,0.1); }
  `]
})
export class CoursesComponent implements OnInit {
  courses: Course[] = [];
  plans: SubscriptionPlan[] = [];
  faculty: Faculty[] = [];
  showModal = false;
  editingCourse: Course | null = null;
  saving = false;
  errorMessage = '';
  courseTab: 'basic' | 'access' = 'basic';
  courseForm: any = { title: '', description: '', thumbnailUrl: '', instructorId: null, planId: null };

  constructor(private apiService: ApiService, private router: Router) {}

  ngOnInit() {
    this.showModal = false;
    this.editingCourse = null;
    this.loadCourses();
    this.loadPlans();
    this.loadFaculty();
  }

  loadCourses() {
    this.apiService.get<Course[]>('/api/courses').subscribe({
      next: (data) => {
        this.courses = data.map((c: any) => ({
          ...c,
          lessonsCount: c.modules?.reduce((sum: number, m: any) => sum + (m.lessons?.length || 0), 0) || 0
        }));
      },
      error: (err) => { console.error('Failed to load courses', err); this.courses = []; }
    });
  }

  loadPlans() {
    this.apiService.get<SubscriptionPlan[]>('/api/subscription-plans').subscribe({
      next: (data) => { this.plans = data; },
      error: (err) => { console.error('Failed to load subscription plans', err); this.plans = []; }
    });
  }

  loadFaculty() {
    this.apiService.get<Faculty[]>('/api/faculty').subscribe({
      next: (data) => { this.faculty = data; },
      error: (err) => { console.error('Failed to load faculty', err); this.faculty = []; }
    });
  }

  goToCourse(course: Course) { this.router.navigate(['/courses', course.id]); }

  getPlanName(planId?: number): string {
    if (!planId) return '';
    const plan = this.plans.find(p => p.id === planId);
    return plan ? plan.name : '';
  }

  onThumbError(event: any) { event.target.style.display = 'none'; }

  openCourseModal() {
    this.editingCourse = null;
    this.errorMessage = '';
    this.courseForm = { title: '', description: '', thumbnailUrl: '', instructorId: null, planId: null };
    this.showModal = true;
  }

  editCourse(course: Course) {
    this.editingCourse = course;
    this.errorMessage = '';
    this.courseForm = {
      title: course.title,
      description: course.description || '',
      thumbnailUrl: course.thumbnailUrl || '',
      instructorId: course.instructorId || null,
      planId: course.planId || null
    };
    this.showModal = true;
  }

  closeModal(event?: any) {
    this.showModal = false;
    this.editingCourse = null;
    this.errorMessage = '';
  }

  saveCourse() {
    this.saving = true;
    this.errorMessage = '';
    if (this.editingCourse) {
      this.apiService.put(`/api/courses/${this.editingCourse.id}`, this.courseForm).subscribe({
        next: () => { this.saving = false; this.loadCourses(); this.closeModal(); },
        error: (err) => {
          this.saving = false;
          this.errorMessage = 'Failed to update course. ' + (err.error?.message || 'Please check the details and try again.');
        }
      });
    } else {
      this.apiService.post('/api/courses', this.courseForm).subscribe({
        next: () => { this.saving = false; this.loadCourses(); this.closeModal(); },
        error: (err) => {
          this.saving = false;
          this.errorMessage = 'Failed to create course. ' + (err.error?.message || 'Please check the details and try again.');
        }
      });
    }
  }

  deleteCourse(course: Course) {
    if (!confirm(`Are you sure you want to delete "${course.title}"?`)) return;
    this.apiService.delete(`/api/courses/${course.id}`).subscribe({
      next: () => { this.loadCourses(); },
      error: (err) => { console.error('Failed to delete course', err); alert('Failed to delete course'); }
    });
  }
}
