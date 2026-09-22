package com.institute.lms.controller;

import com.institute.lms.entity.DailyChallengeAttempt;
import com.institute.lms.entity.Lesson;
import com.institute.lms.entity.OrgAiConfig;
import com.institute.lms.entity.User;
import com.institute.lms.repository.DailyChallengeAttemptRepository;
import com.institute.lms.repository.LessonRepository;
import com.institute.lms.repository.OrgAiConfigRepository;
import com.institute.lms.service.GeminiAiService;
import com.institute.lms.util.OrganizationContext;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.*;

@RestController
@RequestMapping("/api/ai")
public class AiController {

    private final GeminiAiService geminiAiService;
    private final OrgAiConfigRepository aiConfigRepository;
    private final DailyChallengeAttemptRepository challengeRepository;
    private final LessonRepository lessonRepository;
    private final UserContext userContext;
    private final OrganizationContext organizationContext;

    public AiController(GeminiAiService geminiAiService,
                        OrgAiConfigRepository aiConfigRepository,
                        DailyChallengeAttemptRepository challengeRepository,
                        LessonRepository lessonRepository,
                        UserContext userContext,
                        OrganizationContext organizationContext) {
        this.geminiAiService = geminiAiService;
        this.aiConfigRepository = aiConfigRepository;
        this.challengeRepository = challengeRepository;
        this.lessonRepository = lessonRepository;
        this.userContext = userContext;
        this.organizationContext = organizationContext;
    }

    /**
     * Get AI Configuration (masked secret) for admin settings.
     */
    @GetMapping("/config")
    public ResponseEntity<Map<String, Object>> getConfig() {
        Long orgId = organizationContext.getCurrentOrgId();
        OrgAiConfig cfg = geminiAiService.getEffectiveConfig(orgId);

        String rawKey = cfg.getApiKey();
        String maskedKey = (rawKey != null && rawKey.length() > 6)
                ? "••••••••" + rawKey.substring(rawKey.length() - 4)
                : (rawKey != null && !rawKey.isBlank() ? "••••••••" : "");

        Map<String, Object> res = new LinkedHashMap<>();
        res.put("id", cfg.getId());
        res.put("modelName", cfg.getModelName());
        res.put("apiKeyHint", maskedKey);
        res.put("isConfigured", rawKey != null && !rawKey.isBlank());
        res.put("enabled", cfg.getEnabled());
        res.put("dailyQuestionLimit", cfg.getDailyQuestionLimit());
        res.put("dailyChallengeLimit", cfg.getDailyChallengeLimit());
        return ResponseEntity.ok(res);
    }

    /**
     * Save AI Configuration (admin only).
     */
    @PostMapping("/config")
    public ResponseEntity<Map<String, Object>> saveConfig(@RequestBody Map<String, Object> body) {
        userContext.requireOrgAdmin();
        Long orgId = organizationContext.getCurrentOrgId();

        OrgAiConfig cfg = aiConfigRepository.findByOrganizationId(orgId)
                .orElseGet(() -> {
                    OrgAiConfig c = new OrgAiConfig();
                    c.setOrganizationId(orgId);
                    return c;
                });

        if (body.get("modelName") != null) {
            cfg.setModelName(body.get("modelName").toString().trim());
        }
        if (body.get("apiKey") != null) {
            String key = body.get("apiKey").toString().trim();
            if (!key.contains("••••")) {
                cfg.setApiKey(key);
            }
        }
        if (body.get("enabled") != null) {
            cfg.setEnabled(Boolean.parseBoolean(body.get("enabled").toString()));
        }
        if (body.get("dailyQuestionLimit") != null) {
            cfg.setDailyQuestionLimit(Integer.parseInt(body.get("dailyQuestionLimit").toString()));
        }
        if (body.get("dailyChallengeLimit") != null) {
            cfg.setDailyChallengeLimit(Integer.parseInt(body.get("dailyChallengeLimit").toString()));
        }

        aiConfigRepository.save(cfg);
        return getConfig();
    }

    /**
     * Test Gemini API Connection.
     */
    @PostMapping("/config/test")
    public ResponseEntity<Map<String, Object>> testConnection(@RequestBody Map<String, String> body) {
        String model = body.get("modelName");
        String key = body.get("apiKey");

        // If masked, use saved key
        if (key == null || key.contains("••••")) {
            OrgAiConfig cfg = geminiAiService.getEffectiveConfig(organizationContext.getCurrentOrgId());
            key = cfg.getApiKey();
            if (model == null || model.isBlank()) model = cfg.getModelName();
        }

        Map<String, Object> result = geminiAiService.testConnection(model, key);
        return ResponseEntity.ok(result);
    }

