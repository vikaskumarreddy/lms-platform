package com.institute.lms.controller;

import com.institute.lms.dto.course.CourseRequest;
import com.institute.lms.dto.course.CourseSectionDTO;
import com.institute.lms.dto.course.LessonProgressDTO;
import com.institute.lms.dto.course.ModuleLessonsDTO;
import com.institute.lms.entity.Course;
import com.institute.lms.entity.User;
import com.institute.lms.service.CourseService;
import com.institute.lms.util.UserContext;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/courses")
public class CourseController {
    private final CourseService courseService;
    private final UserContext userContext;

    public CourseController(CourseService courseService, UserContext userContext) {
        this.courseService = courseService;
        this.userContext = userContext;
    }

    @GetMapping
    @Transactional
    public List<Course> getAllCourses() {
        List<Course> courses = courseService.findAll();
        // Faculty (INSTRUCTOR) users only see courses they own.
        if (userContext.isFaculty()) {
            User u = userContext.currentUser();
            Long instructorId = u != null ? u.getId() : null;
            if (instructorId == null) return List.of();
            courses = courses.stream()
                    .filter(c -> c.getInstructorId() != null && c.getInstructorId().equals(instructorId))
                    .collect(Collectors.toList());
        }
        return courses;
    }

    @GetMapping("/{id}")
    @Transactional
    public ResponseEntity<Course> getCourseById(@PathVariable Long id) {
        return courseService.findById(id)
                .filter(c -> canAccessCourse(c))
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/{id}/sections")
    public List<CourseSectionDTO> getCourseSections(@PathVariable Long id) {
        return courseService.findSectionsByCourseId(id);
    }

    @PostMapping
    public Course createCourse(@RequestBody CourseRequest request) {
        userContext.requireOrgAdminOrFaculty();
        // Instructors can only create courses for themselves; the instructorId
        // field is forced to the current user regardless of the request body.
        if (userContext.isFaculty()) {
            User u = userContext.currentUser();
            if (u != null) {
                request.setInstructorId(u.getId());
            }
        }
        return courseService.createCourse(request);
    }

    @PutMapping("/{id}")
    public ResponseEntity<Course> updateCourse(@PathVariable Long id, @RequestBody CourseRequest request) {
        userContext.requireOrgAdminOrFaculty();
        // Instructors can only update their own courses.
        if (userContext.isFaculty()) {
            return courseService.findById(id)
                    .filter(this::canAccessCourse)
                    .map(c -> {
                        try {
                            return ResponseEntity.ok(courseService.updateCourse(id, request));
                        } catch (RuntimeException e) {
                            e.printStackTrace();
                            return ResponseEntity.notFound().<Course>build();
                        }
                    })
                    .orElse(ResponseEntity.status(HttpStatus.FORBIDDEN).build());
        }
        try {
            return ResponseEntity.ok(courseService.updateCourse(id, request));
        } catch (RuntimeException e) {
            e.printStackTrace();
            return ResponseEntity.notFound().build();
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteCourse(@PathVariable Long id) {
        userContext.requireOrgAdminOrFaculty();
        // Instructors can only delete their own courses.
        if (userContext.isFaculty()) {
            boolean allowed = courseService.findById(id)
                    .filter(this::canAccessCourse)
                    .isPresent();
            if (!allowed) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
            }
        }
        courseService.deleteCourse(id);
        return ResponseEntity.ok().build();
    }

    /**
     * Checks whether the current Faculty user is allowed to access (view/edit/delete)
     * the given course. Instructors can only access courses they created.
     * Non-faculty (admins) always have access.
     */
    private boolean canAccessCourse(Course course) {
        if (!userContext.isFaculty()) return true;
        User u = userContext.currentUser();
        if (u == null) return false;
        return course.getInstructorId() != null && course.getInstructorId().equals(u.getId());
    }
}
