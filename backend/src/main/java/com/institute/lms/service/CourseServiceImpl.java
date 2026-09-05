package com.institute.lms.service;

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
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
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

        // Safely delete existing modules and their lessons (with cascade from DB)
        List<Module> existingModules = course.getModules() != null
                ? new ArrayList<>(course.getModules())
                : new ArrayList<>();
        if (!existingModules.isEmpty()) {
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
