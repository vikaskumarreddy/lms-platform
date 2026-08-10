package com.institute.lms.controller;

import com.institute.lms.dto.course.CourseRequest;
import com.institute.lms.dto.course.CourseSectionDTO;
import com.institute.lms.dto.course.LessonProgressDTO;
import com.institute.lms.dto.course.ModuleLessonsDTO;
import com.institute.lms.entity.Course;
import com.institute.lms.service.CourseService;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/courses")
public class CourseController {
    private final CourseService courseService;

    public CourseController(CourseService courseService) {
        this.courseService = courseService;
    }

    @GetMapping
    @Transactional
    public List<Course> getAllCourses() {
        return courseService.findAll();
    }

    @GetMapping("/{id}")
    @Transactional
    public ResponseEntity<Course> getCourseById(@PathVariable Long id) {
        return courseService.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/{id}/sections")
    public List<CourseSectionDTO> getCourseSections(@PathVariable Long id) {
        return courseService.findSectionsByCourseId(id);
    }

    @PostMapping
    public Course createCourse(@RequestBody CourseRequest request) {
        return courseService.createCourse(request);
    }

    @PutMapping("/{id}")
    public ResponseEntity<Course> updateCourse(@PathVariable Long id, @RequestBody CourseRequest request) {
        try {
            return ResponseEntity.ok(courseService.updateCourse(id, request));
        } catch (RuntimeException e) {
            e.printStackTrace();
            return ResponseEntity.notFound().build();
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteCourse(@PathVariable Long id) {
        courseService.deleteCourse(id);
        return ResponseEntity.ok().build();
    }
}