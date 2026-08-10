package com.institute.lms.controller;

import com.institute.lms.service.LessonProgressService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/lessons")
public class LessonProgressController {

    private final LessonProgressService lessonProgressService;

    public LessonProgressController(LessonProgressService lessonProgressService) {
        this.lessonProgressService = lessonProgressService;
    }

    @PostMapping("/{lessonId}/toggle-complete")
    public ResponseEntity<Map<String, Object>> toggleComplete(@PathVariable Long lessonId) {
        boolean isNowComplete = lessonProgressService.toggleComplete(lessonId);
        return ResponseEntity.ok(Map.of(
            "completed", isNowComplete,
            "lessonId", lessonId
        ));
    }

    @PostMapping("/{lessonId}/toggle-bookmark")
    public ResponseEntity<Map<String, Object>> toggleBookmark(@PathVariable Long lessonId) {
        boolean isNowBookmarked = lessonProgressService.toggleBookmark(lessonId);
        return ResponseEntity.ok(Map.of(
            "bookmarked", isNowBookmarked,
            "lessonId", lessonId
        ));
    }

    @GetMapping("/{lessonId}/status")
    public ResponseEntity<Map<String, Object>> getLessonStatus(@PathVariable Long lessonId) {
        boolean completed = lessonProgressService.isLessonCompleted(lessonId);
        boolean bookmarked = lessonProgressService.isLessonBookmarked(lessonId);
        return ResponseEntity.ok(Map.of(
            "completed", completed,
            "bookmarked", bookmarked,
            "lessonId", lessonId
        ));
    }
}