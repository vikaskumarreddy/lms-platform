package com.institute.lms.controller;

import com.institute.lms.entity.Answer;
import com.institute.lms.entity.Question;
import com.institute.lms.entity.User;
import com.institute.lms.repository.AnswerRepository;
import com.institute.lms.repository.QuestionRepository;
import com.institute.lms.repository.UserRepository;
import com.institute.lms.service.GeminiAiService;
import com.institute.lms.service.NotificationService;
import com.institute.lms.util.UserContext;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.*;

@RestController
@RequestMapping("/api/questions")
public class QuestionController {

    private final QuestionRepository questionRepository;
    private final AnswerRepository answerRepository;
    private final UserRepository userRepository;
    private final UserContext userContext;
    private final GeminiAiService geminiAiService;
    private final NotificationService notificationService;

    public QuestionController(QuestionRepository questionRepository,
                              AnswerRepository answerRepository,
                              UserRepository userRepository,
                              UserContext userContext,
                              GeminiAiService geminiAiService,
                              NotificationService notificationService) {
        this.questionRepository = questionRepository;
        this.answerRepository = answerRepository;
        this.userRepository = userRepository;
        this.userContext = userContext;
        this.geminiAiService = geminiAiService;
        this.notificationService = notificationService;
    }

    @GetMapping("/daily-status")
    public ResponseEntity<?> getDailyStatus() {
        User current = userContext.currentUser();
        if (current == null) {
            return ResponseEntity.ok(Map.of("limit", 10, "used", 0, "remaining", 10, "canAsk", true));
        }
        LocalDateTime startOfDay = LocalDate.now().atStartOfDay();
        long used = questionRepository.countByUserIdAndCreatedAtAfter(current.getId(), startOfDay);
        return ResponseEntity.ok(Map.of(
                "limit", 10,
                "used", used,
                "remaining", Math.max(0, 10 - used),
                "canAsk", used < 10
        ));
    }

    @GetMapping
    public List<Question> getAllQuestions() {
        // Faculty are scoped to questions visible to their own batch (plus shared "All Batches" ones).
        if (userContext.isFaculty()) {
            Long batchId = userContext.facultyBatchId();
            return batchId != null ? questionRepository.findVisibleToBatch(batchId) : questionRepository.findGeneralQuestions();
        }
        return questionRepository.findAll();
    }

