package com.institute.lms.service;

import com.institute.lms.dto.course.BulkImportResult;
import com.institute.lms.dto.course.CourseRequest;
import com.institute.lms.dto.course.CourseSectionDTO;
import com.institute.lms.dto.course.LessonProgressDTO;
import com.institute.lms.dto.course.ModuleLessonsDTO;
import com.institute.lms.dto.course.ModuleRequest;
import com.institute.lms.dto.course.LessonRequest;
import com.institute.lms.entity.Course;
import com.institute.lms.entity.Lesson;
import com.institute.lms.entity.Module;
import com.institute.lms.entity.MediaItem;
import com.institute.lms.entity.PdfNote;
import com.institute.lms.entity.Progress;
import com.institute.lms.entity.User;
import com.institute.lms.repository.CourseRepository;
import com.institute.lms.repository.LessonRepository;
import com.institute.lms.repository.MediaItemRepository;
import com.institute.lms.repository.ModuleRepository;
import com.institute.lms.repository.PdfNoteRepository;
import com.institute.lms.repository.ProgressRepository;
import com.institute.lms.repository.UserRepository;
import com.institute.lms.util.BulkImportParser;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

@Service
public class CourseServiceImpl implements CourseService {
    private final CourseRepository courseRepository;
    private final UserRepository userRepository;
    private final ModuleRepository moduleRepository;
    private final LessonRepository lessonRepository;
    private final ProgressRepository progressRepository;
    private final PdfNoteRepository pdfNoteRepository;
    private final MediaItemRepository mediaItemRepository;

    /** Longest value the plain VARCHAR columns (title, heading, urls) can hold. */
    private static final int MAX_TEXT_LENGTH = 255;

    public CourseServiceImpl(CourseRepository courseRepository, UserRepository userRepository,
                            ModuleRepository moduleRepository, LessonRepository lessonRepository,
                            ProgressRepository progressRepository, PdfNoteRepository pdfNoteRepository,
                            MediaItemRepository mediaItemRepository) {
        this.courseRepository = courseRepository;
        this.userRepository = userRepository;
        this.moduleRepository = moduleRepository;
        this.lessonRepository = lessonRepository;
        this.progressRepository = progressRepository;
        this.pdfNoteRepository = pdfNoteRepository;
        this.mediaItemRepository = mediaItemRepository;
    }

    @Override
    @Transactional
    public List<Course> findAll() {
        List<Course> courses = courseRepository.findAll();
        Set<Long> completedLessonIds = getCompletedLessonIds();
        for (Course course : courses) {
            enrichCourseProgress(course, completedLessonIds);
        }
        return courses;
    }

    private void enrichCourseProgress(Course course, Set<Long> completedLessonIds) {
        int total = 0;
        int completed = 0;
        if (course.getModules() != null) {
            for (Module module : course.getModules()) {
                if (module.getLessons() != null) {
                    total += module.getLessons().size();
                    completed += module.getLessons().stream()
                            .mapToLong(Lesson::getId)
                            .filter(completedLessonIds::contains)
                            .count();
                }
            }
        }
        course.setTotalLessons(total);
        course.setCompletedLessons(completed);
        course.setProgress(total > 0 ? (double) completed / total : 0.0);
    }

    @Override
    public Optional<Course> findById(Long id) {
        return courseRepository.findById(id);
    }

