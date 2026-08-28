package com.institute.lms.controller;

import com.institute.lms.dto.comment.CommentResponseDTO;
import com.institute.lms.entity.Comment;
import com.institute.lms.entity.Lesson;
import com.institute.lms.entity.User;
import com.institute.lms.repository.CommentRepository;
import com.institute.lms.repository.LessonRepository;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/comments")
public class CommentController {

    private final CommentRepository commentRepository;
    private final LessonRepository lessonRepository;
    private final UserContext userContext;

    public CommentController(CommentRepository commentRepository, LessonRepository lessonRepository, UserContext userContext) {
        this.commentRepository = commentRepository;
        this.lessonRepository = lessonRepository;
        this.userContext = userContext;
    }

    @GetMapping("/lesson/{lessonId}")
    public List<CommentResponseDTO> getCommentsForLesson(@PathVariable Long lessonId) {
        return commentRepository.findByLessonIdOrderByCreatedAtDesc(lessonId).stream().map(this::toDTO).toList();
    }

    @PostMapping
    public ResponseEntity<CommentResponseDTO> createComment(@RequestBody Map<String, Object> body) {
        User me = userContext.currentUser();
        if (me == null) return ResponseEntity.status(401).build();

        Object lessonIdRaw = body.get("lessonId");
        if (lessonIdRaw == null) return ResponseEntity.badRequest().build();
        Lesson lesson = lessonRepository.findById(((Number) lessonIdRaw).longValue()).orElse(null);
        if (lesson == null) return ResponseEntity.badRequest().build();

        Comment comment = new Comment();
        comment.setUser(me);
        comment.setLesson(lesson);
        comment.setContent(body.getOrDefault("content", "").toString());
        if (body.get("parentId") != null) {
            comment.setParentId(((Number) body.get("parentId")).longValue());
        }

        return ResponseEntity.ok(toDTO(commentRepository.save(comment)));
    }

    private CommentResponseDTO toDTO(Comment comment) {
        CommentResponseDTO dto = new CommentResponseDTO();
        dto.setId(comment.getId());
        if (comment.getUser() != null) {
            dto.setUserId(comment.getUser().getId());
            dto.setAuthorName(comment.getUser().getName());
        }
        if (comment.getLesson() != null) {
            dto.setLessonId(comment.getLesson().getId());
        }
        dto.setParentId(comment.getParentId());
        dto.setContent(comment.getContent());
        dto.setCreatedAt(comment.getCreatedAt());
        return dto;
    }
}
