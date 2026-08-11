package com.institute.lms.controller;

import com.institute.lms.entity.Assignment;
import com.institute.lms.entity.AssignmentSubmission;
import com.institute.lms.entity.User;
import com.institute.lms.repository.AssignmentRepository;
import com.institute.lms.repository.AssignmentSubmissionRepository;
import com.institute.lms.repository.UserRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/assignments")
public class AssignmentController {

    private final AssignmentRepository assignmentRepository;
    private final UserRepository userRepository;
    private final AssignmentSubmissionRepository assignmentSubmissionRepository;

    public AssignmentController(AssignmentRepository assignmentRepository, 
                               UserRepository userRepository,
                               AssignmentSubmissionRepository assignmentSubmissionRepository) {
        this.assignmentRepository = assignmentRepository;
        this.userRepository = userRepository;
        this.assignmentSubmissionRepository = assignmentSubmissionRepository;
    }

    @GetMapping
    public List<Assignment> getAllAssignments() {
        return assignmentRepository.findAll();
    }

    @GetMapping("/batch/{batchId}")
    public List<Assignment> getAssignmentsByBatch(@PathVariable Long batchId) {
        return assignmentRepository.findVisibleToBatch(batchId);
    }

    @GetMapping("/course/{courseId}")
    public List<Assignment> getAssignmentsByCourse(@PathVariable Long courseId) {
        return assignmentRepository.findByCourseId(courseId);
    }

    @GetMapping("/user/{userId}")
    public ResponseEntity<Map<String, Object>> getAssignmentsByUser(@PathVariable Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        // Assignments with no batch restriction ("All Batches" in the admin portal) are
        // visible to every student, in addition to assignments explicitly targeted at the
        // student's own batch. Previously this returned an empty list whenever the student
        // had no batch assigned, hiding "All Batches" assignments entirely.
        List<Assignment> assignments = user.getBatchId() != null
                ? assignmentRepository.findVisibleToBatch(user.getBatchId())
                : assignmentRepository.findAll().stream()
                        .filter(a -> a.getBatchIds() == null || a.getBatchIds().isEmpty())
                        .collect(Collectors.toList());
        
        List<AssignmentSubmission> submissions = assignmentSubmissionRepository.findByUserId(userId);
        Map<Long, AssignmentSubmission> submissionMap = submissions.stream()
                .collect(Collectors.toMap(AssignmentSubmission::getAssignmentId, s -> s));

        LocalDateTime now = LocalDateTime.now();
        
        List<Map<String, Object>> assignmentDetails = assignments.stream()
                .map(assignment -> {
                    Map<String, Object> detail = new LinkedHashMap<>();
                    detail.put("id", assignment.getId());
                    detail.put("title", assignment.getTitle());
                    detail.put("description", assignment.getDescription());
                    detail.put("dueDate", assignment.getDueDate());
                    detail.put("totalMarks", assignment.getTotalMarks());
                    detail.put("batchIds", assignment.getBatchIds());
                    detail.put("courseId", assignment.getCourseId());
                    detail.put("isActive", assignment.getIsActive());
                    detail.put("link", assignment.getLink());
                    
                    AssignmentSubmission submission = submissionMap.get(assignment.getId());
                    if (submission != null) {
                        detail.put("submissionId", submission.getId());
                        detail.put("submittedAt", submission.getSubmittedAt());
                        detail.put("marksObtained", submission.getMarksObtained());
                        detail.put("isGraded", submission.getIsGraded());
                        detail.put("status", "Submitted");
                    } else if (assignment.getDueDate() != null && assignment.getDueDate().isBefore(now)) {
                        detail.put("status", "Overdue");
                    } else {
                        detail.put("status", "Pending");
                    }
                    
                    Map<String, String> links = new LinkedHashMap<>();
                    links.put("self", "/api/assignments/" + assignment.getId());
                    links.put("submission", "/api/assignments/" + assignment.getId() + "/submit");
                    if (assignment.getLink() != null && !assignment.getLink().isEmpty()) {
                        links.put("details", assignment.getLink());
                    }
                    detail.put("_links", links);
                    
                    return detail;
                })
                .collect(Collectors.toList());

        long pendingCount = assignmentDetails.stream().filter(a -> "Pending".equals(a.get("status"))).count();
        long submittedCount = assignmentDetails.stream().filter(a -> "Submitted".equals(a.get("status"))).count();
        long overdueCount = assignmentDetails.stream().filter(a -> "Overdue".equals(a.get("status"))).count();

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("assignments", assignmentDetails);
        response.put("totalAssignments", assignments.size());
        response.put("pendingCount", pendingCount);
        response.put("submittedCount", submittedCount);
        response.put("overdueCount", overdueCount);

        return ResponseEntity.ok(response);
    }

    @GetMapping("/{id}")
    public ResponseEntity<Assignment> getAssignmentById(@PathVariable Long id) {
        return assignmentRepository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public Assignment createAssignment(@RequestBody Assignment assignment) {
        if (assignment.getIsActive() == null) assignment.setIsActive(true);
        return assignmentRepository.save(assignment);
    }

    @PutMapping("/{id}")
    public ResponseEntity<Assignment> updateAssignment(@PathVariable Long id, @RequestBody Assignment assignment) {
        return assignmentRepository.findById(id)
                .map(existing -> {
                    existing.setTitle(assignment.getTitle());
                    existing.setDescription(assignment.getDescription());
                    existing.setDueDate(assignment.getDueDate());
                    existing.setTotalMarks(assignment.getTotalMarks());
                    existing.setBatchIds(assignment.getBatchIds());
                    existing.setCourseId(assignment.getCourseId());
                    existing.setIsActive(assignment.getIsActive());
                    existing.setLink(assignment.getLink());
                    return ResponseEntity.ok(assignmentRepository.save(existing));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteAssignment(@PathVariable Long id) {
        assignmentRepository.deleteById(id);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/{id}/submit")
    public ResponseEntity<Map<String, Object>> submitAssignment(@PathVariable Long id, @RequestBody(required = false) Map<String, Object> body) {
        return assignmentRepository.findById(id)
                .map(assignment -> {
                    Long userId = body != null && body.get("userId") != null
                            ? ((Number) body.get("userId")).longValue() : null;
                    User user = userId != null ? userRepository.findById(userId).orElse(null) : null;

                    AssignmentSubmission submission = new AssignmentSubmission();
                    submission.setAssignmentId(id);
                    if (user != null) submission.setUser(user);
                    submission.setSubmission(body != null ? String.valueOf(body.getOrDefault("submission", "")) : "");
                    submission.setSubmittedAt(LocalDateTime.now());

                    AssignmentSubmission saved = assignmentSubmissionRepository.save(submission);

                    Map<String, Object> resp = new LinkedHashMap<>();
                    resp.put("submissionId", saved.getId());
                    resp.put("submittedAt", saved.getSubmittedAt());
                    resp.put("status", "Submitted");
                    resp.put("message", "Assignment submitted successfully");
                    return ResponseEntity.ok(resp);
                })
                .orElse(ResponseEntity.notFound().build());
    }
}
