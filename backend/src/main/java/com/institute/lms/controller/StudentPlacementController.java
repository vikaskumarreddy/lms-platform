package com.institute.lms.controller;

import com.institute.lms.entity.PlacementDrive;
import com.institute.lms.entity.StudentPlacement;
import com.institute.lms.entity.User;
import com.institute.lms.repository.PlacementDriveRepository;
import com.institute.lms.repository.StudentPlacementRepository;
import com.institute.lms.repository.UserRepository;
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
    private final com.institute.lms.service.subscription.ActivityMeterService activityMeter;

    public StudentPlacementController(StudentPlacementRepository placementRepository, UserRepository userRepository,
                                       PlacementDriveRepository placementDriveRepository,
                                       com.institute.lms.service.subscription.ActivityMeterService activityMeter) {
        this.placementRepository = placementRepository;
        this.userRepository = userRepository;
        this.placementDriveRepository = placementDriveRepository;
        this.activityMeter = activityMeter;
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
                case "SELECTED" -> selectedCount++;
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
     * Student applies to a placement drive, creating/updating their
     * StudentPlacement application record with status=APPLIED.
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

        StudentPlacement application = placementRepository.findByUserIdAndDriveId(userId, driveId)
                .orElseGet(StudentPlacement::new);
        application.setUser(user);
        application.setDriveId(driveId);
        application.setCompanyName(drive.getCompanyName());
        application.setRole(drive.getRole());
        application.setPackageAmount(drive.getPackageAmount() != null ? drive.getPackageAmount().doubleValue() : null);
        application.setStatus(StudentPlacement.Status.APPLIED);
        application.setIsPlaced(false);
        StudentPlacement saved = placementRepository.save(application);

        // Applying to a placement drive counts as activity for the billing month.
        if (user.getRole() == User.UserRole.STUDENT) {
            activityMeter.record(user.getOrganizationId(), user.getId(),
                    com.institute.lms.subscription.ActivityType.PLACEMENT_APPLICATION);
        }
        return ResponseEntity.ok(saved);
    }

    @PostMapping
    public ResponseEntity<StudentPlacement> createPlacement(@RequestBody StudentPlacement placement) {
        User user = userRepository.findById(placement.getUser().getId())
                .orElseThrow(() -> new RuntimeException("User not found"));
        placement.setUser(user);
        if (placement.getIsPlaced() == null) placement.setIsPlaced(true);
        if (placement.getStatus() == null) placement.setStatus(StudentPlacement.Status.SELECTED);
        return ResponseEntity.ok(placementRepository.save(placement));
    }

    @PutMapping("/{id}")
    public ResponseEntity<StudentPlacement> updatePlacement(@PathVariable Long id, @RequestBody StudentPlacement placement) {
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
        placementRepository.deleteById(id);
        return ResponseEntity.ok().build();
    }
}