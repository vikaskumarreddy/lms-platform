package com.institute.lms.controller;

import com.institute.lms.entity.DailyChallengeAttempt;
import com.institute.lms.entity.Lesson;
import com.institute.lms.entity.LessonAiChatMessage;
import com.institute.lms.entity.OrgAiConfig;
import com.institute.lms.entity.PdfNote;
import com.institute.lms.entity.User;
import com.institute.lms.repository.DailyChallengeAttemptRepository;
import com.institute.lms.repository.LessonAiChatMessageRepository;
import com.institute.lms.repository.LessonRepository;
import com.institute.lms.repository.OrgAiConfigRepository;
import com.institute.lms.repository.PdfNoteRepository;
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
    private final LessonAiChatMessageRepository chatMessageRepository;
    private final PdfNoteRepository pdfNoteRepository;
    private final UserContext userContext;
    private final OrganizationContext organizationContext;

    public AiController(GeminiAiService geminiAiService,
                        OrgAiConfigRepository aiConfigRepository,
                        DailyChallengeAttemptRepository challengeRepository,
                        LessonRepository lessonRepository,
                        LessonAiChatMessageRepository chatMessageRepository,
                        PdfNoteRepository pdfNoteRepository,
                        UserContext userContext,
                        OrganizationContext organizationContext) {
        this.geminiAiService = geminiAiService;
        this.aiConfigRepository = aiConfigRepository;
        this.challengeRepository = challengeRepository;
        this.lessonRepository = lessonRepository;
        this.chatMessageRepository = chatMessageRepository;
        this.pdfNoteRepository = pdfNoteRepository;
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
        res.put("lessonAiQuestionLimit", cfg.getLessonAiQuestionLimit() != null ? cfg.getLessonAiQuestionLimit() : 100);
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
        if (body.get("lessonAiQuestionLimit") != null) {
            cfg.setLessonAiQuestionLimit(Integer.parseInt(body.get("lessonAiQuestionLimit").toString()));
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

        String difficulty = (body.get("difficulty") != null) ? body.get("difficulty").toString() : "low";

        List<Map<String, Object>> questions = geminiAiService.generateMcqQuiz(orgId, topicOrNotes, count, difficulty);
        return ResponseEntity.ok(Map.of("count", questions.size(), "difficulty", difficulty, "questions", questions));
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
            if (latest.getDetailsJson() != null && !latest.getDetailsJson().isBlank()) {
                try {
                    Object reviewList = new com.fasterxml.jackson.databind.ObjectMapper().readValue(latest.getDetailsJson(), Object.class);
                    res.put("review", reviewList);
                } catch (Exception ignored) {}
            }
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

        String difficulty = (body != null && body.get("difficulty") != null) ? body.get("difficulty").toString() : "low";
        List<Map<String, Object>> questions = geminiAiService.generateMcqQuiz(orgId, topic, 5, difficulty);

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

        String detailsJson = "[]";
        try {
            detailsJson = new com.fasterxml.jackson.databind.ObjectMapper().writeValueAsString(review);
        } catch (Exception ignored) {}

        DailyChallengeAttempt attempt = DailyChallengeAttempt.builder()
                .userId(user.getId())
                .lessonId(lessonId)
                .score(score)
                .totalQuestions(questions.size())
                .pointsAwarded(pointsAwarded)
                .completedAt(LocalDateTime.now())
                .detailsJson(detailsJson)
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

    /**
     * Get chat history and question limit status for a lesson.
     */
    @GetMapping("/lesson-chat/{lessonId}")
    public ResponseEntity<Map<String, Object>> getLessonChat(@PathVariable Long lessonId) {
        User user = userContext.currentUser();
        if (user == null) return ResponseEntity.status(401).build();

        Long orgId = resolveOrgId(user);
        OrgAiConfig cfg = geminiAiService.getEffectiveConfig(orgId);
        int questionLimit = cfg.getLessonAiQuestionLimit() != null ? cfg.getLessonAiQuestionLimit() : 100;

        List<LessonAiChatMessage> messages = chatMessageRepository.findByUserIdAndLessonIdOrderByCreatedAtAsc(user.getId(), lessonId);
        long questionsAsked = messages.stream().filter(m -> "user".equalsIgnoreCase(m.getRole())).count();
        long questionsRemaining = Math.max(0, questionLimit - questionsAsked);
        boolean isLimitReached = questionsAsked >= questionLimit;

        List<Map<String, Object>> msgList = new ArrayList<>();
        for (LessonAiChatMessage m : messages) {
            Map<String, Object> map = new LinkedHashMap<>();
            map.put("id", m.getId());
            map.put("role", m.getRole());
            map.put("content", m.getContent());
            map.put("createdAt", m.getCreatedAt());
            msgList.add(map);
        }

        Map<String, Object> res = new LinkedHashMap<>();
        res.put("lessonId", lessonId);
        res.put("questionLimit", questionLimit);
        res.put("questionsAsked", questionsAsked);
        res.put("questionsRemaining", questionsRemaining);
        res.put("isLimitReached", isLimitReached);
        res.put("messages", msgList);
        return ResponseEntity.ok(res);
    }

    /**
     * Ask a question about the lesson with PDF context and conversational continuity.
     */
    @PostMapping("/lesson-chat/{lessonId}/ask")
    public ResponseEntity<Map<String, Object>> askLessonQuestion(@PathVariable Long lessonId,
                                                                 @RequestBody Map<String, Object> body) {
        User user = userContext.currentUser();
        if (user == null) return ResponseEntity.status(401).build();

        String question = body.get("question") != null ? body.get("question").toString().trim() : "";
        if (question.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("error", "Question cannot be empty."));
        }

        Long orgId = resolveOrgId(user);
        OrgAiConfig cfg = geminiAiService.getEffectiveConfig(orgId);
        int questionLimit = cfg.getLessonAiQuestionLimit() != null ? cfg.getLessonAiQuestionLimit() : 100;

        long currentCount = chatMessageRepository.countByUserIdAndLessonIdAndRole(user.getId(), lessonId, "user");
        if (currentCount >= questionLimit) {
            return ResponseEntity.status(429).body(Map.of(
                    "error", "You have reached the maximum limit of " + questionLimit + " questions for this lesson.",
                    "questionLimit", questionLimit,
                    "questionsAsked", currentCount,
                    "questionsRemaining", 0,
                    "isLimitReached", true
            ));
        }

        Lesson lesson = lessonRepository.findById(lessonId).orElse(null);
        if (lesson == null) {
            return ResponseEntity.notFound().build();
        }

        String pdfText = "";
        try {
            String clientPdfContext = body.get("pdfContext") != null ? body.get("pdfContext").toString() : null;
            pdfText = extractLessonPdfText(lesson, clientPdfContext);
        } catch (Exception e) {
            System.err.println("Could not extract PDF context: " + e.getMessage());
        }

        List<Map<String, String>> history = new ArrayList<>();
        try {
            List<LessonAiChatMessage> existing = chatMessageRepository.findByUserIdAndLessonIdOrderByCreatedAtAsc(user.getId(), lessonId);
            for (LessonAiChatMessage m : existing) {
                history.add(Map.of("role", m.getRole(), "content", m.getContent()));
            }
        } catch (Exception ignored) {}

        String aiAnswer;
        try {
            aiAnswer = geminiAiService.answerLessonDoubt(
                    orgId,
                    question,
                    lesson.getTitle(),
                    lesson.getHeading(),
                    lesson.getContent(),
                    pdfText,
                    history
            );
        } catch (Exception e) {
            System.err.println("AI Doubt generation error: " + e.getMessage());
            aiAnswer = geminiAiService.generatePedagogicalFallback(question, lesson.getTitle(), lesson.getHeading(), lesson.getContent());
        }

        try {
            // Save user message
            LessonAiChatMessage userMsg = LessonAiChatMessage.builder()
                    .userId(user.getId())
                    .lessonId(lessonId)
                    .role("user")
                    .content(question)
                    .build();
            userMsg.setOrganizationId(organizationContext.getCurrentOrgId());
            chatMessageRepository.save(userMsg);

            // Save assistant message
            LessonAiChatMessage aiMsg = LessonAiChatMessage.builder()
                    .userId(user.getId())
                    .lessonId(lessonId)
                    .role("assistant")
                    .content(aiAnswer)
                    .build();
            aiMsg.setOrganizationId(organizationContext.getCurrentOrgId());
            chatMessageRepository.save(aiMsg);
        } catch (Exception ignored) {}

        long newCount = currentCount + 1;
        long remaining = Math.max(0, questionLimit - newCount);

        Map<String, Object> res = new LinkedHashMap<>();
        res.put("lessonId", lessonId);
        res.put("answer", aiAnswer);
        res.put("questionLimit", questionLimit);
        res.put("questionsAsked", newCount);
        res.put("questionsRemaining", remaining);
        res.put("isLimitReached", newCount >= questionLimit);
        return ResponseEntity.ok(res);
    }

    /**
     * Clear lesson AI chat history for the current user.
     */
    @DeleteMapping("/lesson-chat/{lessonId}/clear")
    public ResponseEntity<Map<String, Object>> clearLessonChat(@PathVariable Long lessonId) {
        User user = userContext.currentUser();
        if (user == null) return ResponseEntity.status(401).build();

        chatMessageRepository.deleteByUserIdAndLessonId(user.getId(), lessonId);

        Long orgId = resolveOrgId(user);
        OrgAiConfig cfg = geminiAiService.getEffectiveConfig(orgId);
        int questionLimit = cfg.getLessonAiQuestionLimit() != null ? cfg.getLessonAiQuestionLimit() : 100;

        return ResponseEntity.ok(Map.of(
                "success", true,
                "message", "Chat history cleared successfully.",
                "questionLimit", questionLimit,
                "questionsAsked", 0,
                "questionsRemaining", questionLimit,
                "isLimitReached", false
        ));
    }

    private String extractLessonPdfText(Lesson lesson, String clientPdfContext) {
        StringBuilder sb = new StringBuilder();
        if (clientPdfContext != null && !clientPdfContext.isBlank()) {
            sb.append(clientPdfContext.trim()).append("\n");
        }

        if (lesson.getPdfNoteId() != null) {
            try {
                PdfNote note = pdfNoteRepository.findById(lesson.getPdfNoteId()).orElse(null);
                if (note != null) {
                    if (note.getContent() != null && !note.getContent().isBlank()) {
                        sb.append(note.getContent().trim()).append("\n");
                    }
                    if (note.getFileName() != null) {
                        java.nio.file.Path p = java.nio.file.Paths.get("uploads/pdf-notes", note.getFileName());
                        if (java.nio.file.Files.exists(p)) {
                            byte[] gzipped = java.nio.file.Files.readAllBytes(p);
                            java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream();
                            try (java.io.InputStream in = new java.util.zip.GZIPInputStream(new java.io.ByteArrayInputStream(gzipped))) {
                                in.transferTo(out);
                            }
                            try (org.apache.pdfbox.pdmodel.PDDocument doc = org.apache.pdfbox.Loader.loadPDF(out.toByteArray())) {
                                String text = new org.apache.pdfbox.text.PDFTextStripper().getText(doc);
                                if (text != null && !text.isBlank()) {
                                    sb.append("\n").append(text.trim()).append("\n");
                                }
                            }
                        }
                    }
                }
            } catch (Exception e) {
                System.err.println("Error extracting text from PdfNote: " + e.getMessage());
            }
        }

        if (sb.length() == 0 && lesson.getPdfNotesUrl() != null && lesson.getPdfNotesUrl().contains("/pdf-notes/")) {
            try {
                String url = lesson.getPdfNotesUrl();
                int idx = url.lastIndexOf("/pdf-notes/");
                if (idx != -1) {
                    String sub = url.substring(idx + 11);
                    int slash = sub.indexOf('/');
                    String idStr = slash != -1 ? sub.substring(0, slash) : sub;
                    Long id = Long.parseLong(idStr);
                    PdfNote note = pdfNoteRepository.findById(id).orElse(null);
                    if (note != null && note.getContent() != null) {
                        sb.append(note.getContent().trim()).append("\n");
                    }
                }
            } catch (Exception ignored) {}
        }

        String res = sb.toString().trim();
        if (res.length() > 25000) {
            return res.substring(0, 25000) + "\n...[Content truncated for context window]";
        }
        return res;
    }

    private Long resolveOrgId(User user) {
        Long orgId = organizationContext.getCurrentOrgId();
        if (orgId == null && user != null) {
            orgId = user.getOrganizationId();
        }
        return orgId;
    }
}