    @Override
    @Transactional
    public Course createCourse(CourseRequest request) {
        Course course = new Course();
        course.setTitle(request.getTitle());
        course.setDescription(request.getDescription());
        course.setThumbnailUrl(request.getThumbnailUrl());
        course.setIsPublished(request.getIsPublished() != null ? request.getIsPublished() : false);
        course.setPlanId(request.getPlanId());

        if (request.getInstructorId() != null) {
            User instructor = userRepository.findById(request.getInstructorId())
                    .orElseThrow(() -> new RuntimeException("Instructor not found"));
            course.setInstructor(instructor);
        }

        Course savedCourse = courseRepository.save(course);

        if (request.getModules() != null) {
            for (ModuleRequest moduleRequest : request.getModules()) {
                Module module = new Module();
                module.setTitle(moduleRequest.getTitle());
                module.setDescription(moduleRequest.getDescription());
                module.setOrderIndex(moduleRequest.getOrderIndex());
                module.setIcon(moduleRequest.getIcon());
                module.setColor(moduleRequest.getColor());
                module.setIsLocked(moduleRequest.getIsLocked() != null ? moduleRequest.getIsLocked() : false);
                module.setCourse(savedCourse);

                Module savedModule = moduleRepository.save(module);

                if (moduleRequest.getLessons() != null) {
                    for (LessonRequest lessonRequest : moduleRequest.getLessons()) {
                        Lesson lesson = new Lesson();
                        lesson.setTitle(lessonRequest.getTitle());
                        lesson.setHeading(lessonRequest.getHeading());
                        lesson.setContent(lessonRequest.getContent());
                        lesson.setVideoUrl(lessonRequest.getVideoUrl());
                        lesson.setThumbnailUrl(lessonRequest.getThumbnailUrl());
                        lesson.setPdfNotesUrl(lessonRequest.getPdfNotesUrl());
                        lesson.setOrderIndex(lessonRequest.getOrderIndex());
                        lesson.setDurationMinutes(lessonRequest.getDurationMinutes());
                        lesson.setIsLocked(lessonRequest.getIsLocked() != null ? lessonRequest.getIsLocked() : false);
                        lesson.setIsMandatory(lessonRequest.getIsMandatory() != null ? lessonRequest.getIsMandatory() : true);
                        lesson.setModule(savedModule);
                        lessonRepository.save(lesson);
                    }
                }
            }
        }

        // Reload course with modules and enrollments using EntityGraph
        return courseRepository.findById(savedCourse.getId())
                .orElseThrow(() -> new RuntimeException("Course not found after creation"));
    }

    @Override
    @Transactional
    public Course updateCourse(Long id, CourseRequest request) {
        Course course = courseRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Course not found"));

        course.setTitle(request.getTitle());
        course.setDescription(request.getDescription());
        course.setThumbnailUrl(request.getThumbnailUrl());
        course.setPlanId(request.getPlanId());
        if (request.getIsPublished() != null) {
            course.setIsPublished(request.getIsPublished());
        }

        if (request.getInstructorId() != null) {
            User instructor = userRepository.findById(request.getInstructorId())
                    .orElseThrow(() -> new RuntimeException("Instructor not found"));
            course.setInstructor(instructor);
        }

        // The module/lesson tree is only rebuilt when the caller actually sends
        // one. A metadata-only edit (title/description/thumbnail/plan/instructor)
        // arrives with modules == null and must leave the existing content
        // untouched — otherwise saving the course form would silently wipe every
        // module and lesson in the course.
        List<Module> existingModules = course.getModules() != null
                ? new ArrayList<>(course.getModules())
                : new ArrayList<>();
        if (request.getModules() != null && !existingModules.isEmpty()) {
            // Delete progress records for lessons in these modules first (no DB cascade on progress)
            for (Module m : existingModules) {
                if (m.getLessons() != null) {
                    for (Lesson l : m.getLessons()) {
                        if (l.getId() != null) {
                            progressRepository.deleteByLessonId(l.getId());
                        }
                    }
                }
            }
            course.getModules().clear();
            courseRepository.saveAndFlush(course);
            moduleRepository.deleteAll(existingModules);
            courseRepository.flush();
        }

        // Add new modules and lessons
        if (request.getModules() != null) {
            for (ModuleRequest moduleRequest : request.getModules()) {
                Module module = new Module();
                module.setTitle(moduleRequest.getTitle());
                module.setDescription(moduleRequest.getDescription());
                module.setOrderIndex(moduleRequest.getOrderIndex());
                module.setIcon(moduleRequest.getIcon());
                module.setColor(moduleRequest.getColor());
                module.setIsLocked(moduleRequest.getIsLocked() != null ? moduleRequest.getIsLocked() : false);
                module.setCourse(course);

                Module savedModule = moduleRepository.save(module);

                if (moduleRequest.getLessons() != null) {
                    for (LessonRequest lessonRequest : moduleRequest.getLessons()) {
                        Lesson lesson = new Lesson();
                        lesson.setTitle(lessonRequest.getTitle());
                        lesson.setHeading(lessonRequest.getHeading());
                        lesson.setContent(lessonRequest.getContent());
                        lesson.setVideoUrl(lessonRequest.getVideoUrl());
                        lesson.setThumbnailUrl(lessonRequest.getThumbnailUrl());
                        lesson.setPdfNotesUrl(lessonRequest.getPdfNotesUrl());
                        lesson.setOrderIndex(lessonRequest.getOrderIndex());
                        lesson.setDurationMinutes(lessonRequest.getDurationMinutes());
                        lesson.setIsLocked(lessonRequest.getIsLocked() != null ? lessonRequest.getIsLocked() : false);
                        lesson.setIsMandatory(lessonRequest.getIsMandatory() != null ? lessonRequest.getIsMandatory() : true);
                        lesson.setModule(savedModule);
                        lessonRepository.save(lesson);
                    }
                }
            }
        }

        Course savedCourse = courseRepository.save(course);
        // Reload with modules for full response
        return courseRepository.findById(savedCourse.getId())
                .orElse(savedCourse);
    }

