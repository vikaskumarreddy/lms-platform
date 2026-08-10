package com.institute.lms.controller;

import com.institute.lms.dto.course.LessonProgressDTO;
import com.institute.lms.service.CourseService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/lessons")
public class LessonController {
    private final CourseService courseService;

    public LessonController(CourseService courseService) {
        this.courseService = courseService;
    }

    @GetMapping("/{id}")
    public ResponseEntity<LessonProgressDTO> getLessonById(@PathVariable Long id) {
        return courseService.findLessonById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }
}
