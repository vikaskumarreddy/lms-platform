package com.institute.lms.controller;

import com.institute.lms.dto.user.StudentResponse;
import com.institute.lms.entity.Batch;
import com.institute.lms.entity.User;
import com.institute.lms.repository.BatchRepository;
import com.institute.lms.repository.UserRepository;
import com.institute.lms.service.UserService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/batches")
public class BatchController {

    private final BatchRepository batchRepository;
    private final UserRepository userRepository;
    private final UserService userService;

    public BatchController(BatchRepository batchRepository, UserRepository userRepository, UserService userService) {
        this.batchRepository = batchRepository;
        this.userRepository = userRepository;
        this.userService = userService;
    }

    @GetMapping("/{id}/students")
    public List<StudentResponse> getStudentsInBatch(@PathVariable Long id) {
        return userRepository.findByRoleAndBatchId(User.UserRole.STUDENT, id)
                .stream()
                .map(userService::toResponse)
                .collect(Collectors.toList());
    }

    @GetMapping
    public List<Batch> getAllBatches() {
        return batchRepository.findAll();
    }

    @GetMapping("/active")
    public List<Batch> getActiveBatches() {
        return batchRepository.findByIsActiveTrue();
    }

    @GetMapping("/{id}")
    public ResponseEntity<Batch> getBatchById(@PathVariable Long id) {
        return batchRepository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public Batch createBatch(@RequestBody Batch batch) {
        if (batch.getIsActive() == null) batch.setIsActive(true);
        return batchRepository.save(batch);
    }

    @PutMapping("/{id}")
    public ResponseEntity<Batch> updateBatch(@PathVariable Long id, @RequestBody Batch batch) {
        return batchRepository.findById(id)
                .map(existing -> {
                    existing.setName(batch.getName());
                    existing.setDescription(batch.getDescription());
                    existing.setPlanId(batch.getPlanId());
                    existing.setStartDate(batch.getStartDate());
                    existing.setEndDate(batch.getEndDate());
                    existing.setIsActive(batch.getIsActive());
                    existing.setMaxStudents(batch.getMaxStudents());
                    existing.setSchedule(batch.getSchedule());
                    return ResponseEntity.ok(batchRepository.save(existing));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteBatch(@PathVariable Long id) {
        batchRepository.deleteById(id);
        return ResponseEntity.ok().build();
    }
}