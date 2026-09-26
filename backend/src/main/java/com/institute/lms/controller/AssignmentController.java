package com.institute.lms.controller;

import com.institute.lms.entity.AssessmentType;
import com.institute.lms.entity.Assignment;
import com.institute.lms.entity.AssignmentSubmission;
import com.institute.lms.entity.User;
import com.institute.lms.repository.AssignmentRepository;
import com.institute.lms.repository.AssignmentSubmissionRepository;
import com.institute.lms.repository.UserRepository;
import com.institute.lms.service.AssessmentPaperService;
import com.institute.lms.service.NotificationService;
import com.institute.lms.util.OrganizationContext;
import com.institute.lms.util.UserContext;
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
    private final UserContext userContext;
    private final OrganizationContext organizationContext;
    private final AssessmentPaperService paperService;
    private final NotificationService notificationService;

    public AssignmentController(AssignmentRepository assignmentRepository, 
                               UserRepository userRepository,
                               AssignmentSubmissionRepository assignmentSubmissionRepository,
                               UserContext userContext,
                               OrganizationContext organizationContext,
                               AssessmentPaperService paperService,
                                NotificationService notificationService) {
        this.assignmentRepository = assignmentRepository;
        this.userRepository = userRepository;
        this.assignmentSubmissionRepository = assignmentSubmissionRepository;
        this.userContext = userContext;
        this.organizationContext = organizationContext;
        this.paperService = paperService;
        this.notificationService = notificationService;
    }

    @GetMapping
    public List<Assignment> getAllAssignments() {
        // Faculty are scoped to the assignments visible to their own batch.
        if (userContext.isFaculty()) {
            Long batchId = userContext.facultyBatchId();
            if (batchId == null) {
                return assignmentRepository.findAll().stream()
                        .filter(a -> a.getBatchIds() == null || a.getBatchIds().isEmpty())
                        .collect(Collectors.toList());
            }
            return assignmentRepository.findVisibleToBatch(batchId, organizationContext.getCurrentOrgId());
        }
        return assignmentRepository.findAll();
    }

    @GetMapping("/batch/{batchId}")
    public List<Assignment> getAssignmentsByBatch(@PathVariable Long batchId) {
        return assignmentRepository.findVisibleToBatch(batchId, organizationContext.getCurrentOrgId());
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
                ? assignmentRepository.findVisibleToBatch(user.getBatchId(), organizationContext.getCurrentOrgId())
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
                    detail.put("deliveryMode", assignment.getDeliveryMode() != null
                            ? assignment.getDeliveryMode().name() : "WEB");
                    boolean inApp = assignment.getDeliveryMode() == com.institute.lms.entity.DeliveryMode.IN_APP;
                    detail.put("questionCount", inApp
                            ? paperService.questionCount(AssessmentType.ASSIGNMENT, assignment.getId()) : 0L);
                    
                    AssignmentSubmission submission = submissionMap.get(assignment.getId());
                    if (submission != null) {
                        detail.put("submissionId", submission.getId());
                        detail.put("submittedAt", submission.getSubmittedAt());
                        detail.put("marksObtained", submission.getMarksObtained());
                        detail.put("isGraded", submission.getIsGraded());
                        detail.put("status", Boolean.TRUE.equals(submission.getIsGraded()) ? "Graded" : "Submitted");
                    } else if (assignment.getDueDate() != null && assignment.getDueDate().isBefore(now)) {
                        detail.put("status", "Overdue");
                    } else {
                        detail.put("status", "Pending");
                    }
                    
                    Map<String, String> links = new LinkedHashMap<>();
                    links.put("self", "/api/assignments/" + assignment.getId());
                    links.put("submission", "/api/assignments/" + assignment.getId() + "/submit");
                    if (inApp) {
                        // In-app papers are answered inside the app, never in the browser.
                        links.put("paper", "/api/assessments/assignments/" + assignment.getId() + "/paper");
                        links.put("attempt", "/api/assessments/assignments/" + assignment.getId() + "/attempt");
                        links.put("review", "/api/assessments/assignments/" + assignment.getId() + "/review");
                    } else if (assignment.getLink() != null && !assignment.getLink().isEmpty()) {
                        links.put("details", assignment.getLink());
                    }
                    detail.put("_links", links);
                    
                    return detail;
                })
                .collect(Collectors.toList());

        long pendingCount = assignmentDetails.stream().filter(a -> "Pending".equals(a.get("status"))).count();
        long submittedCount = assignmentDetails.stream().filter(a -> "Submitted".equals(a.get("status")) || "Graded".equals(a.get("status"))).count();
        long gradedCount = assignmentDetails.stream().filter(a -> "Graded".equals(a.get("status"))).count();
        long overdueCount = assignmentDetails.stream().filter(a -> "Overdue".equals(a.get("status"))).count();

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("assignments", assignmentDetails);
        response.put("totalAssignments", assignments.size());
        response.put("pendingCount", pendingCount);
        response.put("submittedCount", submittedCount);
        response.put("gradedCount", gradedCount);
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
        Assignment saved = assignmentRepository.save(assignment);

        // Tell the students it was published to. An empty batch list means "All
        // Batches" in the admin portal, which audienceForBatches reads as everyone.
        notificationService.safeNotify(
                notificationService.audienceForBatches(saved.getBatchIds()),
                "New assignment: " + saved.getTitle(),
                saved.getDueDate() != null
                        ? "Due " + saved.getDueDate().toLocalDate() + ". Open the app to start."
                        : "A new assignment has been posted.",
                "assignment", "/assignments", "BATCH", saved.getId());

        return saved;
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
                    if (assignment.getDeliveryMode() != null) existing.setDeliveryMode(assignment.getDeliveryMode());
                    return ResponseEntity.ok(assignmentRepository.save(existing));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteAssignment(@PathVariable Long id) {
        // The paper points back by (type, id) rather than a FK, so it has to be swept here.
        paperService.deletePaper(AssessmentType.ASSIGNMENT, id);
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
