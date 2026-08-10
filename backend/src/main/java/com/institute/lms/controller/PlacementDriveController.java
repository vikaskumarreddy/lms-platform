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