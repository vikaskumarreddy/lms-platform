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

/** Response of a bulk import: what landed, what was skipped, and why. */
interface BulkImportResult {
  imported: number;
  lessonsImported?: number;
  failed: number;
  errors: string[];
}

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

  // Module pagination state (8-10 items per page)
  modulePage = 1;
  modulePageSize = 8;

  get paginatedModules(): CourseModule[] {
    if (!this.course?.modules) return [];
    const start = (this.modulePage - 1) * this.modulePageSize;
    return this.course.modules.slice(start, start + this.modulePageSize);
  }

  get totalModulePages(): number {
    if (!this.course?.modules?.length) return 1;
    return Math.ceil(this.course.modules.length / this.modulePageSize);
  }

  get moduleStartIndex(): number {
    if (!this.course?.modules?.length) return 0;
    return (this.modulePage - 1) * this.modulePageSize + 1;
  }

  get moduleEndIndex(): number {
    if (!this.course?.modules?.length) return 0;
    return Math.min(this.modulePage * this.modulePageSize, this.course.modules.length);
  }

  setModulePage(page: number) {
    if (page >= 1 && page <= this.totalModulePages) {
      this.modulePage = page;
    }
  }

  setModulePageSize(size: any) {
    this.modulePageSize = Number(size) || 8;
    this.modulePage = 1;
  }

  get modulePageNumbers(): number[] {
    const total = this.totalModulePages;
    const current = this.modulePage;
    const pages: number[] = [];
    if (total <= 7) {
      for (let i = 1; i <= total; i++) pages.push(i);
    } else {
      if (current <= 4) {
        pages.push(1, 2, 3, 4, 5, -1, total);
      } else if (current >= total - 3) {
        pages.push(1, -1, total - 4, total - 3, total - 2, total - 1, total);
      } else {
        pages.push(1, -1, current - 1, current, current + 1, -1, total);
      }
    }
    return pages;
  }

  // Lesson modal state
  showLessonModal = false;
  editingLesson: Lesson | null = null;
  activeModuleForLesson: CourseModule | null = null;
  lessonForm: any = {};
  savingLesson = false;

  // Course edit modal state (title / description / thumbnail / plan / instructor)
  showCourseModal = false;
  courseForm: any = {};
  savingCourse = false;

  // Bulk import modal state — shared by the module import (course level) and the
  // lesson import (module level); only the target and the hint text differ.
  showBulkImport = false;
  bulkImportTarget: 'modules' | 'lessons' = 'modules';
  bulkImportModule: CourseModule | null = null;
  bulkImportFile: File | null = null;
  bulkImporting = false;
  bulkImportResult: BulkImportResult | null = null;
  bulkImportError = '';

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

  // ── Course metadata CRUD ─────────────────────────────────────
  // Before this the title/description could only be set at creation time: the
  // course form existed but nothing in the UI opened it for an existing course.
  openEditCourse() {
    if (!this.course) return;
    this.courseForm = {
      title: this.course.title,
      description: this.course.description || '',
      thumbnailUrl: this.course.thumbnailUrl || '',
      instructorId: this.course.instructorId ?? null,
      planId: this.course.planId ?? null,
      isPublished: !!this.course.isPublished
    };
    this.showCourseModal = true;
  }

  closeCourseModal() { this.showCourseModal = false; }

  /** Metadata-only update — the backend leaves the module/lesson tree untouched. */
  saveCourse() {
    if (!this.course) return;
    this.savingCourse = true;
    this.api.put(`/api/courses/${this.course.id}`, this.courseForm).subscribe({
      next: () => { this.savingCourse = false; this.closeCourseModal(); this.loadCourse(); },
      error: (err) => { this.savingCourse = false; this.errors.show(err, 'Failed to update course'); }
    });
  }

  togglePublished() {
    if (!this.course) return;
    // The update endpoint applies title/description/thumbnail/plan wholesale, so a
    // published-state flip has to carry the current values back with it.
    const body = {
      title: this.course.title,
      description: this.course.description || '',
      thumbnailUrl: this.course.thumbnailUrl || '',
      instructorId: this.course.instructorId ?? null,
      planId: this.course.planId ?? null,
      isPublished: !this.course.isPublished
    };
    this.api.put(`/api/courses/${this.course.id}`, body).subscribe({
      next: () => this.loadCourse(),
      error: (err) => this.errors.show(err, 'Failed to change the published state')
    });
  }

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

  // ── Bulk import (JSON or Excel) ──────────────────────────────
  openBulkImportModules() {
    this.bulkImportTarget = 'modules';
    this.bulkImportModule = null;
    this.resetBulkImport();
    this.showBulkImport = true;
  }

  openBulkImportLessons(m: CourseModule) {
    this.bulkImportTarget = 'lessons';
    this.bulkImportModule = m;
    this.resetBulkImport();
    this.showBulkImport = true;
  }

  private resetBulkImport() {
    this.bulkImportFile = null;
    this.bulkImportResult = null;
    this.bulkImportError = '';
    this.bulkImporting = false;
  }

  closeBulkImport() { this.showBulkImport = false; this.bulkImportModule = null; }

  /** Client-side guard mirroring the server's accepted extensions. */
  onBulkFilePicked(event: Event) {
    const input = event.target as HTMLInputElement;
    const file = input.files && input.files.length ? input.files[0] : null;
    this.bulkImportError = '';
    this.bulkImportResult = null;
    if (file && !/\.(json|xlsx|xls|xlsm)$/i.test(file.name)) {
      this.bulkImportFile = null;
      this.bulkImportError = `"${file.name}" is not a JSON or Excel file. Choose a .json, .xlsx or .xls file.`;
    } else {
      this.bulkImportFile = file;
    }
    // Allows re-picking the same file after a failed attempt.
    input.value = '';
  }

  runBulkImport() {
    if (!this.bulkImportFile) {
      this.bulkImportError = 'Choose a file to import.';
      return;
    }
    const endpoint = this.bulkImportTarget === 'modules'
      ? `/api/modules/bulk-import/course/${this.courseId}`
      : `/api/lessons/bulk-import/module/${this.bulkImportModule?.id}`;
    const form = new FormData();
    form.append('file', this.bulkImportFile, this.bulkImportFile.name);

    this.bulkImporting = true;
    this.bulkImportError = '';
    this.bulkImportResult = null;

    this.api.postForm<BulkImportResult>(endpoint, form).subscribe({
      next: (result) => {
        this.bulkImporting = false;
        this.bulkImportResult = {
          imported: result?.imported || 0,
          lessonsImported: result?.lessonsImported || 0,
          failed: result?.failed || 0,
          errors: result?.errors || []
        };
        if (this.bulkImportResult.imported > 0 || (this.bulkImportResult.lessonsImported || 0) > 0) {
          this.loadCourse();
        }
      },
      error: (err) => {
        this.bulkImporting = false;
        this.bulkImportError = this.errors.parse(err).message;
      }
    });
  }

  /**
   * Downloads a sample JSON file for the current target so the exact field names
   * (and, for lessons, how a module is referenced) are discoverable without docs.
   */
  downloadImportTemplate() {
    const lesson = {
      title: 'Lesson title', heading: 'Short heading', content: '<p>Lesson notes (HTML allowed)</p>',
      videoUrl: 'https://example.com/video.mp4', videoSource: 'URL', videoId: null,
      thumbnailUrl: '', pdfNotesUrl: '', pdfSource: 'URL', pdfNoteId: null,
      orderIndex: 0, durationMinutes: 10, isLocked: false, isMandatory: true
    };
    const payload = this.bulkImportTarget === 'modules'
      ? [{
          title: 'Module title', description: 'What this module covers', icon: '📘',
          color: '#4F46E5', orderIndex: 0, isLocked: false,
          lessons: [{ ...lesson, title: 'First lesson in this module' }]
        }]
      : [{ ...lesson, moduleTitle: '' }];

    const name = this.bulkImportTarget === 'modules' ? 'modules-import-template.json' : 'lessons-import-template.json';
    const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = name;
    link.click();
    URL.revokeObjectURL(url);
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
