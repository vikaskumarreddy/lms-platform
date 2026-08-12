package com.institute.lms.service;

import com.institute.lms.dto.course.CourseRequest;
import com.institute.lms.dto.course.CourseSectionDTO;
import com.institute.lms.dto.course.LessonProgressDTO;
import com.institute.lms.dto.course.LessonRequest;
import com.institute.lms.dto.course.ModuleLessonsDTO;
import com.institute.lms.dto.course.ModuleRequest;
import com.institute.lms.entity.Course;
import com.institute.lms.entity.Lesson;
import com.institute.lms.entity.Module;
import java.util.List;
import java.util.Optional;

public interface CourseService {
    List<Course> findAll();
    Optional<Course> findById(Long id);
    Course createCourse(CourseRequest request);
    Course updateCourse(Long id, CourseRequest request);
    void deleteCourse(Long id);

    /**
     * Returns the modules (sections) of a course enriched with lesson progress
     * for the currently authenticated user.
     */
    List<CourseSectionDTO> findSectionsByCourseId(Long courseId);

    /**
     * Returns a module (section) with its lessons, each enriched with the
     * current user's completion status.
     */
    Optional<ModuleLessonsDTO> findModuleLessons(Long moduleId);

    /**
     * Returns a single lesson enriched with the current user's completion status.
     */
    Optional<LessonProgressDTO> findLessonById(Long lessonId);

    // ─────────────────────────────────────────────────────────────
    // Admin portal: granular module/lesson CRUD (add/edit/delete a single
    // module or lesson without resaving/recreating the entire course tree).
    // ─────────────────────────────────────────────────────────────

    Module addModule(Long courseId, ModuleRequest request);
    Module updateModule(Long moduleId, ModuleRequest request);
    void deleteModule(Long moduleId);

    Lesson addLesson(Long moduleId, LessonRequest request);
    Lesson updateLesson(Long lessonId, LessonRequest request);
    void deleteLesson(Long lessonId);
}