    @GetMapping("/{id}")
    public ResponseEntity<Question> getQuestionById(@PathVariable Long id) {
        return questionRepository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/batch/{batchId}")
    public List<Question> getQuestionsByBatch(@PathVariable Long batchId) {
        // Includes both batch-specific questions and "All Batches" questions (batchId == null).
        return questionRepository.findVisibleToBatch(batchId);
    }

    @GetMapping("/user/{userId}")
    public List<Question> getQuestionsByUser(@PathVariable Long userId) {
        return questionRepository.findByUserId(userId);
    }

    @GetMapping("/category/{category}")
    public List<Question> getQuestionsByCategory(@PathVariable String category) {
        return questionRepository.findByCategoryIgnoreCase(category);
    }

    @GetMapping("/{id}/answers")
    public List<Answer> getAnswersByQuestion(@PathVariable Long id) {
        return answerRepository.findByQuestionId(id);
    }

    @PostMapping
    public ResponseEntity<?> createQuestion(@RequestBody Question question) {
        User current = userContext.currentUser();
        Long uid = question.getUserId() != null ? question.getUserId() : (current != null ? current.getId() : null);

        // Enforce daily limit: maximum 10 questions per day
        if (uid != null) {
            LocalDateTime startOfDay = LocalDate.now().atStartOfDay();
            long askedToday = questionRepository.countByUserIdAndCreatedAtAfter(uid, startOfDay);
            if (askedToday >= 10) {
                return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
                        .body(Map.of("message", "Daily limit of 10 doubt questions reached. Please wait until tomorrow or escalate an existing question to faculty mentors."));
            }
        }

        if (question.getUserId() == null && current != null) {
            question.setUserId(current.getId());
        }
        if (question.getAuthorName() == null && current != null) {
            question.setAuthorName(current.getName());
        }
        if (question.getBatchId() == null && current != null) {
            question.setBatchId(current.getBatchId());
        }

        if (question.getIsAnswered() == null) question.setIsAnswered(false);
        if (question.getAnswerCount() == null) question.setAnswerCount(0);
        if (question.getViewCount() == null) question.setViewCount(0);
        if (question.getVoteCount() == null) question.setVoteCount(0);
        if (question.getIsEscalated() == null) question.setIsEscalated(false);
        if (question.getIsAiAnswered() == null) question.setIsAiAnswered(false);

        Question saved = questionRepository.save(question);

        // Trigger AI Doubt Assistant
        try {
            Long orgId = current != null ? current.getOrganizationId() : null;
            String aiAnswerText = geminiAiService.answerDoubt(orgId, saved.getTitle(), saved.getContent(), saved.getCategory());
            if (aiAnswerText != null && !aiAnswerText.isBlank()) {
                Answer aiAnswer = new Answer();
                aiAnswer.setQuestion(saved);
                aiAnswer.setContent(aiAnswerText);
                aiAnswer.setAuthorName("🤖 AI Teaching Assistant (Gemini 1.5 Flash)");
                aiAnswer.setIsAiGenerated(true);
                aiAnswer.setIsAccepted(false);
                aiAnswer.setVoteCount(0);
                answerRepository.save(aiAnswer);

                saved.setIsAnswered(true);
                saved.setIsAiAnswered(true);
                saved.setAnswerCount(1);
                saved = questionRepository.save(saved);
            }
        } catch (Exception e) {
            System.err.println("AI doubt resolution failed: " + e.getMessage());
        }

        // Notify faculty and admins about the new student doubt
        try {
            notificationService.notifyFacultyAndAdmins(
                    "New Doubt: " + saved.getTitle(),
                    (saved.getAuthorName() != null ? saved.getAuthorName() : "Student") + " posted a question in " + saved.getCategory(),
                    "qa",
                    "/qa",
                    saved.getBatchId()
            );
        } catch (Exception ignored) {}

        return ResponseEntity.ok(saved);
    }

    @PostMapping("/{id}/escalate")
    public ResponseEntity<?> escalateQuestion(@PathVariable Long id) {
        return questionRepository.findById(id)
                .map(question -> {
                    question.setIsEscalated(true);
                    Question saved = questionRepository.save(question);

                    // High priority notification to assigned faculty
                    notificationService.notifyFacultyAndAdmins(
                            "⚠️ Doubt Escalated: " + question.getTitle(),
                            (question.getAuthorName() != null ? question.getAuthorName() : "Student") + " requested mentor intervention on: " + question.getTitle(),
                            "qa",
                            "/qa",
                            question.getBatchId()
                    );
                    return ResponseEntity.ok(saved);
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/{id}")
    public ResponseEntity<Question> updateQuestion(@PathVariable Long id, @RequestBody Question question) {
        return questionRepository.findById(id)
                .map(existing -> {
                    existing.setTitle(question.getTitle());
                    existing.setContent(question.getContent());
                    existing.setCategory(question.getCategory());
                    existing.setAuthorName(question.getAuthorName());
                    existing.setIsAnswered(question.getIsAnswered());
                    existing.setAnswerCount(question.getAnswerCount());
                    existing.setViewCount(question.getViewCount());
                    existing.setVoteCount(question.getVoteCount());
                    existing.setPlanId(question.getPlanId());
                    existing.setBatchId(question.getBatchId());
                    existing.setUserId(question.getUserId());
                    return ResponseEntity.ok(questionRepository.save(existing));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteQuestion(@PathVariable Long id) {
        questionRepository.deleteById(id);
                return ResponseEntity.ok().build();
    }

    @PostMapping("/{id}/answers")
    public ResponseEntity<Answer> createAnswer(@PathVariable Long id, @RequestBody Answer answer) {
        return questionRepository.findById(id)
                .map(question -> {
                    answer.setQuestion(question);
                    if (answer.getIsAccepted() == null) answer.setIsAccepted(false);
                    if (answer.getVoteCount() == null) answer.setVoteCount(0);
                    Answer saved = answerRepository.save(answer);

                    question.setAnswerCount((question.getAnswerCount() == null ? 0 : question.getAnswerCount()) + 1);
                    question.setIsAnswered(true);
                    questionRepository.save(question);

                    return ResponseEntity.ok(saved);
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/answers/{id}")
    public ResponseEntity<Answer> updateAnswer(@PathVariable Long id, @RequestBody Answer answer) {
        return answerRepository.findById(id)
                .map(existing -> {
                    existing.setContent(answer.getContent());
                    existing.setAuthorName(answer.getAuthorName());
                    existing.setIsAccepted(answer.getIsAccepted());
                    existing.setVoteCount(answer.getVoteCount());
                    return ResponseEntity.ok(answerRepository.save(existing));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/answers/{id}")
    public ResponseEntity<Void> deleteAnswer(@PathVariable Long id) {
        Answer answer = answerRepository.findById(id).orElse(null);
        if (answer != null) {
            Question question = answer.getQuestion();
            if (question != null && question.getAnswerCount() != null && question.getAnswerCount() > 0) {
                question.setAnswerCount(question.getAnswerCount() - 1);
                questionRepository.save(question);
            }
            answerRepository.deleteById(id);
        }
                return ResponseEntity.ok().build();
    }

    @PostMapping("/{id}/vote")
    public ResponseEntity<Question> voteQuestion(@PathVariable Long id, @RequestParam(defaultValue = "up") String direction) {
        return questionRepository.findById(id)
                .map(question -> {
                    Integer currentVotes = question.getVoteCount() == null ? 0 : question.getVoteCount();
                    question.setVoteCount("up".equals(direction) ? currentVotes + 1 : Math.max(0, currentVotes - 1));
                    return ResponseEntity.ok(questionRepository.save(question));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping("/answers/{id}/vote")
    public ResponseEntity<Answer> voteAnswer(@PathVariable Long id, @RequestParam(defaultValue = "up") String direction) {
        return answerRepository.findById(id)
                .map(answer -> {
                    Integer currentVotes = answer.getVoteCount() == null ? 0 : answer.getVoteCount();
                    answer.setVoteCount("up".equals(direction) ? currentVotes + 1 : Math.max(0, currentVotes - 1));
                    return ResponseEntity.ok(answerRepository.save(answer));
                })
                .orElse(ResponseEntity.notFound().build());
    }
}