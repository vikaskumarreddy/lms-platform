import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { DomSanitizer, SafeResourceUrl } from '@angular/platform-browser';
import { ApiService } from '../../services/api.service';
import { ApiErrorService } from '../../services/api-error.service';
import { MediaService, MediaItem } from '../../services/media.service';
import { ConfirmService } from '../../services/confirm.service';

interface Lesson {
  id: number;
  title: string;
  heading?: string;
  content?: string;
  videoUrl?: string;
  videoSource?: 'URL' | 'SELF';
  videoId?: number | null;
  thumbnailUrl?: string;
  pdfNotesUrl?: string;
  pdfSource?: 'URL' | 'SELF';
  pdfNoteId?: number | null;
  orderIndex?: number;
  durationMinutes?: number;
  isLocked?: boolean;
  isMandatory?: boolean;
}

interface CourseModule {
  id: number;
  title: string;
  description?: string;
  orderIndex?: number;
  icon?: string;
  color?: string;
  isLocked?: boolean;
  lessons: Lesson[];
  expanded?: boolean;
}

interface Course {
  id: number;
  title: string;
  description: string;
  thumbnailUrl: string;
  instructorId?: number;
  planId?: number;
  isPublished: boolean;
  modules: CourseModule[];
}

interface Faculty { id: number; name: string; email: string; }
interface SubscriptionPlan { id: number; name: string; price: number; period: string; }

/**
 * Course Detail page: module cards with inline CRUD, each containing lesson
 * cards with inline CRUD. Replaces the old single giant scrolling form.
 */
@Component({
  selector: 'app-course-detail',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './course-detail.component.html',
  styleUrl: './course-detail.component.css'
})
export class CourseDetailComponent implements OnInit {
  courseId!: number;
  course: Course | null = null;
  faculty: Faculty[] = [];
  plans: SubscriptionPlan[] = [];
  pdfNotes: { id: number; title: string }[] = [];
  mediaFiles: MediaItem[] = [];
  mediaVideos: MediaItem[] = [];
  loading = true;
  viewMedia: MediaItem | null = null;
  viewMediaSafeUrl: SafeResourceUrl | null = null;
  viewMediaIsPdf = false;
  private media = inject(MediaService);
  private confirm = inject(ConfirmService);

  // Module modal state
  showModuleModal = false;
  editingModule: CourseModule | null = null;
  moduleForm: any = { title: '', description: '', orderIndex: 0, icon: '', color: '', isLocked: false };
  savingModule = false;

  // Lesson modal state
  showLessonModal = false;
  editingLesson: Lesson | null = null;
  activeModuleForLesson: CourseModule | null = null;
  lessonForm: any = {};
  savingLesson = false;

  constructor(
    private route: ActivatedRoute,
    private router: Router,
    private api: ApiService,
    private errors: ApiErrorService,
    private sanitizer: DomSanitizer
  ) {}

  ngOnInit() {
    this.courseId = Number(this.route.snapshot.paramMap.get('id'));
    this.loadCourse();
    this.loadFaculty();
    this.loadPlans();
    this.loadMedia();
  }

  /** Load uploaded media (videos + files) for the self-hosted dropdowns. */
  private loadMedia() {
    this.media.list().subscribe({
      next: (items) => {
        this.mediaVideos = items.filter(i => i.type === 'video');
        this.mediaFiles = items.filter(i => i.type === 'file');
      },
      error: () => { this.mediaVideos = []; this.mediaFiles = []; }
    });
  }

  loadCourse() {
    this.loading = true;
    this.api.get<Course>(`/api/courses/${this.courseId}`).subscribe({
      next: (data) => {
        data.modules = (data.modules || [])
          .slice()
          .sort((a, b) => (a.orderIndex ?? 0) - (b.orderIndex ?? 0))
          .map(m => ({
            ...m,
            expanded: false,
            lessons: (m.lessons || []).slice().sort((a, b) => (a.orderIndex ?? 0) - (b.orderIndex ?? 0))
          }));
        this.course = data;
        this.loading = false;
      },
      error: (err) => {
        console.error('Failed to load course', err);
        this.loading = false;
      }
    });
  }

  loadFaculty() {
    this.api.get<Faculty[]>('/api/faculty').subscribe({ next: (d) => this.faculty = d, error: () => this.faculty = [] });
  }

  loadPlans() {
    this.api.get<SubscriptionPlan[]>('/api/subscription-plans').subscribe({ next: (d) => this.plans = d, error: () => this.plans = [] });
  }

  getFacultyName(id?: number): string {
    if (!id) return 'No instructor assigned';
    const f = this.faculty.find(x => x.id === id);
    return f ? `${f.name} (${f.email})` : 'Unknown';
  }

  getPlanName(id?: number): string {
    if (!id) return 'Free access';
    const p = this.plans.find(x => x.id === id);
    return p ? `${p.name} - ₹${p.price}${p.period}` : '';
  }

  toggleModule(m: CourseModule) { m.expanded = !m.expanded; }

  back() { this.router.navigate(['/courses']); }

  // ── Module CRUD ──────────────────────────────────────────────
  openAddModule() {
    this.editingModule = null;
    const nextOrder = (this.course?.modules?.length || 0);
    this.moduleForm = { title: '', description: '', orderIndex: nextOrder, icon: '📘', color: '#4F46E5', isLocked: false };
    this.showModuleModal = true;
  }

  openEditModule(m: CourseModule) {
    this.editingModule = m;
    this.moduleForm = { title: m.title, description: m.description || '', orderIndex: m.orderIndex ?? 0, icon: m.icon || '', color: m.color || '', isLocked: !!m.isLocked };
    this.showModuleModal = true;
  }

