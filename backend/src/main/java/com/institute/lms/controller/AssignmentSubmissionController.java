package com.institute.lms.controller;

import com.institute.lms.entity.AssignmentSubmission;
import com.institute.lms.entity.User;
import com.institute.lms.repository.AssignmentSubmissionRepository;
import com.institute.lms.repository.UserRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/assignment-submissions")
public class AssignmentSubmissionController {

    private final AssignmentSubmissionRepository submissionRepository;
    private final UserRepository userRepository;

    public AssignmentSubmissionController(AssignmentSubmissionRepository submissionRepository, UserRepository userRepository) {
        this.submissionRepository = submissionRepository;
        this.userRepository = userRepository;
    }

    @GetMapping
    public List<AssignmentSubmission> getAllSubmissions() {
        return submissionRepository.findAll();
    }

    @GetMapping("/student/{studentId}")
    public List<AssignmentSubmission> getSubmissionsByStudent(@PathVariable Long studentId) {
        return submissionRepository.findByUserId(studentId);
    }

    @GetMapping("/assignment/{assignmentId}")
    public List<AssignmentSubmission> getSubmissionsByAssignment(@PathVariable Long assignmentId) {
        return submissionRepository.findByAssignmentId(assignmentId);
    }

    @PostMapping
    public ResponseEntity<AssignmentSubmission> createSubmission(@RequestBody AssignmentSubmission submission) {
        User user = userRepository.findById(submission.getUser().getId())
                .orElseThrow(() -> new RuntimeException("User not found"));
        submission.setUser(user);
        submission.setSubmittedAt(java.time.LocalDateTime.now());
        return ResponseEntity.ok(submissionRepository.save(submission));
    }

    @PutMapping("/{id}")
    public ResponseEntity<AssignmentSubmission> updateSubmission(@PathVariable Long id, @RequestBody AssignmentSubmission submission) {
        return submissionRepository.findById(id)
                .map(existing -> {
                    existing.setSubmission(submission.getSubmission());
                    existing.setMarksObtained(submission.getMarksObtained());
                    existing.setFeedback(submission.getFeedback());
                    existing.setIsGraded(submission.getIsGraded());
                    return ResponseEntity.ok(submissionRepository.save(existing));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteSubmission(@PathVariable Long id) {
        submissionRepository.deleteById(id);
        return ResponseEntity.ok().build();
    }
}