    @Override
    @Transactional
    public void deleteCourse(Long id) {
        courseRepository.deleteById(id);
    }

    // ──────────────────────────────────────────────────────────────────
    // Mobile app endpoints: course sections, module lessons, lesson detail
    // ──────────────────────────────────────────────────────────────────

    /**
     * Resolves the currently authenticated user from the security context.
     * Returns null when no authenticated user is present.
     */
    private User getCurrentUser() {
        try {
            Authentication auth = SecurityContextHolder.getContext().getAuthentication();
            if (auth == null || !auth.isAuthenticated()) {
                return null;
            }
            String username = auth.getName();
            return userRepository.findByEmail(username).orElse(null);
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Returns the set of lesson IDs the current user has completed.
     */
    private Set<Long> getCompletedLessonIds() {
        User user = getCurrentUser();
        if (user == null) {
            return Set.of();
        }
        return progressRepository.findCompletedLessonIdsByUserId(user.getId());
    }

    @Override
    @Transactional(readOnly = true)
    public List<CourseSectionDTO> findSectionsByCourseId(Long courseId) {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new RuntimeException("Course not found: " + courseId));

        Set<Long> completedLessonIds = getCompletedLessonIds();

        List<Module> modules = course.getModules() != null
                ? new ArrayList<>(course.getModules())
                : new ArrayList<>();
        modules.sort(Comparator.comparing(Module::getOrderIndex, Comparator.nullsFirst(Integer::compareTo)));

        return modules.stream()
                .map(module -> {
                    Set<Lesson> lessons = module.getLessons() != null ? module.getLessons() : Set.of();
                    int totalLessons = lessons.size();
                    long completedLessons = lessons.stream()
                            .mapToLong(Lesson::getId)
                            .filter(completedLessonIds::contains)
                            .count();

                    Boolean isLocked = module.getIsLocked() != null ? module.getIsLocked() : false;

                    return new CourseSectionDTO(
                            module.getId(),
                            module.getTitle(),
                            module.getDescription(),
                            module.getIcon(),
                            module.getColor(),
                            module.getOrderIndex(),
                            isLocked,
                            totalLessons,
                            (int) completedLessons
                    );
                })
                .collect(Collectors.toList());
    }

    @Override
    @Transactional(readOnly = true)
    public Optional<ModuleLessonsDTO> findModuleLessons(Long moduleId) {
        Module module = moduleRepository.findById(moduleId).orElse(null);
        if (module == null) {
            return Optional.empty();
        }

        Set<Long> completedLessonIds = getCompletedLessonIds();

        List<LessonProgressDTO> lessonDTOs = new ArrayList<>();
        if (module.getLessons() != null) {
            lessonDTOs = module.getLessons().stream()
                    .sorted(Comparator.comparing(Lesson::getOrderIndex, Comparator.nullsFirst(Integer::compareTo)))
                    .map(lesson -> toLessonProgressDTO(lesson, completedLessonIds))
                    .collect(Collectors.toList());
        }

        Boolean isLocked = module.getIsLocked() != null ? module.getIsLocked() : false;

        ModuleLessonsDTO dto = new ModuleLessonsDTO(
                module.getId(),
                module.getTitle(),
                module.getDescription(),
                module.getIcon(),
                module.getColor(),
                module.getOrderIndex(),
                isLocked,
                lessonDTOs
        );
        return Optional.of(dto);
    }

    @Override
    @Transactional(readOnly = true)
    public Optional<LessonProgressDTO> findLessonById(Long lessonId) {
        Lesson lesson = lessonRepository.findById(lessonId).orElse(null);
        if (lesson == null) {
            return Optional.empty();
        }

        Set<Long> completedLessonIds = getCompletedLessonIds();
        return Optional.of(toLessonProgressDTO(lesson, completedLessonIds));
    }

    // ─────────────────────────────────────────────────────────────
    // Admin portal: granular module/lesson CRUD
    // ─────────────────────────────────────────────────────────────

    @Override
    @Transactional
    public Module addModule(Long courseId, ModuleRequest request) {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new RuntimeException("Course not found: " + courseId));

        Module module = new Module();
        applyModuleRequest(module, request);
        module.setCourse(course);
        return moduleRepository.save(module);
    }

