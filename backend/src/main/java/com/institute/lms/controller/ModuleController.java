package com.institute.lms.controller;

import com.institute.lms.dto.course.ModuleLessonsDTO;
import com.institute.lms.dto.course.ModuleRequest;
import com.institute.lms.entity.Module;
import com.institute.lms.service.CourseService;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/modules")
public class ModuleController {
    private final CourseService courseService;
    private final UserContext userContext;

    public ModuleController(CourseService courseService, UserContext userContext) {
        this.courseService = courseService;
        this.userContext = userContext;
    }

    @GetMapping("/{id}")
    public ResponseEntity<ModuleLessonsDTO> getModuleLessons(@PathVariable Long id) {
        return courseService.findModuleLessons(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    /** Admin portal: add a single module to a course without resaving the whole course tree. */
    @PostMapping("/course/{courseId}")
    public ResponseEntity<Module> addModule(@PathVariable Long courseId, @RequestBody ModuleRequest request) {
        userContext.requireOrgAdminOrFaculty();
        try {
            return ResponseEntity.ok(courseService.addModule(courseId, request));
        } catch (RuntimeException e) {
            return ResponseEntity.notFound().build();
        }
    }

    /** Admin portal: edit a single module in place. */
    @PutMapping("/{id}")
    public ResponseEntity<Module> updateModule(@PathVariable Long id, @RequestBody ModuleRequest request) {
        userContext.requireOrgAdminOrFaculty();
        try {
            return ResponseEntity.ok(courseService.updateModule(id, request));
        } catch (RuntimeException e) {
            return ResponseEntity.notFound().build();
        }
    }

    /** Admin portal: delete a single module (and its lessons) in place. */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteModule(@PathVariable Long id) {
        userContext.requireOrgAdminOrFaculty();
        courseService.deleteModule(id);
        return ResponseEntity.ok().build();
    }
}