  closeModuleModal() { this.showModuleModal = false; this.editingModule = null; }

  saveModule() {
    this.savingModule = true;
    if (this.editingModule) {
      this.api.put(`/api/modules/${this.editingModule.id}`, this.moduleForm).subscribe({
        next: () => { this.savingModule = false; this.closeModuleModal(); this.loadCourse(); },
        error: (err) => { this.savingModule = false; this.errors.show(err, 'Failed to update module'); }
      });
    } else {
      this.api.post(`/api/modules/course/${this.courseId}`, this.moduleForm).subscribe({
        next: () => { this.savingModule = false; this.closeModuleModal(); this.loadCourse(); },
        error: (err) => { this.savingModule = false; this.errors.show(err, 'Failed to add module'); }
      });
    }
  }

  async deleteModule(m: CourseModule) {
    if (!(await this.confirm.confirm(`Delete module "${m.title}" and all its lessons?`))) return;
    this.api.delete(`/api/modules/${m.id}`).subscribe({
      next: () => this.loadCourse(),
      error: (err) => this.errors.show(err, 'Failed to delete module')
    });
  }

  // ── Lesson CRUD ──────────────────────────────────────────────
  openAddLesson(m: CourseModule) {
    this.activeModuleForLesson = m;
    this.editingLesson = null;
    this.lessonForm = {
      title: '', heading: '', videoUrl: '', videoSource: 'URL', videoId: null, thumbnailUrl: '', pdfNotesUrl: '',
      pdfSource: 'URL', pdfNoteId: null,
      orderIndex: m.lessons.length, durationMinutes: 10, isLocked: false, isMandatory: true
    };
    this.showLessonModal = true;
  }

  openEditLesson(m: CourseModule, l: Lesson) {
    this.activeModuleForLesson = m;
    this.editingLesson = l;
    this.lessonForm = {
      title: l.title, heading: l.heading || '', videoUrl: l.videoUrl || '',
      videoSource: l.videoSource === 'SELF' ? 'SELF' : 'URL', videoId: l.videoId ?? null,
      thumbnailUrl: l.thumbnailUrl || '', pdfNotesUrl: l.pdfNotesUrl || '',
      pdfSource: l.pdfSource === 'SELF' ? 'SELF' : 'URL', pdfNoteId: l.pdfNoteId ?? null,
      orderIndex: l.orderIndex ?? 0,
      durationMinutes: l.durationMinutes ?? 10, isLocked: !!l.isLocked, isMandatory: l.isMandatory !== false
    };
    this.showLessonModal = true;
  }

  closeLessonModal() { this.showLessonModal = false; this.editingLesson = null; this.activeModuleForLesson = null; }

  saveLesson() {
    if (!this.activeModuleForLesson) return;
    this.savingLesson = true;
    if (this.editingLesson) {
      this.api.put(`/api/lessons/${this.editingLesson.id}`, this.lessonForm).subscribe({
        next: () => { this.savingLesson = false; this.closeLessonModal(); this.loadCourse(); },
        error: (err) => { this.savingLesson = false; this.errors.show(err, 'Failed to update lesson'); }
      });
    } else {
      this.api.post(`/api/lessons/module/${this.activeModuleForLesson.id}`, this.lessonForm).subscribe({
        next: () => { this.savingLesson = false; this.closeLessonModal(); this.loadCourse(); },
        error: (err) => { this.savingLesson = false; this.errors.show(err, 'Failed to add lesson'); }
      });
    }
  }

  async deleteLesson(l: Lesson) {
    if (!(await this.confirm.confirm(`Delete lesson "${l.title}"?`))) return;
    this.api.delete(`/api/lessons/${l.id}`).subscribe({
      next: () => this.loadCourse(),
      error: (err) => this.errors.show(err, 'Failed to delete lesson')
    });
  }

  // ── Media view popup (self-hosted videos & PDFs) ──────────────
  viewSelfVideo(id: number | null) {
    if (!id) return;
    const item = this.mediaVideos.find(v => v.id === id) || null;
    this.viewMedia = item;
    this.viewMediaIsPdf = false;
    this.viewMediaSafeUrl = null;
  }

  viewSelfPdf(id: number | null) {
    if (!id) return;
    const item = this.mediaFiles.find(f => f.id === id) || null;
    this.viewMedia = item;
    this.viewMediaIsPdf = true;
    if (item) this.viewMediaSafeUrl = this.sanitizer.bypassSecurityTrustResourceUrl(this.media.serveUrl(item.id));
  }

  closeMediaView() { this.viewMedia = null; this.viewMediaSafeUrl = null; }

  mediaServeUrl(id: number): string { return this.media.serveUrl(id); }

  /** "▶ Video" on a saved lesson row — self-hosted opens the in-page popup, external URL opens in a new tab. */
  viewLessonVideo(l: Lesson) {
    if (l.videoSource === 'SELF' && l.videoId) { this.viewSelfVideo(l.videoId); return; }
    if (l.videoUrl) window.open(l.videoUrl, '_blank', 'noopener');
  }

  /** "📄 PDF" on a saved lesson row — self-hosted opens the in-page popup, external URL opens in a new tab. */
  viewLessonPdf(l: Lesson) {
    if (l.pdfSource === 'SELF' && l.pdfNoteId) { this.viewSelfPdf(l.pdfNoteId); return; }
    if (l.pdfNotesUrl) window.open(l.pdfNotesUrl, '_blank', 'noopener');
  }

}