    @Override
    @Transactional
    public Module updateModule(Long moduleId, ModuleRequest request) {
        Module module = moduleRepository.findById(moduleId)
                .orElseThrow(() -> new RuntimeException("Module not found: " + moduleId));
        applyModuleRequest(module, request);
        return moduleRepository.save(module);
    }

    private void applyModuleRequest(Module module, ModuleRequest request) {
        module.setTitle(request.getTitle());
        module.setDescription(request.getDescription());
        module.setOrderIndex(request.getOrderIndex());
        module.setIcon(request.getIcon());
        module.setColor(request.getColor());
        module.setIsLocked(request.getIsLocked() != null ? request.getIsLocked() : false);
    }

    @Override
    @Transactional
    public void deleteModule(Long moduleId) {
        Module module = moduleRepository.findById(moduleId).orElse(null);
        if (module == null) return;
        if (module.getLessons() != null) {
            for (Lesson lesson : module.getLessons()) {
                if (lesson.getId() != null) {
                    progressRepository.deleteByLessonId(lesson.getId());
                }
            }
        }
        moduleRepository.deleteById(moduleId);
    }

    @Override
    @Transactional
    public Lesson addLesson(Long moduleId, LessonRequest request) {
        Module module = moduleRepository.findById(moduleId)
                .orElseThrow(() -> new RuntimeException("Module not found: " + moduleId));

        Lesson lesson = new Lesson();
        applyLessonRequest(lesson, request);
        lesson.setModule(module);
        return lessonRepository.save(lesson);
    }

    @Override
    @Transactional
    public Lesson updateLesson(Long lessonId, LessonRequest request) {
        Lesson lesson = lessonRepository.findById(lessonId)
                .orElseThrow(() -> new RuntimeException("Lesson not found: " + lessonId));
        applyLessonRequest(lesson, request);
        return lessonRepository.save(lesson);
    }

    private void applyLessonRequest(Lesson lesson, LessonRequest request) {
        lesson.setTitle(request.getTitle());
        lesson.setHeading(request.getHeading());
        lesson.setContent(request.getContent());
        lesson.setThumbnailUrl(request.getThumbnailUrl());
        lesson.setOrderIndex(request.getOrderIndex());
        lesson.setDurationMinutes(request.getDurationMinutes());
        lesson.setIsLocked(request.getIsLocked() != null ? request.getIsLocked() : false);
        lesson.setIsMandatory(request.getIsMandatory() != null ? request.getIsMandatory() : true);

        // Self-hosted video selection: keep the MediaItem id + source, and resolve
        // videoUrl to the item's relative serve endpoint (the mobile app/admin portal
        // absolutizes it against the API base). External-URL lessons (e.g. YouTube)
        // keep the pasted URL as-is.
        if ("SELF".equalsIgnoreCase(request.getVideoSource()) && request.getVideoId() != null) {
            lesson.setVideoSource("SELF");
            lesson.setVideoId(request.getVideoId());
            Optional<MediaItem> video = mediaItemRepository.findById(request.getVideoId());
            lesson.setVideoUrl(video.isPresent()
                    ? "/api/media/" + video.get().getId() + "/serve"
                    : null);
        } else {
            lesson.setVideoSource("URL");
            lesson.setVideoId(null);
            lesson.setVideoUrl(request.getVideoUrl());
        }

        // Self-hosted PDF selection: the dropdown now lists uploaded MediaItems
        // (the "Create PDF" generator was replaced by direct file uploads), so
        // pdfNoteId resolves against MediaItemRepository, not the old PdfNote table.
        if ("SELF".equalsIgnoreCase(request.getPdfSource()) && request.getPdfNoteId() != null) {
            lesson.setPdfSource("SELF");
            lesson.setPdfNoteId(request.getPdfNoteId());
            Optional<MediaItem> file = mediaItemRepository.findById(request.getPdfNoteId());
            lesson.setPdfNotesUrl(file.isPresent()
                    ? "/api/media/" + file.get().getId() + "/serve"
                    : null);
        } else {
            lesson.setPdfSource("URL");
            lesson.setPdfNoteId(null);
            lesson.setPdfNotesUrl(request.getPdfNotesUrl());
        }
    }

