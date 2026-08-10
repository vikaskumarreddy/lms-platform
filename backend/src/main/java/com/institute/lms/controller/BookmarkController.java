package com.institute.lms.controller;

import com.institute.lms.dto.bookmark.BookmarkResponseDTO;
import com.institute.lms.service.BookmarkService;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/bookmarks")
@RequiredArgsConstructor
@Slf4j
public class BookmarkController {

    private final BookmarkService bookmarkService;

    @GetMapping("/user/{userId}")
    public ResponseEntity<List<BookmarkResponseDTO>> getUserBookmarks(@PathVariable Long userId) {
        try {
            List<BookmarkResponseDTO> bookmarks = bookmarkService.getUserBookmarks(userId);
            return ResponseEntity.ok(bookmarks);
        } catch (Exception e) {
            log.error("Error fetching bookmarks for user {}", userId, e);
            return ResponseEntity.ok(List.of()); // Return empty list instead of error
        }
    }

    @GetMapping("/check")
    public ResponseEntity<Boolean> isBookmarked(@RequestParam Long userId, @RequestParam Long lessonId) {
        boolean bookmarked = bookmarkService.isBookmarked(userId, lessonId);
        return ResponseEntity.ok(bookmarked);
    }

    @PostMapping("/toggle")
    public ResponseEntity<Void> toggleBookmark(@RequestParam Long userId, @RequestParam Long lessonId) {
        try {
            bookmarkService.toggleBookmark(userId, lessonId);
            return ResponseEntity.ok().build();
        } catch (EntityNotFoundException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        } catch (Exception e) {
            log.error("Error toggling bookmark", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @DeleteMapping("/user/{userId}/lesson/{lessonId}")
    public ResponseEntity<Void> deleteBookmark(@PathVariable Long userId, @PathVariable Long lessonId) {
        try {
            bookmarkService.deleteBookmark(userId, lessonId);
            return ResponseEntity.noContent().build();
        } catch (EntityNotFoundException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        } catch (Exception e) {
            log.error("Error deleting bookmark", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
}