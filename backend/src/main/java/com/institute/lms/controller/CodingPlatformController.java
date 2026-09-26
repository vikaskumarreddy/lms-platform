package com.institute.lms.controller;

import com.institute.lms.entity.AssessmentQuestion;
import com.institute.lms.entity.CodingTestCase;
import com.institute.lms.repository.CodingTestCaseRepository;
import com.institute.lms.service.CodeExecutionService;
import com.institute.lms.service.CodingPlatformService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/coding")
public class CodingPlatformController {

    private final CodingPlatformService codingService;
    private final CodingTestCaseRepository testCaseRepository;

    public CodingPlatformController(CodingPlatformService codingService,
                                    CodingTestCaseRepository testCaseRepository) {
        this.codingService = codingService;
        this.testCaseRepository = testCaseRepository;
    }

    /**
     * Public or authenticated endpoint for fetching coding problem description,
     * criteria, constraints, sample test cases, starter codes, and institute branding.
     */
    @GetMapping("/questions/{id}")
    public ResponseEntity<CodingPlatformService.QuestionDetailDTO> getQuestion(
            @PathVariable Long id,
            @RequestParam(required = false) Long orgId) {
        return ResponseEntity.ok(codingService.getQuestionDetails(id, orgId));
    }

    /**
     * Executes student code in real-time against sample test cases or custom input.
     */
    @PostMapping("/run")
    public ResponseEntity<Map<String, Object>> runCode(
            @RequestBody CodingPlatformService.RunRequest request) {
        return ResponseEntity.ok(codingService.runCode(request));
    }

    /**
     * Submits code for auto-grading across all test cases (both visible and hidden).
     * Automatically scores the attempt and syncs with the user's assignment or exam!
     */
    @PostMapping("/submit")
    public ResponseEntity<Map<String, Object>> submitSolution(
            @RequestBody CodingPlatformService.SubmitRequest request) {
        return ResponseEntity.ok(codingService.submitSolution(request));
    }

    /**
     * Admin Question Bank: lists all coding challenges.
     */
    @GetMapping("/bank")
    public ResponseEntity<List<Map<String, Object>>> getBank() {
        return ResponseEntity.ok(codingService.getCodingBank());
    }

    /**
     * Admin: Creates or updates a coding question with test cases.
     */
    @PostMapping("/bank")
    public ResponseEntity<Map<String, Object>> saveBankQuestion(
            @RequestBody Map<String, Object> payload) {
        Long questionId = payload.get("id") != null ? ((Number) payload.get("id")).longValue() : null;
        AssessmentQuestion saved = codingService.saveCodingQuestion(questionId, payload);
        return ResponseEntity.ok(Map.of("id", saved.getId(), "message", "Coding question saved successfully"));
    }

    /**
     * Admin: Deletes a coding challenge from bank.
     */
    @DeleteMapping("/bank/{id}")
    public ResponseEntity<Map<String, Object>> deleteBankQuestion(@PathVariable Long id) {
        codingService.deleteCodingQuestion(id);
        return ResponseEntity.ok(Map.of("message", "Coding question deleted successfully"));
    }

    /**
     * Admin: Get all test cases (including hidden ones) for a question.
     */
    @GetMapping("/test-cases/{questionId}")
    public ResponseEntity<List<CodingTestCase>> getTestCases(@PathVariable Long questionId) {
        return ResponseEntity.ok(testCaseRepository.findByQuestionIdOrderByDisplayOrderAscIdAsc(questionId));
    }

    /**
     * Admin: Set or replace test cases for a question.
     */
    @PostMapping("/test-cases/{questionId}")
    public ResponseEntity<Map<String, Object>> saveTestCases(
            @PathVariable Long questionId,
            @RequestBody List<Map<String, Object>> testCases) {
        Map<String, Object> payload = Map.of("testCases", testCases);
        codingService.saveCodingQuestion(questionId, payload);
        return ResponseEntity.ok(Map.of("message", "Test cases saved successfully"));
    }
}
