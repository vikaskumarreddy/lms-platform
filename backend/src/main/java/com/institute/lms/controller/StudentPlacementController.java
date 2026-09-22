package com.institute.lms.controller;

import com.institute.lms.entity.PlacementDrive;
import com.institute.lms.entity.StudentPlacement;
import com.institute.lms.entity.User;
import com.institute.lms.repository.PlacementDriveRepository;
import com.institute.lms.repository.StudentPlacementRepository;
import com.institute.lms.repository.UserRepository;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/student-placements")
public class StudentPlacementController {

    private final StudentPlacementRepository placementRepository;
    private final UserRepository userRepository;
    private final PlacementDriveRepository placementDriveRepository;
    private final com.institute.lms.repository.AttendanceRepository attendanceRepository;
    private final com.institute.lms.repository.EnrollmentRepository enrollmentRepository;
    private final com.institute.lms.repository.ExamResultRepository examResultRepository;
    private final com.institute.lms.repository.AssignmentSubmissionRepository assignmentSubmissionRepository;
    private final com.institute.lms.service.subscription.ActivityMeterService activityMeter;
    private final UserContext userContext;

    public StudentPlacementController(StudentPlacementRepository placementRepository,
                                       UserRepository userRepository,
                                       PlacementDriveRepository placementDriveRepository,
                                       com.institute.lms.repository.AttendanceRepository attendanceRepository,
                                       com.institute.lms.repository.EnrollmentRepository enrollmentRepository,
                                       com.institute.lms.repository.ExamResultRepository examResultRepository,
                                       com.institute.lms.repository.AssignmentSubmissionRepository assignmentSubmissionRepository,
                                       com.institute.lms.service.subscription.ActivityMeterService activityMeter,
                                       UserContext userContext) {
        this.placementRepository = placementRepository;
        this.userRepository = userRepository;
        this.placementDriveRepository = placementDriveRepository;
        this.attendanceRepository = attendanceRepository;
        this.enrollmentRepository = enrollmentRepository;
        this.examResultRepository = examResultRepository;
        this.assignmentSubmissionRepository = assignmentSubmissionRepository;
        this.activityMeter = activityMeter;
        this.userContext = userContext;
    }

    @GetMapping
    public List<StudentPlacement> getAllPlacements() {
        return placementRepository.findAll();
    }

    @GetMapping("/student/{studentId}")
    public List<StudentPlacement> getPlacementsByStudent(@PathVariable Long studentId) {
        return placementRepository.findByUserId(studentId);
    }

    @GetMapping("/placed")
    public long getPlacedCount() {
        return placementRepository.countByIsPlacedTrue();
    }

    /**
     * Placement overview for a student: all placement drives posted since the
     * student joined (createdAt), tagged with their application status.
     */
    @GetMapping("/overview/{studentId}")
    public ResponseEntity<Map<String, Object>> getPlacementOverview(@PathVariable Long studentId) {
        User user = userRepository.findById(studentId).orElse(null);
        if (user == null) {
            return ResponseEntity.notFound().build();
        }
        LocalDateTime since = user.getCreatedAt() != null ? user.getCreatedAt() : LocalDateTime.now().minusYears(5);

        List<PlacementDrive> drives = placementDriveRepository.findAll().stream()
                .filter(d -> d.getCreatedAt() == null || !d.getCreatedAt().isBefore(since))
                .toList();

        List<StudentPlacement> applications = placementRepository.findByUserId(studentId);
        Map<Long, StudentPlacement> byDrive = new LinkedHashMap<>();
        for (StudentPlacement sp : applications) {
            if (sp.getDriveId() != null) byDrive.put(sp.getDriveId(), sp);
        }

        long openCount = 0, appliedCount = 0, selectedCount = 0, rejectedCount = 0;
        List<Map<String, Object>> items = new java.util.ArrayList<>();
        for (PlacementDrive drive : drives) {
            StudentPlacement application = byDrive.get(drive.getId());
            String status = application != null ? application.getStatus().name() : "OPEN";
            switch (status) {
                case "APPLIED" -> appliedCount++;
                case "SELECTED", "OFFER_EXTENDED" -> selectedCount++;
                case "REJECTED" -> rejectedCount++;
                default -> openCount++;
            }
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("driveId", drive.getId());
            item.put("companyName", drive.getCompanyName());
            item.put("role", drive.getRole());
            item.put("status", status);
            item.put("postedAt", drive.getCreatedAt());
            items.add(item);
        }

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("totalPosted", drives.size());
        response.put("openCount", openCount);
        response.put("appliedCount", appliedCount);
        response.put("selectedCount", selectedCount);
        response.put("rejectedCount", rejectedCount);
        response.put("items", items);
        return ResponseEntity.ok(response);
    }

