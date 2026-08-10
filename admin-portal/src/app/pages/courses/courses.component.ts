import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';

interface Module {
  id?: number;
  title: string;
  description: string;
  orderIndex: number;
  icon: string;
  color: string;
  isLocked: boolean;
  lessons: Lesson[];
}

interface Lesson {
  id?: number;
  title: string;
  heading: string;
  content: string;
  videoUrl: string;
  thumbnailUrl: string;
  pdfNotesUrl: string;
  orderIndex: number;
  durationMinutes: number;
  isLocked: boolean;
  isMandatory: boolean;
}

interface Course {
  id: number;
  title: string;
  description: string;
  thumbnailUrl: string;
  instructorId?: number;
  instructorName?: string;
  isPublished: boolean;
  planId?: number;
  modules: Module[];
  studentsCount?: number;
  lessonsCount?: number;
}

interface SubscriptionPlan {
  id: number;
  name: string;
  price: number;
  period: string;
}

@Component({
  selector: 'app-courses',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
      <h1 style="font-size:24px;font-weight:700;">Courses</h1>
      <button class="btn btn-primary" (click)="openCourseModal()" style="position:relative;z-index:1;">+ Add Course</button>
    </div>

    <div class="grid-2">
      <div class="card" *ngFor="let c of courses" (click)="editCourse(c)" style="cursor:pointer;">
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
          <button class="btn btn-danger" style="margin-left:auto;padding:4px 12px;font-size:12px;position:relative;z-index:2;" (click)="$event.stopPropagation(); deleteCourse(c)">Delete</button>
        </div>
      </div>
    </div>

    <!-- Course Modal -->
    <div class="modal-overlay" *ngIf="showModal" (click)="closeModal($event)">
      <div class="modal-content" style="width:90%;max-width:900px;max-height:90vh;overflow-y:auto;" (click)="$event.stopPropagation()">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
          <h2 style="font-size:20px;font-weight:700;">{{editingCourse ? 'Edit Course' : 'Add New Course'}}</h2>
          <button class="btn btn-secondary" (click)="closeModal()">✕</button>
        </div>

        <form (ngSubmit)="saveCourse()">
          <div style="margin-bottom:20px;">
            <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">Course Title</label>
            <input type="text" [(ngModel)]="courseForm.title" name="title" required
                   style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;"
                   placeholder="Enter course title">
          </div>

          <div style="margin-bottom:20px;">
            <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">Description</label>
            <textarea [(ngModel)]="courseForm.description" name="description" rows="3"
                      style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;resize:vertical;"
                      placeholder="Enter course description"></textarea>
          </div>

          <div style="margin-bottom:20px;">
            <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">Thumbnail URL</label>
            <input type="text" [(ngModel)]="courseForm.thumbnailUrl" name="thumbnailUrl"
                   style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;"
                   placeholder="https://example.com/image.jpg">
            <div *ngIf="courseForm.thumbnailUrl" style="margin-top:8px;">
              <img [src]="courseForm.thumbnailUrl" alt="Thumbnail preview" style="max-width:200px;max-height:100px;border-radius:8px;object-fit:cover;" (error)="onThumbError($event)">
            </div>
          </div>

          <div style="margin-bottom:20px;">
            <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">Subscription Plan (for access control)</label>
            <select [(ngModel)]="courseForm.planId" name="planId"
                    style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;background:white;">
              <option [ngValue]="null">No plan (free access)</option>
              <option *ngFor="let p of plans" [ngValue]="p.id">{{p.name}} - ₹{{p.price}}{{p.period}}</option>
            </select>
          </div>

          <div style="margin-bottom:20px;">
            <label style="display:block;font-weight:600;margin-bottom:8px;font-size:14px;">Instructor ID (optional)</label>
            <input type="number" [(ngModel)]="courseForm.instructorId" name="instructorId"
                   style="width:100%;padding:10px 14px;border:1px solid #E2E8F0;border-radius:8px;font-size:14px;"
                   placeholder="Enter instructor user ID">
          </div>

          <!-- Modules Section -->
          <div style="margin-bottom:20px;">
            <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px;">
              <label style="font-weight:700;font-size:16px;">Modules & Lessons</label>
              <button type="button" class="btn btn-secondary" (click)="addModule()">+ Add Module</button>
            </div>

            <div *ngFor="let module of courseForm.modules; let mIndex = index" style="border:1px solid #E2E8F0;border-radius:12px;padding:16px;margin-bottom:16px;background:#F8FAFC;">
              <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;">
                <h4 style="font-weight:600;font-size:14px;color:#0F172A;">Module {{mIndex + 1}}</h4>
                <button type="button" class="btn btn-danger" style="padding:4px 12px;font-size:12px;" (click)="removeModule(mIndex)">Remove</button>
              </div>

              <div style="margin-bottom:12px;">
                <label style="display:block;font-size:13px;font-weight:600;margin-bottom:6px;">Module Title</label>
                <input type="text" [(ngModel)]="module.title" [name]="'moduleTitle'+mIndex"
                       style="width:100%;padding:8px 12px;border:1px solid #E2E8F0;border-radius:6px;font-size:13px;"
                       placeholder="Module title">
              </div>

              <div style="margin-bottom:12px;">
                <label style="display:block;font-size:13px;font-weight:600;margin-bottom:6px;">Module Description</label>
                <textarea [(ngModel)]="module.description" [name]="'moduleDesc'+mIndex" rows="2"
                          style="width:100%;padding:8px 12px;border:1px solid #E2E8F0;border-radius:6px;font-size:13px;resize:vertical;"
                          placeholder="Module description"></textarea>
              </div>

              <div style="margin-bottom:12px;">
                <label style="display:block;font-size:13px;font-weight:600;margin-bottom:6px;">Order Index</label>
                <input type="number" [(ngModel)]="module.orderIndex" [name]="'moduleOrder'+mIndex"
                       style="width:100%;padding:8px 12px;border:1px solid #E2E8F0;border-radius:6px;font-size:13px;"
                       placeholder="0">
              </div>

              <div style="margin-bottom:12px;">
                <label style="display:block;font-size:13px;font-weight:600;margin-bottom:6px;">Icon (e.g. 📚)</label>
                <input type="text" [(ngModel)]="module.icon" [name]="'moduleIcon'+mIndex"
                       style="width:100%;padding:8px 12px;border:1px solid #E2E8F0;border-radius:6px;font-size:13px;"
                       placeholder="Icon name or emoji">
              </div>

              <div style="margin-bottom:12px;">
                <label style="display:block;font-size:13px;font-weight:600;margin-bottom:6px;">Color (hex code)</label>
                <input type="text" [(ngModel)]="module.color" [name]="'moduleColor'+mIndex"
                       style="width:100%;padding:8px 12px;border:1px solid #E2E8F0;border-radius:6px;font-size:13px;"
                       placeholder="#0F172A">
              </div>

              <div style="margin-bottom:12px;display:flex;align-items:center;gap:8px;">
                <input type="checkbox" [(ngModel)]="module.isLocked" [name]="'moduleLocked'+mIndex"
                       style="width:18px;height:18px;">
                <label style="font-size:13px;font-weight:600;margin-bottom:0;">Lock this section</label>
              </div>

              <!-- Lessons -->
              <div style="margin-top:16px;padding-top:16px;border-top:1px solid #E2E8F0;">
                <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;">
                  <label style="font-weight:600;font-size:13px;">Lessons</label>
                  <button type="button" class="btn btn-secondary" style="padding:4px 12px;font-size:12px;" (click)="addLesson(module)">+ Add Lesson</button>
                </div>

                <div *ngFor="let lesson of module.lessons; let lIndex = index" style="background:white;border:1px solid #E2E8F0;border-radius:8px;padding:12px;margin-bottom:12px;">
                  <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;">
                    <strong style="font-size:13px;">Lesson {{lIndex + 1}}</strong>
                    <button type="button" class="btn btn-danger" style="padding:2px 8px;font-size:11px;" (click)="removeLesson(module, lIndex)">Remove</button>
                  </div>

                  <div style="margin-bottom:8px;">
                    <label style="display:block;font-size:12px;font-weight:600;margin-bottom:4px;">Lesson Title</label>
                    <input type="text" [(ngModel)]="lesson.title" [name]="'lessonTitle'+mIndex+lIndex"
                           style="width:100%;padding:6px 10px;border:1px solid #E2E8F0;border-radius:4px;font-size:12px;"
                           placeholder="Lesson title">
                  </div>

                  <div style="margin-bottom:8px;">
                    <label style="display:block;font-size:12px;font-weight:600;margin-bottom:4px;">Content (HTML supported)</label>
                    <textarea [(ngModel)]="lesson.content" [name]="'lessonContent'+mIndex+lIndex" rows="4"
                              style="width:100%;padding:6px 10px;border:1px solid #E2E8F0;border-radius:4px;font-size:12px;font-family:inherit;resize:vertical;"
                              placeholder="<h2>Heading</h2><p>Paragraph text...</p>"></textarea>
                  </div>

                  <div style="margin-bottom:8px;">
                    <label style="display:block;font-size:12px;font-weight:600;margin-bottom:4px;">Video URL</label>
                    <input type="text" [(ngModel)]="lesson.videoUrl" [name]="'lessonVideo'+mIndex+lIndex"
                           style="width:100%;padding:6px 10px;border:1px solid #E2E8F0;border-radius:4px;font-size:12px;"
                           placeholder="https://youtube.com/watch?v=...">
                  </div>

                  <div style="margin-bottom:8px;">
                    <label style="display:block;font-size:12px;font-weight:600;margin-bottom:4px;">Lesson Heading / Sub-title</label>
                    <input type="text" [(ngModel)]="lesson.heading" [name]="'lessonHeading'+mIndex+lIndex"
                           style="width:100%;padding:6px 10px;border:1px solid #E2E8F0;border-radius:4px;font-size:12px;"
                           placeholder="e.g. Introduction to...">
                  </div>

                  <div style="margin-bottom:8px;">
                    <label style="display:block;font-size:12px;font-weight:600;margin-bottom:4px;">Thumbnail URL</label>
                    <input type="text" [(ngModel)]="lesson.thumbnailUrl" [name]="'lessonThumb'+mIndex+lIndex"
                           style="width:100%;padding:6px 10px;border:1px solid #E2E8F0;border-radius:4px;font-size:12px;"
                           placeholder="https://example.com/thumb.jpg">
                  </div>

                  <div style="margin-bottom:8px;">
                    <label style="display:block;font-size:12px;font-weight:600;margin-bottom:4px;">PDF Notes URL</label>
                    <input type="text" [(ngModel)]="lesson.pdfNotesUrl" [name]="'lessonPdf'+mIndex+lIndex"
                           style="width:100%;padding:6px 10px;border:1px solid #E2E8F0;border-radius:4px;font-size:12px;"
                           placeholder="https://example.com/notes.pdf">
                  </div>

                  <div style="display:flex;gap:12px;">
                    <div style="display:flex;align-items:center;gap:6px;">
                      <input type="checkbox" [(ngModel)]="lesson.isLocked" [name]="'lessonLocked'+mIndex+lIndex"
                             style="width:16px;height:16px;">
                      <label style="font-size:12px;font-weight:600;margin-bottom:0;">Locked</label>
                    </div>
                    <div style="display:flex;align-items:center;gap:6px;">
                      <input type="checkbox" [(ngModel)]="lesson.isMandatory" [name]="'lessonMandatory'+mIndex+lIndex"
                             style="width:16px;height:16px;">
                      <label style="font-size:12px;font-weight:600;margin-bottom:0;">Mandatory</label>
                    </div>
                  </div>

                  <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;">
                    <div>
                      <label style="display:block;font-size:12px;font-weight:600;margin-bottom:4px;">Order</label>
                      <input type="number" [(ngModel)]="lesson.orderIndex" [name]="'lessonOrder'+mIndex+lIndex"
                             style="width:100%;padding:6px 10px;border:1px solid #E2E8F0;border-radius:4px;font-size:12px;"
                             placeholder="0">
                    </div>
                    <div>
                      <label style="display:block;font-size:12px;font-weight:600;margin-bottom:4px;">Duration (min)</label>
                      <input type="number" [(ngModel)]="lesson.durationMinutes" [name]="'lessonDuration'+mIndex+lIndex"
                             style="width:100%;padding:6px 10px;border:1px solid #E2E8F0;border-radius:4px;font-size:12px;"
                             placeholder="10">
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div style="display:flex;gap:12px;justify-content:flex-end;margin-top:24px;">
            <button type="button" class="btn btn-secondary" (click)="closeModal()">Cancel</button>
            <button type="submit" class="btn btn-primary" [disabled]="saving">{{saving ? 'Saving...' : (editingCourse ? 'Update Course' : 'Create Course')}}</button>
          </div>
        </form>

        <div *ngIf="errorMessage" style="margin-top:16px;padding:12px;background:#FEE2E2;color:#991B1B;border-radius:8px;font-size:14px;">
          {{errorMessage}}
        </div>
      </div>
    </div>
  `,
  styles: [`
    .modal-overlay {
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(0,0,0,0.5);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 1000;
    }
    .modal-content {
      background: white;
      border-radius: 16px;
      padding: 32px;
      box-shadow: 0 20px 25px -5px rgba(0,0,0,0.1);
    }
    body.modal-open {
      overflow: hidden;
    }
  `]
})
export class CoursesComponent implements OnInit {
  courses: Course[] = [];
  plans: SubscriptionPlan[] = [];
  showModal = false;
  editingCourse: Course | null = null;
  saving = false;
  errorMessage = '';
  courseForm: any = {
    title: '',
    description: '',
    thumbnailUrl: '',
    instructorId: null,
    planId: null,
    modules: []
  };

  constructor(private apiService: ApiService) {}

  ngOnInit() {
    this.showModal = false;
    this.editingCourse = null;
    this.loadCourses();
    this.loadPlans();
  }

  loadCourses() {
    this.apiService.get<Course[]>('/api/courses').subscribe({
      next: (data) => {
        this.courses = data.map((c: any) => ({
          ...c,
          lessonsCount: c.modules?.reduce((sum: number, m: any) => sum + (m.lessons?.length || 0), 0) || 0
        }));
      },
      error: (err) => {
        console.error('Failed to load courses', err);
        this.courses = [];
      }
    });
  }

  loadPlans() {
    this.apiService.get<SubscriptionPlan[]>('/api/subscription-plans').subscribe({
      next: (data) => {
        this.plans = data;
      },
      error: (err) => {
        console.error('Failed to load subscription plans', err);
        this.plans = [];
      }
    });
  }

  getPlanName(planId?: number): string {
    if (!planId) return '';
    const plan = this.plans.find(p => p.id === planId);
    return plan ? plan.name : '';
  }

  onThumbError(event: any) {
    event.target.style.display = 'none';
  }

  openCourseModal() {
    this.editingCourse = null;
    this.errorMessage = '';
    this.courseForm = {
      title: '',
      description: '',
      thumbnailUrl: '',
      instructorId: null,
      planId: null,
      modules: []
    };
    this.showModal = true;
  }

  editCourse(course: Course) {
    this.editingCourse = course;
    this.errorMessage = '';
    this.apiService.get<Course>(`/api/courses/${course.id}`).subscribe({
      next: (data) => {
        this.courseForm = {
          title: data.title,
          description: data.description || '',
          thumbnailUrl: data.thumbnailUrl || '',
          instructorId: data.instructorId,
          planId: data.planId || null,
          modules: data.modules?.map((m: any) => ({
            title: m.title,
            description: m.description || '',
            orderIndex: m.orderIndex || 0,
            icon: m.icon || '',
            color: m.color || '',
            isLocked: m.isLocked || false,
            lessons: m.lessons?.map((l: any) => ({
              title: l.title,
              heading: l.heading || '',
              content: l.content || '',
              videoUrl: l.videoUrl || '',
              thumbnailUrl: l.thumbnailUrl || '',
              pdfNotesUrl: l.pdfNotesUrl || '',
              orderIndex: l.orderIndex || 0,
              durationMinutes: l.durationMinutes || 0,
              isLocked: l.isLocked || false,
              isMandatory: l.isMandatory ?? true
            })) || []
          })) || []
        };
        this.showModal = true;
      },
      error: (err) => {
        console.error('Failed to load course details', err);
        this.errorMessage = 'Failed to load course details';
      }
    });
  }

  closeModal(event?: any) {
    this.showModal = false;
    this.editingCourse = null;
    this.errorMessage = '';
  }

  addModule() {
    this.courseForm.modules.push({
      title: '',
      description: '',
      orderIndex: this.courseForm.modules.length,
      icon: '',
      color: '',
      isLocked: false,
      lessons: []
    });
  }

  removeModule(index: number) {
    this.courseForm.modules.splice(index, 1);
  }

  addLesson(module: any) {
    module.lessons.push({
      title: '',
      heading: '',
      content: '',
      videoUrl: '',
      thumbnailUrl: '',
      pdfNotesUrl: '',
      orderIndex: module.lessons.length,
      durationMinutes: 0,
      isLocked: false,
      isMandatory: true
    });
  }

  removeLesson(module: any, index: number) {
    module.lessons.splice(index, 1);
  }

  saveCourse() {
    this.saving = true;
    this.errorMessage = '';

    if (this.editingCourse) {
      this.apiService.put(`/api/courses/${this.editingCourse.id}`, this.courseForm).subscribe({
        next: () => {
          this.saving = false;
          this.loadCourses();
          this.closeModal();
        },
        error: (err) => {
          this.saving = false;
          console.error('Failed to update course', err);
          this.errorMessage = 'Failed to update course. ' + (err.error?.message || 'Please check the details and try again.');
        }
      });
    } else {
      this.apiService.post('/api/courses', this.courseForm).subscribe({
        next: () => {
          this.saving = false;
          this.loadCourses();
          this.closeModal();
        },
        error: (err) => {
          this.saving = false;
          console.error('Failed to create course', err);
          this.errorMessage = 'Failed to create course. ' + (err.error?.message || 'Please check the details and try again.');
        }
      });
    }
  }

  deleteCourse(course: Course) {
    if (!confirm(`Are you sure you want to delete "${course.title}"?`)) return;
    this.apiService.delete(`/api/courses/${course.id}`).subscribe({
      next: () => {
        this.loadCourses();
      },
      error: (err) => {
        console.error('Failed to delete course', err);
        alert('Failed to delete course');
      }
    });
  }
}