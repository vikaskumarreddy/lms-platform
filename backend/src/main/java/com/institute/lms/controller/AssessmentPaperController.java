package com.institute.lms.controller;

import com.institute.lms.entity.AssessmentQuestion;
import com.institute.lms.entity.AssessmentType;
import com.institute.lms.service.AssessmentPaperService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * In-app question papers for assignments and exams.
 *
 * <p>{@code type} is the literal "assignments" or "exams" so the URLs read naturally
 * next to the existing /api/assignments and /api/exams endpoints; both singular and
 * plural spellings are accepted.</p>
 *
 * <ul>
 *   <li>Admin/mentor authoring: GET/POST/PUT/DELETE {@code /questions}, PUT {@code /questions/reorder}</li>
 *   <li>Student delivery: GET {@code /paper} (answer key stripped), POST {@code /attempt}, GET {@code /review}</li>
 *   <li>Mentor results: GET {@code /responses}, GET {@code /responses/{userId}}</li>
 * </ul>
 */
@RestController
@RequestMapping("/api/assessments/{type}/{assessmentId}")
public class AssessmentPaperController {

    private final AssessmentPaperService paperService;

    public AssessmentPaperController(AssessmentPaperService paperService) {
        this.paperService = paperService;
    }

    // ------------------------------------------------------------------ authoring

    /** Full question list including the answer key. Admin portal only. */
    @GetMapping("/questions")
    public ResponseEntity<Map<String, Object>> listQuestions(@PathVariable String type,
                                                             @PathVariable Long assessmentId) {
        AssessmentType assessmentType = AssessmentType.from(type);
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("questions", paperService.answerKey(assessmentType, assessmentId));
        body.put("questionCount", paperService.questionCount(assessmentType, assessmentId));
        body.put("totalMarks", paperService.paperMarks(assessmentType, assessmentId));
        return ResponseEntity.ok(body);
    }

    @PostMapping("/questions")
    public ResponseEntity<?> createQuestion(@PathVariable String type,
                                            @PathVariable Long assessmentId,
                                            @RequestBody AssessmentPaperService.QuestionForm form) {
        String error = validate(form);
        if (error != null) return ResponseEntity.badRequest().body(Map.of("message", error));
        AssessmentQuestion saved = paperService.createQuestion(AssessmentType.from(type), assessmentId, form);
        return ResponseEntity.ok(Map.of("id", saved.getId()));
    }

    @PutMapping("/questions/{questionId}")
    public ResponseEntity<?> updateQuestion(@PathVariable String type,
                                            @PathVariable Long assessmentId,
                                            @PathVariable Long questionId,
                                            @RequestBody AssessmentPaperService.QuestionForm form) {
        String error = validate(form);
        if (error != null) return ResponseEntity.badRequest().body(Map.of("message", error));
        AssessmentQuestion saved = paperService.updateQuestion(questionId, form);
        return ResponseEntity.ok(Map.of("id", saved.getId()));
    }

    @DeleteMapping("/questions/{questionId}")
    public ResponseEntity<Void> deleteQuestion(@PathVariable String type,
                                               @PathVariable Long assessmentId,
                                               @PathVariable Long questionId) {
        paperService.deleteQuestion(questionId);
        return ResponseEntity.ok().build();
    }

    /** Body: {"questionIds": [3, 1, 2]} - the new top-to-bottom order. */
    @PutMapping("/questions-order")
    public ResponseEntity<Void> reorder(@PathVariable String type,
                                        @PathVariable Long assessmentId,
                                        @RequestBody Map<String, Object> body) {
        List<Long> ids = new ArrayList<>();
        Object raw = body.get("questionIds");
        if (raw instanceof List<?> list) {
            for (Object item : list) {
                if (item instanceof Number number) ids.add(number.longValue());
            }
        }
        paperService.reorder(AssessmentType.from(type), assessmentId, ids);
        return ResponseEntity.ok().build();
    }

