package com.institute.lms.controller;

import com.institute.lms.entity.PlacementDrive;
import com.institute.lms.repository.PlacementDriveRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/placement-drives")
public class PlacementDriveController {

    private final PlacementDriveRepository placementDriveRepository;

    public PlacementDriveController(PlacementDriveRepository placementDriveRepository) {
        this.placementDriveRepository = placementDriveRepository;
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
        if (drive.getIsActive() == null) drive.setIsActive(true);
        if (drive.getDriveType() == null || drive.getDriveType().isBlank()) drive.setDriveType("EXTERNAL");
        return placementDriveRepository.save(drive);
    }

    @PutMapping("/{id}")
    public ResponseEntity<PlacementDrive> updateDrive(@PathVariable Long id, @RequestBody PlacementDrive drive) {
        return placementDriveRepository.findById(id)
                .map(existing -> {
                    existing.setCompanyName(drive.getCompanyName());
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
                    existing.setMinExamAvgPercent(drive.getMinExamAvgPercent());
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
        placementDriveRepository.deleteById(id);
        return ResponseEntity.ok().build();
    }
}