    @Override
    @Transactional
    public void deleteLesson(Long lessonId) {
        progressRepository.deleteByLessonId(lessonId);
        lessonRepository.deleteById(lessonId);
    }

    // ─────────────────────────────────────────────────────────────
    // Admin portal: bulk import (JSON or Excel)
    //
    // Both importers build their entities through applyModuleRequest /
    // applyLessonRequest — the exact code the single add/edit endpoints use — so
    // self-hosted video/PDF resolution, defaults and locking all behave
    // identically whether a module was imported or typed by hand.
    // ─────────────────────────────────────────────────────────────

    @Override
    @Transactional
    public BulkImportResult importModules(Long courseId, MultipartFile file) {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new RuntimeException("Course not found: " + courseId));

        List<BulkImportParser.ParsedRow<ModuleRequest>> rows = BulkImportParser.parseModules(file);

        BulkImportResult result = new BulkImportResult();
        // Rows without an explicit order index continue after the last module
        // already in the course (the same value the "Add Module" form pre-fills),
        // so an import appends instead of colliding with existing content.
        int nextOrder = nextModuleOrderIndex(course);

        for (BulkImportParser.ParsedRow<ModuleRequest> row : rows) {
            if (row.getError() != null) {
                result.addError(rowMessage(row.getNumber(), null, row.getError()));
                continue;
            }
            ModuleRequest request = row.getValue();
            trimModule(request);
            String problem = validateModule(request);
            if (problem != null) {
                result.addError(rowMessage(row.getNumber(), request.getTitle(), problem));
                continue;
            }

            if (request.getOrderIndex() == null) {
                request.setOrderIndex(nextOrder);
            }
            nextOrder = Math.max(nextOrder, request.getOrderIndex() + 1);

            Module module = new Module();
            applyModuleRequest(module, request);
            module.setCourse(course);
            Module savedModule = moduleRepository.save(module);
            result.incrementImported();

            // Nested lessons ride along exactly like a single "Add Lesson" call.
            int lessonOrder = 0;
            if (request.getLessons() != null) {
                for (LessonRequest lessonRequest : request.getLessons()) {
                    if (lessonRequest == null) {
                        continue;
                    }
                    trimLesson(lessonRequest);
                    String lessonProblem = validateLesson(lessonRequest);
                    if (lessonProblem != null) {
                        result.addError(rowMessage(row.getNumber(), request.getTitle(),
                                "lesson \"" + describe(lessonRequest.getTitle()) + "\": " + lessonProblem));
                        continue;
                    }
                    if (lessonRequest.getOrderIndex() == null) {
                        lessonRequest.setOrderIndex(lessonOrder);
                    }
                    lessonOrder = Math.max(lessonOrder, lessonRequest.getOrderIndex() + 1);

                    Lesson lesson = new Lesson();
                    applyLessonRequest(lesson, lessonRequest);
                    lesson.setModule(savedModule);
                    lessonRepository.save(lesson);
                    result.incrementLessonsImported();
                }
            }
        }
        return result;
    }
    @Override
    @Transactional
    public BulkImportResult importLessons(Long moduleId, MultipartFile file) {
        Module target = moduleRepository.findById(moduleId)
                .orElseThrow(() -> new RuntimeException("Module not found: " + moduleId));
        Course course = target.getCourse() != null
                ? courseRepository.findById(target.getCourse().getId()).orElse(null)
                : null;
        Map<String, Module> modules = moduleLookup(course, target);

        List<BulkImportParser.ParsedRow<BulkImportParser.LessonRow>> rows = BulkImportParser.parseLessons(file);

        BulkImportResult result = new BulkImportResult();
        // Running "next free order index" per module: the module's in-memory lesson
        // set does not include what this import has just inserted, so the counter
        // is kept here instead of being re-read from the entity.
        Map<Long, Integer> nextOrderByModule = new HashMap<>();
        for (Module module : modules.values()) {
            nextOrderByModule.putIfAbsent(module.getId(), nextLessonOrderIndex(module));
        }

        for (BulkImportParser.ParsedRow<BulkImportParser.LessonRow> row : rows) {
            if (row.getError() != null) {
                result.addError(rowMessage(row.getNumber(), null, row.getError()));
                continue;
            }
            LessonRequest request = row.getValue().getRequest();
            trimLesson(request);

            Module module = target;
            String ref = row.getValue().getModuleRef();
            if (ref != null) {
                module = modules.get(ref.toLowerCase(Locale.ROOT));
                if (module == null) {
                    result.addError(rowMessage(row.getNumber(), request.getTitle(),
                            "this course has no module \"" + ref + "\""));
                    continue;
                }
            }

            String problem = validateLesson(request);
            if (problem != null) {
                result.addError(rowMessage(row.getNumber(), request.getTitle(), problem));
                continue;
            }

            int nextOrder = nextOrderByModule.getOrDefault(module.getId(), 0);
            if (request.getOrderIndex() == null) {
                request.setOrderIndex(nextOrder);
            }
            nextOrderByModule.put(module.getId(), Math.max(nextOrder, request.getOrderIndex() + 1));

            Lesson lesson = new Lesson();
            applyLessonRequest(lesson, request);
            lesson.setModule(module);
            lessonRepository.save(lesson);
            result.incrementImported();
        }
        return result;
    }
    // ── Bulk import helpers ──────────────────────────────────────

    /** All modules of the course keyed by id, title (lower-cased) and order index. */
    private Map<String, Module> moduleLookup(Course course, Module fallback) {
        Map<String, Module> lookup = new LinkedHashMap<>();
        List<Module> modules = new ArrayList<>();
        if (course != null && course.getModules() != null) {
            modules.addAll(course.getModules());
        }
        if (modules.stream().noneMatch(m -> m.getId() != null && m.getId().equals(fallback.getId()))) {
            modules.add(fallback);
        }
        for (Module module : modules) {
            if (module.getId() != null) {
                lookup.putIfAbsent(String.valueOf(module.getId()), module);
            }
            if (module.getTitle() != null && !module.getTitle().isBlank()) {
                lookup.putIfAbsent(module.getTitle().trim().toLowerCase(Locale.ROOT), module);
            }
            if (module.getOrderIndex() != null) {
                lookup.putIfAbsent(String.valueOf(module.getOrderIndex()), module);
            }
        }
        return lookup;
    }

    /** First free order index after the course's last module (0 when it has none). */
    private int nextModuleOrderIndex(Course course) {
        int highest = -1;
        if (course.getModules() != null) {
            for (Module module : course.getModules()) {
                if (module.getOrderIndex() != null) {
                    highest = Math.max(highest, module.getOrderIndex());
                }
            }
        }
        return highest + 1;
    }

    /** First free order index after the module's last lesson (0 when it has none). */
    private int nextLessonOrderIndex(Module module) {
        int highest = -1;
        if (module.getLessons() != null) {
            for (Lesson lesson : module.getLessons()) {
                if (lesson.getOrderIndex() != null) {
                    highest = Math.max(highest, lesson.getOrderIndex());
                }
            }
        }
        return highest + 1;
    }

    /** "Row 4 (\"Getting started\"): Title is required." — what the admin sees. */
    private static String rowMessage(int number, String title, String problem) {
        String label = "Row " + number;
        if (title != null && !title.isBlank()) {
            label += " (\"" + title.trim() + "\")";
        }
        return label + ": " + problem;
    }

    private static String describe(String title) {
        return title == null || title.isBlank() ? "untitled" : title.trim();
    }
    /** Title and description are the two mandatory fields of a module import. */
    private static String validateModule(ModuleRequest request) {
        if (isBlank(request.getTitle())) {
            return "Title is required.";
        }
        if (isBlank(request.getDescription())) {
            return "Description is required.";
        }
        if (request.getTitle().length() > MAX_TEXT_LENGTH) {
            return "Title must be " + MAX_TEXT_LENGTH + " characters or fewer.";
        }
        if (tooLong(request.getIcon())) {
            return "Icon is too long (max " + MAX_TEXT_LENGTH + " characters).";
        }
        if (tooLong(request.getColor())) {
            return "Color is too long (max " + MAX_TEXT_LENGTH + " characters).";
        }
        if (request.getOrderIndex() != null && request.getOrderIndex() < 0) {
            return "Order index cannot be negative.";
        }
        return null;
    }

    /** Title is the only mandatory field of a lesson; the rest mirrors the manual form. */
    private static String validateLesson(LessonRequest request) {
        if (isBlank(request.getTitle())) {
            return "Title is required.";
        }
        if (request.getTitle().length() > MAX_TEXT_LENGTH) {
            return "Title must be " + MAX_TEXT_LENGTH + " characters or fewer.";
        }
        if (tooLong(request.getHeading())) {
            return "Heading is too long (max " + MAX_TEXT_LENGTH + " characters).";
        }
        if (tooLong(request.getVideoUrl())) {
            return "Video URL is too long (max " + MAX_TEXT_LENGTH + " characters).";
        }
        if (tooLong(request.getThumbnailUrl())) {
            return "Thumbnail URL is too long (max " + MAX_TEXT_LENGTH + " characters).";
        }
        if (tooLong(request.getPdfNotesUrl())) {
            return "PDF notes URL is too long (max " + MAX_TEXT_LENGTH + " characters).";
        }
        if ("SELF".equalsIgnoreCase(request.getVideoSource()) && request.getVideoId() == null) {
            return "Video ID is required when the video source is SELF.";
        }
        if ("SELF".equalsIgnoreCase(request.getPdfSource()) && request.getPdfNoteId() == null) {
            return "PDF note ID is required when the PDF source is SELF.";
        }
        if (request.getOrderIndex() != null && request.getOrderIndex() < 0) {
            return "Order index cannot be negative.";
        }
        if (request.getDurationMinutes() != null && request.getDurationMinutes() < 0) {
            return "Duration cannot be negative.";
        }
        return null;
    }

    private static boolean isBlank(String value) {
        return value == null || value.isBlank();
    }

    private static boolean tooLong(String value) {
        return value != null && value.length() > MAX_TEXT_LENGTH;
    }

    /** Spaces pasted in from a spreadsheet would otherwise show up in the app. */
    private static void trimModule(ModuleRequest request) {
        request.setTitle(trim(request.getTitle()));
        request.setDescription(trim(request.getDescription()));
        request.setIcon(trim(request.getIcon()));
        request.setColor(trim(request.getColor()));
    }

    private static void trimLesson(LessonRequest request) {
        request.setTitle(trim(request.getTitle()));
        request.setHeading(trim(request.getHeading()));
        request.setContent(trim(request.getContent()));
        request.setVideoUrl(trim(request.getVideoUrl()));
        request.setVideoSource(trim(request.getVideoSource()));
        request.setThumbnailUrl(trim(request.getThumbnailUrl()));
        request.setPdfNotesUrl(trim(request.getPdfNotesUrl()));
        request.setPdfSource(trim(request.getPdfSource()));
    }

    private static String trim(String value) {
        return value == null ? null : value.trim();
    }

    private LessonProgressDTO toLessonProgressDTO(Lesson lesson, Set<Long> completedLessonIds) {
        boolean completed = lesson.getId() != null && completedLessonIds.contains(lesson.getId());
        Boolean isLocked = lesson.getIsLocked() != null ? lesson.getIsLocked() : false;
        Boolean isMandatory = lesson.getIsMandatory() != null ? lesson.getIsMandatory() : true;

        return new LessonProgressDTO(
                lesson.getId(),
                lesson.getTitle(),
                lesson.getHeading(),
                lesson.getContent(),
                lesson.getVideoUrl(),
                lesson.getVideoSource(),
                lesson.getDurationMinutes(),
                lesson.getOrderIndex(),
                isLocked,
                isMandatory,
                lesson.getThumbnailUrl(),
                lesson.getPdfNotesUrl(),
                completed
        );
    }
}
