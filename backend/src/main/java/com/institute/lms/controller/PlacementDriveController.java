package com.institute.lms.controller;

import com.institute.lms.entity.PlacementDrive;
import com.institute.lms.repository.PlacementDriveRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import com.institute.lms.service.NotificationService;
import com.institute.lms.util.UserContext;

@RestController
@RequestMapping("/api/placement-drives")
public class PlacementDriveController {

    private final PlacementDriveRepository placementDriveRepository;
    private final NotificationService notificationService;
    private final UserContext userContext;

    public PlacementDriveController(PlacementDriveRepository placementDriveRepository,
                                    NotificationService notificationService,
                                    UserContext userContext) {
        this.placementDriveRepository = placementDriveRepository;
        this.notificationService = notificationService;
        this.userContext = userContext;
    }

    @GetMapping
    public List<PlacementDrive> getAllDrives() {
        return placementDriveRepository.findAll();
    }

    @GetMapping("/active")
    public List<PlacementDrive> getActiveDrives() {
        return placementDriveRepository.findByIsActiveTrue();
    }

    @PostMapping
    public PlacementDrive createDrive(@RequestBody PlacementDrive drive) {
        userContext.requireOrgAdmin();
        if (drive.getIsActive() == null) drive.setIsActive(true);
        if (drive.getDriveType() == null || drive.getDriveType().isBlank()) drive.setDriveType("EXTERNAL");
        if (drive.getRecruiterToken() == null || drive.getRecruiterToken().isBlank()) {
            drive.setRecruiterToken(java.util.UUID.randomUUID().toString());
        }
        PlacementDrive saved = placementDriveRepository.save(drive);

        // Drives are gated by subscription plan; a null planId means open to all.
        String role = saved.getRole() != null ? saved.getRole() : "New opening";
        notificationService.safeNotify(
                notificationService.audienceForPlan(saved.getPlanId()),
                saved.getCompanyName() + " is hiring",
                role + (saved.getDeadline() != null
                        ? " - apply by " + saved.getDeadline().toLocalDate() + "."
                        : " - open now."),
                "placement", "/placement-drives", "SUBSCRIPTION", saved.getId());

        return saved;
    }

    @PutMapping("/{id}")
    public ResponseEntity<PlacementDrive> updateDrive(@PathVariable Long id, @RequestBody PlacementDrive drive) {
        userContext.requireOrgAdmin();
        return placementDriveRepository.findById(id)
                .map(existing -> {
                    existing.setCompanyName(drive.getCompanyName());
                    existing.setCompanyLogoUrl(drive.getCompanyLogoUrl());
                    existing.setRole(drive.getRole());
                    existing.setPackageAmount(drive.getPackageAmount());
                    existing.setLocation(drive.getLocation());
                    existing.setEligibility(drive.getEligibility());
                    existing.setDescription(drive.getDescription());
                    existing.setApplyLink(drive.getApplyLink());
                    existing.setDeadline(drive.getDeadline());
                    existing.setIsActive(drive.getIsActive());
                    existing.setPlanId(drive.getPlanId());
                    if (drive.getDriveType() != null && !drive.getDriveType().isBlank()) {
                        existing.setDriveType(drive.getDriveType());
                    }
                    existing.setMinAttendancePercent(drive.getMinAttendancePercent());
                    existing.setMinCourseCompletionPercent(drive.getMinCourseCompletionPercent());
                    existing.setMinAssignmentAvgPercent(drive.getMinAssignmentAvgPercent());
                    if (drive.getRecruiterToken() != null && !drive.getRecruiterToken().isBlank()) {
                        existing.setRecruiterToken(drive.getRecruiterToken());
                    } else if (existing.getRecruiterToken() == null || existing.getRecruiterToken().isBlank()) {
                        existing.setRecruiterToken(java.util.UUID.randomUUID().toString());
                    }
                    return ResponseEntity.ok(placementDriveRepository.save(existing));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    /**
     * Updates only the eligibility criteria thresholds for a drive, leaving all
     * other fields untouched. Used by the admin UI's dedicated Criteria modal.
     */
    @PutMapping("/{id}/criteria")
    public ResponseEntity<PlacementDrive> updateCriteria(@PathVariable Long id, @RequestBody PlacementDrive criteria) {
        userContext.requireOrgAdmin();
        return placementDriveRepository.findById(id)
                .map(existing -> {
                    existing.setMinAttendancePercent(criteria.getMinAttendancePercent());
                    existing.setMinCourseCompletionPercent(criteria.getMinCourseCompletionPercent());
                    existing.setMinAssignmentAvgPercent(criteria.getMinAssignmentAvgPercent());
                    existing.setMinExamAvgPercent(criteria.getMinExamAvgPercent());
                    return ResponseEntity.ok(placementDriveRepository.save(existing));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteDrive(@PathVariable Long id) {
        userContext.requireOrgAdmin();
        placementDriveRepository.deleteById(id);
        return ResponseEntity.ok().build();
    }
}