package com.institute.lms.controller;

import com.institute.lms.entity.Note;
import com.institute.lms.repository.NoteRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/notes")
public class NoteController {

    private final NoteRepository noteRepository;

    public NoteController(NoteRepository noteRepository) {
        this.noteRepository = noteRepository;
    }

    @GetMapping("/user/{userId}")
    public List<Note> getNotesForUser(@PathVariable Long userId) {
        return noteRepository.findByUserIdOrderByUpdatedAtDesc(userId);
    }

    @GetMapping("/user/{userId}/lesson/{lessonId}")
    public List<Note> getNotesForLesson(@PathVariable Long userId, @PathVariable Long lessonId) {
        return noteRepository.findByUserIdAndLessonId(userId, lessonId);
    }

    @PostMapping
    public ResponseEntity<Note> createNote(@RequestBody Map<String, Object> body) {
        Note note = new Note();
        note.setUserId(body.get("userId") != null ? ((Number) body.get("userId")).longValue() : null);
        note.setLessonId(body.get("lessonId") != null ? ((Number) body.get("lessonId")).longValue() : null);
        note.setTitle(body.getOrDefault("title", "Untitled Note").toString());
        note.setContent(body.getOrDefault("content", "").toString());
        if (note.getUserId() == null) {
            return ResponseEntity.badRequest().build();
        }
        return ResponseEntity.ok(noteRepository.save(note));
    }

    @PutMapping("/{id}")
    public ResponseEntity<Note> updateNote(@PathVariable Long id, @RequestBody Map<String, Object> body) {
        return noteRepository.findById(id)
                .map(existing -> {
                    if (body.containsKey("title")) existing.setTitle(String.valueOf(body.get("title")));
                    if (body.containsKey("content")) existing.setContent(String.valueOf(body.get("content")));
                    return ResponseEntity.ok(noteRepository.save(existing));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteNote(@PathVariable Long id) {
        if (!noteRepository.existsById(id)) {
            return ResponseEntity.notFound().build();
        }
        noteRepository.deleteById(id);
        return ResponseEntity.ok().build();
    }
}
