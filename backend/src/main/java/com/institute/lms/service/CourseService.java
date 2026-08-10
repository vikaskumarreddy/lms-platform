package com.institute.lms.service;

import com.institute.lms.dto.course.CourseRequest;
import com.institute.lms.dto.course.CourseSectionDTO;
import com.institute.lms.dto.course.LessonProgressDTO;
import com.institute.lms.dto.course.ModuleLessonsDTO;
import com.institute.lms.entity.Course;
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
}
