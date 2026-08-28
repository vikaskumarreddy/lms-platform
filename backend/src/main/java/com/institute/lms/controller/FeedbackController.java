package com.institute.lms.controller;

import com.institute.lms.dto.feedback.FeedbackResponseDTO;
import com.institute.lms.entity.Course;
import com.institute.lms.entity.Feedback;
import com.institute.lms.entity.User;
import com.institute.lms.repository.CourseRepository;
import com.institute.lms.repository.FeedbackRepository;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/feedback")
public class FeedbackController {

    private final FeedbackRepository feedbackRepository;
    private final CourseRepository courseRepository;
    private final UserContext userContext;

    public FeedbackController(FeedbackRepository feedbackRepository, CourseRepository courseRepository, UserContext userContext) {
        this.feedbackRepository = feedbackRepository;
        this.courseRepository = courseRepository;
        this.userContext = userContext;
    }

    /** Admin list of all feedback in this org. */
    @GetMapping
    public List<FeedbackResponseDTO> getAllFeedback() {
        userContext.requireOrgAdmin();
        return feedbackRepository.findAllByOrderByCreatedAtDesc().stream().map(this::toDTO).toList();
    }

    @GetMapping("/me")
    public List<FeedbackResponseDTO> getMyFeedback() {
        User me = userContext.currentUser();
        if (me == null) return List.of();
        return feedbackRepository.findByUserIdOrderByCreatedAtDesc(me.getId()).stream().map(this::toDTO).toList();
    }

    @PostMapping
    public ResponseEntity<FeedbackResponseDTO> createFeedback(@RequestBody Map<String, Object> body) {
        User me = userContext.currentUser();
        if (me == null) return ResponseEntity.status(401).build();

        Feedback feedback = new Feedback();
        feedback.setUser(me);
        feedback.setType(body.getOrDefault("type", "General").toString());
        feedback.setComment(body.getOrDefault("comment", "").toString());
        feedback.setRating(body.get("rating") != null ? ((Number) body.get("rating")).intValue() : null);

        if (body.get("courseId") != null) {
            Long courseId = ((Number) body.get("courseId")).longValue();
            Course course = courseRepository.findById(courseId).orElse(null);
            feedback.setCourse(course);
        }

        return ResponseEntity.ok(toDTO(feedbackRepository.save(feedback)));
    }

    private FeedbackResponseDTO toDTO(Feedback feedback) {
        FeedbackResponseDTO dto = new FeedbackResponseDTO();
        dto.setId(feedback.getId());
        if (feedback.getUser() != null) {
            dto.setUserId(feedback.getUser().getId());
            dto.setStudentName(feedback.getUser().getName());
        }
        if (feedback.getCourse() != null) {
            dto.setCourseId(feedback.getCourse().getId());
            dto.setCourseName(feedback.getCourse().getTitle());
        }
        dto.setType(feedback.getType());
        dto.setRating(feedback.getRating());
        dto.setComment(feedback.getComment());
        dto.setCreatedAt(feedback.getCreatedAt());
        return dto;
    }
}