    /**
     * Student applies to a placement drive, verifying criteria thresholds,
     * calculating ATS match score, and creating/updating their application record.
     */
    @PostMapping("/apply")
    public ResponseEntity<StudentPlacement> applyToDrive(@RequestBody Map<String, Object> body) {
        Long userId = body.get("userId") != null ? ((Number) body.get("userId")).longValue() : null;
        Long driveId = body.get("driveId") != null ? ((Number) body.get("driveId")).longValue() : null;
        if (userId == null || driveId == null) {
            return ResponseEntity.badRequest().build();
        }
        User user = userRepository.findById(userId).orElseThrow(() -> new RuntimeException("User not found"));
        PlacementDrive drive = placementDriveRepository.findById(driveId).orElseThrow(() -> new RuntimeException("Drive not found"));

        // 1. Check drive status and deadline
        if (drive.getIsActive() != null && !drive.getIsActive()) {
            throw new org.springframework.web.server.ResponseStatusException(
                    org.springframework.http.HttpStatus.BAD_REQUEST, "This placement drive is currently inactive.");
        }
        if (drive.getDeadline() != null && drive.getDeadline().isBefore(LocalDateTime.now())) {
            throw new org.springframework.web.server.ResponseStatusException(
                    org.springframework.http.HttpStatus.BAD_REQUEST, "Application deadline has already passed.");
        }

        // 2. Automated Eligibility Criteria Check
        long totalAtt = attendanceRepository.countByUserId(userId);
        long presentAtt = attendanceRepository.countByUserIdAndPresentTrue(userId);
        double attendancePct = totalAtt > 0 ? (presentAtt * 100.0 / totalAtt) : 100.0;
        if (drive.getMinAttendancePercent() != null && attendancePct < drive.getMinAttendancePercent()) {
            throw new org.springframework.web.server.ResponseStatusException(
                    org.springframework.http.HttpStatus.BAD_REQUEST,
                    String.format("Attendance requirement not met: %.1f%% (minimum required: %.1f%%)",
                            attendancePct, drive.getMinAttendancePercent()));
        }

        List<com.institute.lms.entity.Enrollment> enrollments = enrollmentRepository.findByUserId(userId);
        double courseCompletionPct = enrollments.isEmpty() ? 100.0 :
                enrollments.stream().mapToInt(e -> e.getProgressPercentage() != null ? e.getProgressPercentage() : 0).average().orElse(0.0);
        if (drive.getMinCourseCompletionPercent() != null && courseCompletionPct < drive.getMinCourseCompletionPercent()) {
            throw new org.springframework.web.server.ResponseStatusException(
                    org.springframework.http.HttpStatus.BAD_REQUEST,
                    String.format("Course completion requirement not met: %.1f%% (minimum required: %.1f%%)",
                            courseCompletionPct, drive.getMinCourseCompletionPercent()));
        }

        List<com.institute.lms.entity.ExamResult> examResults = examResultRepository.findByUserId(userId);
        double examAvgPct = examResults.isEmpty() ? 100.0 :
                examResults.stream().filter(r -> r.getPercentage() != null).mapToDouble(com.institute.lms.entity.ExamResult::getPercentage).average().orElse(100.0);
        if (drive.getMinExamAvgPercent() != null && examAvgPct < drive.getMinExamAvgPercent()) {
            throw new org.springframework.web.server.ResponseStatusException(
                    org.springframework.http.HttpStatus.BAD_REQUEST,
                    String.format("Exam score average not met: %.1f%% (minimum required: %.1f%%)",
                            examAvgPct, drive.getMinExamAvgPercent()));
        }

        List<com.institute.lms.entity.AssignmentSubmission> submissions = assignmentSubmissionRepository.findByUserId(userId);
        double assignmentAvgPct = submissions.isEmpty() ? 100.0 :
                submissions.stream().filter(s -> s.getMarksObtained() != null).mapToInt(com.institute.lms.entity.AssignmentSubmission::getMarksObtained).average().orElse(100.0);
        if (drive.getMinAssignmentAvgPercent() != null && assignmentAvgPct < drive.getMinAssignmentAvgPercent()) {
            throw new org.springframework.web.server.ResponseStatusException(
                    org.springframework.http.HttpStatus.BAD_REQUEST,
                    String.format("Assignment score average not met: %.1f%% (minimum required: %.1f%%)",
                            assignmentAvgPct, drive.getMinAssignmentAvgPercent()));
        }

        // 3. ATS Match Score Calculation
        String targetKeywords = ((drive.getRole() != null ? drive.getRole() : "") + " " +
                (drive.getDescription() != null ? drive.getDescription() : "") + " " +
                (drive.getEligibility() != null ? drive.getEligibility() : "")).toLowerCase();

        String candidateData = ((user.getName() != null ? user.getName() : "") + " " +
                (user.getEmail() != null ? user.getEmail() : "")).toLowerCase();
        if (body.get("resumeText") != null) {
            candidateData += " " + body.get("resumeText").toString().toLowerCase();
        }
        if (body.get("skills") != null) {
            candidateData += " " + body.get("skills").toString().toLowerCase();
        }

        double keywordScore = 65.0;
        if (!targetKeywords.isBlank() && !candidateData.isBlank()) {
            String[] tokens = targetKeywords.split("[\\s,;\\.\\(\\)\\[\\]\\-]+");
            int matches = 0;
            int meaningfulTokens = 0;
            for (String token : tokens) {
                if (token.length() > 3) {
                    meaningfulTokens++;
                    if (candidateData.contains(token)) {
                        matches++;
                    }
                }
            }
            if (meaningfulTokens > 0) {
                double matchRatio = (double) matches / meaningfulTokens;
                keywordScore = Math.min(100.0, 50.0 + (matchRatio * 50.0));
            }
        }

        double computedAts = (keywordScore * 0.4) + (attendancePct * 0.2) + (examAvgPct * 0.2) + (courseCompletionPct * 0.2);
        computedAts = Math.round(Math.min(99.0, Math.max(45.0, computedAts)) * 10.0) / 10.0;

        // 4. Save Application
        StudentPlacement application = placementRepository.findByUserIdAndDriveId(userId, driveId)
                .orElseGet(StudentPlacement::new);
        application.setUser(user);
        application.setDriveId(driveId);
        application.setCompanyName(drive.getCompanyName());
        application.setRole(drive.getRole());
        application.setPackageAmount(drive.getPackageAmount() != null ? drive.getPackageAmount().doubleValue() : null);
        application.setStatus(StudentPlacement.Status.APPLIED);
        application.setHiringStage("APPLIED");
        application.setAtsScore(computedAts);
        if (body.get("resumeUrl") != null) {
            application.setResumeUrl(body.get("resumeUrl").toString());
        }
        application.setIsPlaced(false);
        StudentPlacement saved = placementRepository.save(application);

        // Applying to a placement drive counts as activity for the billing month.
        if (user.getRole() == User.UserRole.STUDENT) {
            activityMeter.record(user.getOrganizationId(), user.getId(),
                    com.institute.lms.subscription.ActivityType.PLACEMENT_APPLICATION);
        }
        return ResponseEntity.ok(saved);
    }

