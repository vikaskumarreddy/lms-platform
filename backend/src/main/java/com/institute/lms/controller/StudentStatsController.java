package com.institute.lms.controller;

import com.institute.lms.dto.StudentStatsDTO;
import com.institute.lms.dto.PlacementMetricsDTO;
import com.institute.lms.service.StudentStatsService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/student-stats")
public class StudentStatsController {

    private final StudentStatsService studentStatsService;

    public StudentStatsController(StudentStatsService studentStatsService) {
        this.studentStatsService = studentStatsService;
    }

    @GetMapping("/{studentId}")
    public ResponseEntity<StudentStatsDTO> getStudentStats(@PathVariable Long studentId) {
        try {
            StudentStatsDTO stats = studentStatsService.getStudentStats(studentId);
            return ResponseEntity.ok(stats);
        } catch (RuntimeException e) {
            return ResponseEntity.notFound().build();
        }
    }

    /**
     * Placement-eligibility metrics (percentages) for a student. Consumed by the
     * mobile app to decide whether a student meets a drive's criteria.
     */
    @GetMapping("/{studentId}/placement-metrics")
    public ResponseEntity<PlacementMetricsDTO> getPlacementMetrics(@PathVariable Long studentId) {
        try {
            PlacementMetricsDTO metrics = studentStatsService.getPlacementMetrics(studentId);
            return ResponseEntity.ok(metrics);
        } catch (RuntimeException e) {
            return ResponseEntity.notFound().build();
        }
    }
}