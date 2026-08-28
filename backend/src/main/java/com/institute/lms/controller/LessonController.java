package com.institute.lms.controller;

import com.institute.lms.dto.course.LessonProgressDTO;
import com.institute.lms.dto.course.LessonRequest;
import com.institute.lms.entity.Lesson;
import com.institute.lms.service.CourseService;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/lessons")
public class LessonController {
    private final CourseService courseService;
    private final UserContext userContext;

    public LessonController(CourseService courseService, UserContext userContext) {
        this.courseService = courseService;
        this.userContext = userContext;
    }

    @GetMapping("/{id}")
    public ResponseEntity<LessonProgressDTO> getLessonById(@PathVariable Long id) {
        return courseService.findLessonById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    /** Admin portal: add a single lesson to a module without resaving the whole course tree. */
    @PostMapping("/module/{moduleId}")
    public ResponseEntity<Lesson> addLesson(@PathVariable Long moduleId, @RequestBody LessonRequest request) {
        userContext.requireOrgAdminOrFaculty();
        try {
            return ResponseEntity.ok(courseService.addLesson(moduleId, request));
        } catch (RuntimeException e) {
            return ResponseEntity.notFound().build();
        }
    }

    /** Admin portal: edit a single lesson in place. */
    @PutMapping("/{id}")
    public ResponseEntity<Lesson> updateLesson(@PathVariable Long id, @RequestBody LessonRequest request) {
        userContext.requireOrgAdminOrFaculty();
        try {
            return ResponseEntity.ok(courseService.updateLesson(id, request));
        } catch (RuntimeException e) {
            return ResponseEntity.notFound().build();
        }
    }

    /** Admin portal: delete a single lesson in place. */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteLesson(@PathVariable Long id) {
        userContext.requireOrgAdminOrFaculty();
        courseService.deleteLesson(id);
        return ResponseEntity.ok().build();
    }
}