    /**
     * External Recruiter Portal View (Token authenticated)
     */
    @GetMapping("/recruiter/{token}")
    public ResponseEntity<Map<String, Object>> getRecruiterView(@PathVariable String token) {
        PlacementDrive drive = placementDriveRepository.findByRecruiterToken(token)
                .orElseThrow(() -> new org.springframework.web.server.ResponseStatusException(
                        org.springframework.http.HttpStatus.NOT_FOUND, "Recruiter link not found or expired"));

        List<StudentPlacement> applications = placementRepository.findByDriveId(drive.getId());
        List<Map<String, Object>> candidateList = new java.util.ArrayList<>();
        long shortlistedCount = 0, techRoundCount = 0, offerCount = 0, rejectedCount = 0;

        for (StudentPlacement app : applications) {
            Map<String, Object> candidate = new LinkedHashMap<>();
            candidate.put("id", app.getId());
            candidate.put("userId", app.getUser() != null ? app.getUser().getId() : null);
            candidate.put("studentName", app.getUser() != null ? app.getUser().getName() : "Applicant");
            candidate.put("email", app.getUser() != null ? app.getUser().getEmail() : "");
            candidate.put("phone", app.getUser() != null ? app.getUser().getPhone() : "");
            candidate.put("status", app.getStatus() != null ? app.getStatus().name() : "APPLIED");
            candidate.put("hiringStage", app.getHiringStage() != null ? app.getHiringStage() : "APPLIED");
            candidate.put("atsScore", app.getAtsScore() != null ? app.getAtsScore() : 75.0);
            candidate.put("resumeUrl", app.getResumeUrl());
            candidate.put("appliedAt", app.getCreatedAt());
            candidateList.add(candidate);

            String stage = app.getHiringStage() != null ? app.getHiringStage() : app.getStatus().name();
            switch (stage) {
                case "SHORTLISTED" -> shortlistedCount++;
                case "TECH_ROUND" -> techRoundCount++;
                case "OFFER_EXTENDED", "SELECTED" -> offerCount++;
                case "REJECTED" -> rejectedCount++;
            }
        }

        candidateList.sort((a, b) -> Double.compare(
                ((Number) b.getOrDefault("atsScore", 0.0)).doubleValue(),
                ((Number) a.getOrDefault("atsScore", 0.0)).doubleValue()));

        Map<String, Object> stats = new LinkedHashMap<>();
        stats.put("totalApplicants", applications.size());
        stats.put("shortlisted", shortlistedCount);
        stats.put("techRound", techRoundCount);
        stats.put("offerExtended", offerCount);
        stats.put("rejected", rejectedCount);

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("drive", drive);
        response.put("stats", stats);
        response.put("candidates", candidateList);
        return ResponseEntity.ok(response);
    }

