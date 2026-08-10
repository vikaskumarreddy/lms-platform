package com.institute.lms.controller;

import com.institute.lms.dto.course.ModuleLessonsDTO;
import com.institute.lms.service.CourseService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/modules")
public class ModuleController {
    private final CourseService courseService;

    public ModuleController(CourseService courseService) {
        this.courseService = courseService;
    }

    @GetMapping("/{id}")
    public ResponseEntity<ModuleLessonsDTO> getModuleLessons(@PathVariable Long id) {
        return courseService.findModuleLessons(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }
}