    /**
     * A question is only usable if it has at least two options and at least one of them
     * is flagged correct - otherwise auto-grading would mark every student wrong.
     */
    private String validate(AssessmentPaperService.QuestionForm form) {
        if (form == null || form.questionText == null || form.questionText.isBlank()) {
            return "Question text is required";
        }
        if (form.questionType == AssessmentQuestion.QuestionType.FILL_IN_BLANK) {
            if (form.answerText == null || form.answerText.isBlank()) {
                return "Enter the correct answer";
            }
            return null;
        }
        if (form.questionType == AssessmentQuestion.QuestionType.CODING) {
            // No sandbox/test-case runner - only the prompt itself is required.
            return null;
        }
        long usable = form.options == null ? 0 : form.options.stream()
                .filter(o -> o.optionText != null && !o.optionText.isBlank()).count();
        if (usable < 2) return "Add at least two options";
        long correct = form.options.stream()
                .filter(o -> o.optionText != null && !o.optionText.isBlank())
                .filter(o -> Boolean.TRUE.equals(o.isCorrect)).count();
        if (correct < 1) return "Tick at least one correct answer";
        if (form.questionType == AssessmentQuestion.QuestionType.SINGLE_CHOICE && correct > 1) {
            return "A single-choice question can only have one correct answer";
        }
        return null;
    }

    // ------------------------------------------------------------------ student delivery

    /** The paper as the student sees it - no isCorrect, no explanations. */
    @GetMapping("/paper")
    public ResponseEntity<Map<String, Object>> paper(@PathVariable String type,
                                                     @PathVariable Long assessmentId,
                                                     @RequestParam(required = false) Long userId) {
        AssessmentType assessmentType = AssessmentType.from(type);
        Map<String, Object> body = new LinkedHashMap<>();
        List<Map<String, Object>> questions = paperService.studentPaper(assessmentType, assessmentId);
        body.put("questions", questions);
        body.put("questionCount", questions.size());
        body.put("totalMarks", paperService.paperMarks(assessmentType, assessmentId));
        body.put("alreadySubmitted",
                userId != null && paperService.hasSubmitted(assessmentType, assessmentId, userId));
        return ResponseEntity.ok(body);
    }

    /**
     * Submits and auto-grades an attempt in one call. Body:
     * {"userId": 4, "timeTakenSeconds": 540, "answers": [{"questionId": 1, "selectedOptionIds": [2]}]}
     */
    @PostMapping("/attempt")
    public ResponseEntity<?> attempt(@PathVariable String type,
                                     @PathVariable Long assessmentId,
                                     @RequestBody AttemptRequest request) {
        if (request == null || request.userId == null) {
            return ResponseEntity.badRequest().body(Map.of("message", "userId is required"));
        }
        try {
            return ResponseEntity.ok(paperService.submitAttempt(AssessmentType.from(type), assessmentId,
                    request.userId, request.answers, request.timeTakenSeconds));
        } catch (IllegalArgumentException | IllegalStateException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    /** Post-submission review: the student answers alongside the key and explanations. */
    @GetMapping("/review")
    public ResponseEntity<Map<String, Object>> review(@PathVariable String type,
                                                      @PathVariable Long assessmentId,
                                                      @RequestParam Long userId) {
        return ResponseEntity.ok(paperService.review(AssessmentType.from(type), assessmentId, userId));
    }

    // ------------------------------------------------------------------ mentor results

    /** Every student attempt with the exact options each one ticked, plus per-question stats. */
    @GetMapping("/responses")
    public ResponseEntity<Map<String, Object>> responses(@PathVariable String type,
                                                         @PathVariable Long assessmentId) {
        return ResponseEntity.ok(paperService.mentorResponses(AssessmentType.from(type), assessmentId));
    }

    /** One student attempt in full - same shape as the student review screen. */
    @GetMapping("/responses/{userId}")
    public ResponseEntity<Map<String, Object>> studentResponses(@PathVariable String type,
                                                                @PathVariable Long assessmentId,
                                                                @PathVariable Long userId) {
        return ResponseEntity.ok(paperService.review(AssessmentType.from(type), assessmentId, userId));
    }

    /** Inbound attempt payload. */
    public static class AttemptRequest {
        public Long userId;
        public Integer timeTakenSeconds;
        public List<AssessmentPaperService.AnswerForm> answers;
    }
}