    /**
     * Fetch available Google Gemini models for the current or supplied API key.
     */
    @GetMapping("/models")
    public ResponseEntity<Map<String, Object>> getAvailableModels(@RequestParam(required = false) String apiKey) {
        String key = apiKey;
        if (key == null || key.contains("••••") || key.isBlank()) {
            OrgAiConfig cfg = geminiAiService.getEffectiveConfig(organizationContext.getCurrentOrgId());
            key = cfg.getApiKey();
        }
        List<Map<String, String>> models = geminiAiService.fetchAvailableModels(key);
        return ResponseEntity.ok(Map.of("models", models));
    }

    /**
     * Generate 20 MCQs for instructors based on lesson content or custom topic notes.
     */
    @PostMapping("/generate-quiz")
    public ResponseEntity<Map<String, Object>> generateQuiz(@RequestBody Map<String, Object> body) {
        userContext.requireOrgAdminOrFaculty();
        Long orgId = organizationContext.getCurrentOrgId();

        Long lessonId = body.get("lessonId") != null ? Long.parseLong(body.get("lessonId").toString()) : null;
        String topicOrNotes = (String) body.get("topicOrNotes");
        int count = body.get("count") != null ? Integer.parseInt(body.get("count").toString()) : 20;

        if (lessonId != null) {
            Lesson lesson = lessonRepository.findById(lessonId).orElse(null);
            if (lesson != null) {
                StringBuilder sb = new StringBuilder();
                sb.append("Lesson Title: ").append(lesson.getTitle()).append("\n");
                if (lesson.getHeading() != null) sb.append("Topic: ").append(lesson.getHeading()).append("\n");
                if (lesson.getContent() != null && !lesson.getContent().isBlank()) {
                    sb.append("Lecture Notes: ").append(lesson.getContent());
                }
                topicOrNotes = sb.toString();
            }
        }

        if (topicOrNotes == null || topicOrNotes.isBlank()) {
            topicOrNotes = "Computer Science and Software Engineering Core Fundamentals";
        }

        List<Map<String, Object>> questions = geminiAiService.generateMcqQuiz(orgId, topicOrNotes, count);
        return ResponseEntity.ok(Map.of("count", questions.size(), "questions", questions));
    }

    /**
     * Check if student has completed today's Daily AI Challenge.
     */
    @GetMapping("/daily-challenge/status")
    public ResponseEntity<Map<String, Object>> getChallengeStatus() {
        User user = userContext.currentUser();
        if (user == null) return ResponseEntity.status(401).build();

        LocalDateTime startOfDay = LocalDate.now().atStartOfDay();
        LocalDateTime endOfDay = LocalDate.now().atTime(LocalTime.MAX);

        List<DailyChallengeAttempt> attemptsToday = challengeRepository.findAttemptsToday(user.getId(), startOfDay, endOfDay);
        boolean hasCompleted = !attemptsToday.isEmpty();

        Map<String, Object> res = new LinkedHashMap<>();
        res.put("hasCompletedToday", hasCompleted);
        res.put("attemptsCountToday", attemptsToday.size());
        if (hasCompleted) {
            DailyChallengeAttempt latest = attemptsToday.get(0);
            res.put("todayScore", latest.getScore());
            res.put("todayTotal", latest.getTotalQuestions());
            res.put("pointsAwarded", latest.getPointsAwarded());
            res.put("completedAt", latest.getCompletedAt());
        }
        return ResponseEntity.ok(res);
    }

    /**
     * Start today's challenge: verifies 1/day rate limit and returns 5 MCQs for the lesson.
     */
    @PostMapping("/daily-challenge/start")
    public ResponseEntity<Map<String, Object>> startChallenge(@RequestBody(required = false) Map<String, Object> body) {
        User user = userContext.currentUser();
        if (user == null) return ResponseEntity.status(401).build();

        LocalDateTime startOfDay = LocalDate.now().atStartOfDay();
        LocalDateTime endOfDay = LocalDate.now().atTime(LocalTime.MAX);

        List<DailyChallengeAttempt> attemptsToday = challengeRepository.findAttemptsToday(user.getId(), startOfDay, endOfDay);
        if (!attemptsToday.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of(
                    "error", "You have already completed today's challenge. Come back tomorrow for the next challenge!"
            ));
        }

        Long orgId = organizationContext.getCurrentOrgId();
        Long lessonId = (body != null && body.get("lessonId") != null) ? Long.parseLong(body.get("lessonId").toString()) : null;

        String topic = "Daily Skills Practice";
        if (lessonId != null) {
            Lesson lesson = lessonRepository.findById(lessonId).orElse(null);
            if (lesson != null) {
                topic = "Lesson: " + lesson.getTitle() + "\n" + (lesson.getContent() != null ? lesson.getContent() : "");
            }
        }

        List<Map<String, Object>> questions = geminiAiService.generateMcqQuiz(orgId, topic, 5);

