package com.institute.lms.controller;

import com.institute.lms.entity.AssignmentSubmission;
import com.institute.lms.entity.User;
import com.institute.lms.repository.AssignmentSubmissionRepository;
import com.institute.lms.repository.UserRepository;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/assignment-submissions")
public class AssignmentSubmissionController {

    private final AssignmentSubmissionRepository submissionRepository;
    private final UserRepository userRepository;
    private final UserContext userContext;
    private final com.institute.lms.service.subscription.ActivityMeterService activityMeter;

    public AssignmentSubmissionController(AssignmentSubmissionRepository submissionRepository, UserRepository userRepository,
                                          UserContext userContext,
                                          com.institute.lms.service.subscription.ActivityMeterService activityMeter) {
        this.submissionRepository = submissionRepository;
        this.userRepository = userRepository;
        this.userContext = userContext;
        this.activityMeter = activityMeter;
    }

    @GetMapping
    public List<AssignmentSubmission> getAllSubmissions() {
        List<AssignmentSubmission> all = submissionRepository.findAll();
        if (userContext.isFaculty()) {
            Long batchId = userContext.facultyBatchId();
            if (batchId == null) return List.of();
            return all.stream()
                    .filter(s -> s.getUser() != null && batchId.equals(s.getUser().getBatchId()))
                    .toList();
        }
        return all;
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
        AssignmentSubmission saved = submissionRepository.save(submission);

        // Submitting an assessment counts as activity for the billing month. Metered
        // after the save so a metering problem can never cost a student their
        // submission.
        if (user.getRole() == User.UserRole.STUDENT) {
            activityMeter.record(user.getOrganizationId(), user.getId(),
                    com.institute.lms.subscription.ActivityType.ASSESSMENT_SUBMISSION);
        }
        return ResponseEntity.ok(saved);
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