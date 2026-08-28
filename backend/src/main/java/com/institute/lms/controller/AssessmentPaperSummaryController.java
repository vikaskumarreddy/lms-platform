package com.institute.lms.controller;

import com.institute.lms.entity.AssessmentType;
import com.institute.lms.repository.AssessmentQuestionRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Paper-level summaries that are not scoped to a single assessment.
 * Kept separate from {@link AssessmentPaperController} only because that one is
 * mapped under /{type}/{assessmentId}.
 */
@RestController
@RequestMapping("/api/assessments")
public class AssessmentPaperSummaryController {

    private final AssessmentQuestionRepository questionRepository;

    public AssessmentPaperSummaryController(AssessmentQuestionRepository questionRepository) {
        this.questionRepository = questionRepository;
    }

    /**
     * {@code {"12": 8, "15": 20}} - question count keyed by assessment id, so the admin
     * assignment/exam tables can badge every row from a single request.
     */
    @GetMapping("/{type}/question-counts")
    public ResponseEntity<Map<String, Long>> questionCounts(@PathVariable String type) {
        List<Object[]> rows = questionRepository.countsByType(AssessmentType.from(type));
        Map<String, Long> counts = new LinkedHashMap<>();
        for (Object[] row : rows) {
            counts.put(String.valueOf(row[0]), ((Number) row[1]).longValue());
        }
        return ResponseEntity.ok(counts);
    }
}
