package com.institute.lms.controller;

import com.institute.lms.entity.Note;
import com.institute.lms.repository.NoteRepository;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/notes")
public class NoteController {

    private final NoteRepository noteRepository;
    private final UserContext userContext;

    public NoteController(NoteRepository noteRepository, UserContext userContext) {
        this.noteRepository = noteRepository;
        this.userContext = userContext;
    }

    @GetMapping("/user/{userId}")
    public List<Note> getNotesForUser(@PathVariable Long userId) {
        userContext.requireSelfOrAdmin(userId);
        return noteRepository.findByUserIdOrderByUpdatedAtDesc(userId);
    }

    @GetMapping("/user/{userId}/lesson/{lessonId}")
    public List<Note> getNotesForLesson(@PathVariable Long userId, @PathVariable Long lessonId) {
        userContext.requireSelfOrAdmin(userId);
        return noteRepository.findByUserIdAndLessonId(userId, lessonId);
    }

    @PostMapping
    public ResponseEntity<Note> createNote(@RequestBody Map<String, Object> body) {
        Long userId = body.get("userId") != null ? ((Number) body.get("userId")).longValue() : null;
        if (userId == null) {
            return ResponseEntity.badRequest().build();
        }
        userContext.requireSelfOrAdmin(userId);

        Note note = new Note();
        note.setUserId(userId);
        note.setLessonId(body.get("lessonId") != null ? ((Number) body.get("lessonId")).longValue() : null);
        note.setTitle(body.getOrDefault("title", "Untitled Note").toString());
        note.setContent(body.getOrDefault("content", "").toString());
        return ResponseEntity.ok(noteRepository.save(note));
    }

    @PutMapping("/{id}")
    public ResponseEntity<Note> updateNote(@PathVariable Long id, @RequestBody Map<String, Object> body) {
        return noteRepository.findById(id)
                .map(existing -> {
                    userContext.requireSelfOrAdmin(existing.getUserId());
                    if (body.containsKey("title")) existing.setTitle(String.valueOf(body.get("title")));
                    if (body.containsKey("content")) existing.setContent(String.valueOf(body.get("content")));
                    return ResponseEntity.ok(noteRepository.save(existing));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteNote(@PathVariable Long id) {
        Note existing = noteRepository.findById(id).orElse(null);
        if (existing == null) {
            return ResponseEntity.notFound().build();
        }
        userContext.requireSelfOrAdmin(existing.getUserId());
        noteRepository.deleteById(id);
        return ResponseEntity.ok().build();
    }
}
