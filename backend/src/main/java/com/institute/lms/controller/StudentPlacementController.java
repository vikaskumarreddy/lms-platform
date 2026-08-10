package com.institute.lms.controller;

import com.institute.lms.entity.StudentPlacement;
import com.institute.lms.entity.User;
import com.institute.lms.repository.StudentPlacementRepository;
import com.institute.lms.repository.UserRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/student-placements")
public class StudentPlacementController {

    private final StudentPlacementRepository placementRepository;
    private final UserRepository userRepository;

    public StudentPlacementController(StudentPlacementRepository placementRepository, UserRepository userRepository) {
        this.placementRepository = placementRepository;
        this.userRepository = userRepository;
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

    @PostMapping
    public ResponseEntity<StudentPlacement> createPlacement(@RequestBody StudentPlacement placement) {
        User user = userRepository.findById(placement.getUser().getId())
                .orElseThrow(() -> new RuntimeException("User not found"));
        placement.setUser(user);
        placement.setIsPlaced(true);
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