    /**
     * External Recruiter updates candidate stage
     */
    @PutMapping("/recruiter/{token}/{id}/stage")
    public ResponseEntity<StudentPlacement> updateRecruiterStage(
            @PathVariable String token,
            @PathVariable Long id,
            @RequestBody Map<String, String> body) {
        PlacementDrive drive = placementDriveRepository.findByRecruiterToken(token)
                .orElseThrow(() -> new org.springframework.web.server.ResponseStatusException(
                        org.springframework.http.HttpStatus.NOT_FOUND, "Recruiter link not found"));

        StudentPlacement application = placementRepository.findById(id)
                .orElseThrow(() -> new org.springframework.web.server.ResponseStatusException(
                        org.springframework.http.HttpStatus.NOT_FOUND, "Application not found"));

        if (!drive.getId().equals(application.getDriveId())) {
            throw new org.springframework.web.server.ResponseStatusException(
                    org.springframework.http.HttpStatus.BAD_REQUEST, "Application does not belong to this drive");
        }

        String stage = body.get("stage");
        if (stage != null) {
            application.setHiringStage(stage);
            switch (stage.toUpperCase()) {
                case "SHORTLISTED" -> {
                    application.setStatus(StudentPlacement.Status.SHORTLISTED);
                    application.setIsPlaced(false);
                }
                case "TECH_ROUND" -> {
                    application.setStatus(StudentPlacement.Status.TECH_ROUND);
                    application.setIsPlaced(false);
                }
                case "OFFER_EXTENDED" -> {
                    application.setStatus(StudentPlacement.Status.OFFER_EXTENDED);
                    application.setIsPlaced(true);
                }
                case "SELECTED" -> {
                    application.setStatus(StudentPlacement.Status.SELECTED);
                    application.setIsPlaced(true);
                }
                case "REJECTED" -> {
                    application.setStatus(StudentPlacement.Status.REJECTED);
                    application.setIsPlaced(false);
                }
            }
        }
        return ResponseEntity.ok(placementRepository.save(application));
    }

    @PostMapping
    public ResponseEntity<StudentPlacement> createPlacement(@RequestBody StudentPlacement placement) {
        userContext.requireOrgAdmin();
        User user = userRepository.findById(placement.getUser().getId())
                .orElseThrow(() -> new RuntimeException("User not found"));
        placement.setUser(user);
        if (placement.getIsPlaced() == null) placement.setIsPlaced(true);
        if (placement.getStatus() == null) placement.setStatus(StudentPlacement.Status.SELECTED);
        return ResponseEntity.ok(placementRepository.save(placement));
    }

    @PutMapping("/{id}")
    public ResponseEntity<StudentPlacement> updatePlacement(@PathVariable Long id, @RequestBody StudentPlacement placement) {
        userContext.requireOrgAdmin();
        return placementRepository.findById(id)
                .map(existing -> {
                    existing.setCompanyName(placement.getCompanyName());
                    existing.setRole(placement.getRole());
                    existing.setPackageAmount(placement.getPackageAmount());
                    existing.setPlacedDate(placement.getPlacedDate());
                    existing.setDescription(placement.getDescription());
                    existing.setIsPlaced(placement.getIsPlaced());
                    if (placement.getStatus() != null) {
                        existing.setStatus(placement.getStatus());
                        existing.setIsPlaced(placement.getStatus() == StudentPlacement.Status.SELECTED);
                    }
                    return ResponseEntity.ok(placementRepository.save(existing));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    /**
     * Admin updates only the status of a student's placement application.
     */
    @PutMapping("/{id}/status")
    public ResponseEntity<StudentPlacement> updateStatus(@PathVariable Long id, @RequestBody Map<String, String> body) {
        userContext.requireOrgAdmin();
        return placementRepository.findById(id)
                .map(existing -> {
                    StudentPlacement.Status status = StudentPlacement.Status.valueOf(body.get("status"));
                    existing.setStatus(status);
                    existing.setIsPlaced(status == StudentPlacement.Status.SELECTED);
                    return ResponseEntity.ok(placementRepository.save(existing));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deletePlacement(@PathVariable Long id) {
        userContext.requireOrgAdmin();
        placementRepository.deleteById(id);
        return ResponseEntity.ok().build();
    }
}