import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { DomSanitizer, SafeHtml } from '@angular/platform-browser';
import { ApiService } from '../../services/api.service';
import { ApiErrorService } from '../../services/api-error.service';
import { RichTextToHtmlService } from '../../services/rich-text-to-html.service';

interface Lesson {
  id: number;
  title: string;
  heading?: string;
  content?: string;
  videoUrl?: string;
  thumbnailUrl?: string;
  pdfNotesUrl?: string;
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
  loading = true;

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

  // HTML preview modal
  showPreview = false;
  previewHtml: SafeHtml = '';

  // ── Notes conversion (Word / plain text → HTML) ───────────────
  /** Outcome of the last conversion, shown under the textarea. */
  conversionMessage = '';
  conversionWarnings: string[] = [];
  conversionOk = false;
  /**
   * The content as it was before the last conversion, so a faculty member who
   * dislikes the result can put it back. Without this, converting is a one-way
   * door over someone's typed notes.
   */
  private contentBeforeConversion: string | null = null;

  constructor(
    private route: ActivatedRoute,
    private router: Router,
    private api: ApiService,
    private errors: ApiErrorService,
    private sanitizer: DomSanitizer,
    private richText: RichTextToHtmlService
  ) {}

  ngOnInit() {
    this.courseId = Number(this.route.snapshot.paramMap.get('id'));
    this.loadCourse();
    this.loadFaculty();
    this.loadPlans();
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

  deleteModule(m: CourseModule) {
    if (!confirm(`Delete module "${m.title}" and all its lessons?`)) return;
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
      title: '', heading: '', content: '', videoUrl: '', thumbnailUrl: '', pdfNotesUrl: '',
      orderIndex: m.lessons.length, durationMinutes: 10, isLocked: false, isMandatory: true
    };
    this.resetConversionState();
    this.showLessonModal = true;
  }

  openEditLesson(m: CourseModule, l: Lesson) {
    this.activeModuleForLesson = m;
    this.editingLesson = l;
    this.lessonForm = {
      title: l.title, heading: l.heading || '', content: l.content || '', videoUrl: l.videoUrl || '',
      thumbnailUrl: l.thumbnailUrl || '', pdfNotesUrl: l.pdfNotesUrl || '', orderIndex: l.orderIndex ?? 0,
      durationMinutes: l.durationMinutes ?? 10, isLocked: !!l.isLocked, isMandatory: l.isMandatory !== false
    };
    this.resetConversionState();
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

  deleteLesson(l: Lesson) {
    if (!confirm(`Delete lesson "${l.title}"?`)) return;
    this.api.delete(`/api/lessons/${l.id}`).subscribe({
      next: () => this.loadCourse(),
      error: (err) => this.errors.show(err, 'Failed to delete lesson')
    });
  }

  // ── HTML mobile preview ──────────────────────────────────────
  openPreview(content: string) {
    this.previewHtml = this.sanitizer.bypassSecurityTrustHtml(content || '<p style="color:#94A3B8;">No notes content yet.</p>');
    this.showPreview = true;
  }

  closePreview() { this.showPreview = false; }

  // ── Notes conversion ─────────────────────────────────────────

  /**
   * Intercepts a paste into the notes box to keep the formatting.
   *
   * <p>A plain textarea normally receives text only — the browser discards the
   * clipboard's rich flavour, so headings, bold and bullets from a Word document are
   * lost before any button could act on them. Reading {@code text/html} here is the
   * only point at which that formatting still exists, which is why conversion happens
   * on paste rather than only on demand.
   *
   * <p>Falls through to the browser's own handling when the clipboard holds no HTML,
   * so typing and pasting plain text behave exactly as before.
   */
  onNotesPaste(event: ClipboardEvent) {
    const clipboard = event.clipboardData;
    if (!clipboard) {
      return;
    }
    const html = clipboard.getData('text/html');
    if (!html || !html.trim()) {
      return; // plain text — let the browser paste it, the button can convert later
    }

    event.preventDefault();
    const result = this.richText.fromHtml(html);
    if (!result.html.trim()) {
      return;
    }

    const textarea = event.target as HTMLTextAreaElement;
    const existing = this.lessonForm.content || '';
    this.contentBeforeConversion = existing;

    // Insert at the cursor rather than replacing, so pasting a second section appends
    // to the first instead of destroying it.
    const start = textarea.selectionStart ?? existing.length;
    const end = textarea.selectionEnd ?? existing.length;
    const separator = existing.slice(0, start).trim() ? '\n' : '';
    this.lessonForm.content = existing.slice(0, start) + separator + result.html + existing.slice(end);

    this.conversionOk = true;
    this.conversionMessage = result.source === 'word'
      ? `Pasted from Word and converted. ${result.summary}`
      : `Pasted and converted. ${result.summary}`;
    this.conversionWarnings = result.warnings;
  }

  /**
   * Converts whatever is currently in the box.
   *
   * <p>For content that is already there — typed by hand, or pasted as plain text —
   * structure is inferred from how people actually write notes: dashes are bullets,
   * a line ending in a colon introduces a section, a short line with no full stop is a
   * heading.
   */
  convertNotesToHtml() {
    const current = (this.lessonForm.content || '').trim();
    if (!current) {
      this.conversionOk = false;
      this.conversionMessage = 'Paste or type your notes first, then convert.';
      this.conversionWarnings = [];
      return;
    }

    this.contentBeforeConversion = this.lessonForm.content;
    const result = this.richText.convert(current);

    if (!result.html.trim()) {
      this.conversionOk = false;
      this.conversionMessage = 'Could not find any structure to convert.';
      this.conversionWarnings = [];
      return;
    }

    this.lessonForm.content = result.html;
    this.conversionOk = true;
    this.conversionMessage = result.source === 'text'
      ? `${result.summary} Check the preview and adjust anything that looks wrong.`
      : `Cleaned up the pasted markup. ${result.summary}`;
    this.conversionWarnings = result.warnings;
  }

  get canUndoConversion(): boolean {
    return this.contentBeforeConversion !== null
      && this.contentBeforeConversion !== this.lessonForm.content;
  }

  /** Restores the content as it was before the last conversion. */
  undoConversion() {
    if (this.contentBeforeConversion === null) {
      return;
    }
    this.lessonForm.content = this.contentBeforeConversion;
    this.contentBeforeConversion = null;
    this.conversionOk = false;
    this.conversionMessage = 'Reverted to what you had before.';
    this.conversionWarnings = [];
  }

  /** Clears the conversion feedback when the modal opens or closes. */
  private resetConversionState() {
    this.conversionMessage = '';
    this.conversionWarnings = [];
    this.conversionOk = false;
    this.contentBeforeConversion = null;
  }
}