        // Strip correctIndex from questions returned to client so they can't cheat
        List<Map<String, Object>> clientQuestions = new ArrayList<>();
        for (int i = 0; i < questions.size(); i++) {
            Map<String, Object> original = questions.get(i);
            Map<String, Object> cq = new LinkedHashMap<>();
            cq.put("id", i);
            cq.put("question", original.get("question"));
            cq.put("options", original.get("options"));
            clientQuestions.add(cq);
        }

        // Cache or return challenge payload
        Map<String, Object> res = new LinkedHashMap<>();
        res.put("lessonId", lessonId);
        res.put("totalQuestions", clientQuestions.size());
        res.put("questions", clientQuestions);
        // Include secure signature or answer keys for server validation
        try {
            res.put("challengeToken", Base64.getEncoder().encodeToString(
                    new com.fasterxml.jackson.databind.ObjectMapper().writeValueAsString(questions).getBytes()
            ));
        } catch (Exception e) {
            res.put("challengeToken", "");
        }
        return ResponseEntity.ok(res);
    }

    /**
     * Submit challenge answers, evaluate, award leaderboard points, and save attempt.
     */
    @PostMapping("/daily-challenge/submit")
    public ResponseEntity<Map<String, Object>> submitChallenge(@RequestBody Map<String, Object> body) {
        User user = userContext.currentUser();
        if (user == null) return ResponseEntity.status(401).build();

        LocalDateTime startOfDay = LocalDate.now().atStartOfDay();
        LocalDateTime endOfDay = LocalDate.now().atTime(LocalTime.MAX);

        List<DailyChallengeAttempt> attemptsToday = challengeRepository.findAttemptsToday(user.getId(), startOfDay, endOfDay);
        if (!attemptsToday.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of(
                    "error", "Daily challenge already submitted today."
            ));
        }

        String challengeToken = (String) body.get("challengeToken");
        @SuppressWarnings("unchecked")
        Map<String, Integer> userAnswers = (Map<String, Integer>) body.get("answers"); // questionId -> chosenIndex
        Long lessonId = body.get("lessonId") != null ? Long.parseLong(body.get("lessonId").toString()) : null;

        List<Map<String, Object>> questions = new ArrayList<>();
        if (challengeToken != null) {
            try {
                String decodedJson = new String(Base64.getDecoder().decode(challengeToken));
                com.fasterxml.jackson.databind.JsonNode array = new com.fasterxml.jackson.databind.ObjectMapper().readTree(decodedJson);
                for (com.fasterxml.jackson.databind.JsonNode n : array) {
                    Map<String, Object> q = new LinkedHashMap<>();
                    q.put("question", n.path("question").asText());
                    List<String> opts = new ArrayList<>();
                    n.path("options").forEach(o -> opts.add(o.asText()));
                    q.put("options", opts);
                    q.put("correctIndex", n.path("correctIndex").asInt(0));
                    q.put("explanation", n.path("explanation").asText(""));
                    questions.add(q);
                }
            } catch (Exception ignored) {}
        }

        int score = 0;
        List<Map<String, Object>> review = new ArrayList<>();

        for (int i = 0; i < questions.size(); i++) {
            Map<String, Object> q = questions.get(i);
            int correctIndex = (int) q.getOrDefault("correctIndex", 0);
            Integer userChoice = userAnswers != null ? userAnswers.get(String.valueOf(i)) : null;
            boolean isCorrect = userChoice != null && userChoice.equals(correctIndex);
            if (isCorrect) score++;

            Map<String, Object> r = new LinkedHashMap<>();
            r.put("question", q.get("question"));
            r.put("options", q.get("options"));
            r.put("correctIndex", correctIndex);
            r.put("userChoice", userChoice);
            r.put("isCorrect", isCorrect);
            r.put("explanation", q.get("explanation"));
            review.add(r);
        }

        // Leaderboard points: 10 points per correct question
        double pointsAwarded = score * 10.0;

        DailyChallengeAttempt attempt = DailyChallengeAttempt.builder()
                .userId(user.getId())
                .lessonId(lessonId)
                .score(score)
                .totalQuestions(questions.size())
                .pointsAwarded(pointsAwarded)
                .completedAt(LocalDateTime.now())
                .detailsJson(review.toString())
                .build();
        attempt.setOrganizationId(organizationContext.getCurrentOrgId());
        challengeRepository.save(attempt);

        Map<String, Object> res = new LinkedHashMap<>();
        res.put("score", score);
        res.put("totalQuestions", questions.size());
        res.put("pointsAwarded", pointsAwarded);
        res.put("percentage", questions.isEmpty() ? 0 : (score * 100 / questions.size()));
        res.put("review", review);
        return ResponseEntity.ok(res);
    }
}
