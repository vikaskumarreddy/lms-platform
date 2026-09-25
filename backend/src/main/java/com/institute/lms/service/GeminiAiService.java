package com.institute.lms.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.institute.lms.entity.OrgAiConfig;
import com.institute.lms.repository.OrgAiConfigRepository;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.*;

@Service
public class GeminiAiService {

    private final OrgAiConfigRepository aiConfigRepository;
    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public GeminiAiService(OrgAiConfigRepository aiConfigRepository, RestTemplate restTemplate) {
        this.aiConfigRepository = aiConfigRepository;
        this.restTemplate = restTemplate;
    }

    /**
     * Resolves effective AI configuration for an organization.
     */
    public OrgAiConfig getEffectiveConfig(Long organizationId) {
        if (organizationId != null) {
            Optional<OrgAiConfig> cfg = aiConfigRepository.findByOrganizationId(organizationId);
            if (cfg.isPresent() && cfg.get().getApiKey() != null && !cfg.get().getApiKey().isBlank()) {
                return cfg.get();
            }
        }
        // Check global fallback from database or environment
        List<OrgAiConfig> all = aiConfigRepository.findAll();
        for (OrgAiConfig c : all) {
            if (c.getApiKey() != null && !c.getApiKey().isBlank()) {
                return c;
            }
        }
        String envKey = System.getenv("GEMINI_API_KEY");
        return OrgAiConfig.builder()
                .modelName("gemini-3.6-flash")
                .apiKey(envKey != null ? envKey : "")
                .enabled(true)
                .dailyQuestionLimit(10)
                .dailyChallengeLimit(1)
                .lessonAiQuestionLimit(100)
                .build();
    }

    /**
     * Maps experimental or deprecated model names to current active Gemini API models.
     */
    public String normalizeModelName(String model) {
        if (model == null || model.isBlank()) return "gemini-3.6-flash";
        String m = model.trim();
        if (m.startsWith("models/")) m = m.substring(7);
        // Normalize outdated/deprecated models to standard active Gemini endpoints
        if (m.contains("1.5") || m.contains("2.0") || m.contains("2.5") || m.equalsIgnoreCase("gemini-pro")) {
            return "gemini-3.6-flash";
        }
        return m;
    }

    /**
     * Fetches active models available for the provided Gemini API key.
     */
    public List<Map<String, String>> fetchAvailableModels(String apiKey) {
        if (apiKey == null || apiKey.trim().isEmpty()) {
            return List.of();
        }
        try {
            String url = "https://generativelanguage.googleapis.com/v1beta/models?key=" + apiKey.trim();
            ResponseEntity<String> response = restTemplate.getForEntity(url, String.class);
            if (response.getStatusCode().is2xxSuccessful() && response.getBody() != null) {
                JsonNode root = objectMapper.readTree(response.getBody());
                JsonNode modelsNode = root.path("models");
                if (modelsNode.isArray()) {
                    List<Map<String, String>> result = new ArrayList<>();
                    for (JsonNode m : modelsNode) {
                        String name = m.path("name").asText("");
                        JsonNode methods = m.path("supportedGenerationMethods");
                        boolean supportsGenerate = false;
                        if (methods.isArray()) {
                            for (JsonNode method : methods) {
                                if ("generateContent".equalsIgnoreCase(method.asText())) {
                                    supportsGenerate = true;
                                    break;
                                }
                            }
                        }
                        if (supportsGenerate) {
                            String cleanId = name.replaceFirst("^models/", "");
                            String displayName = m.path("displayName").asText(cleanId);
                            result.add(Map.of(
                                    "id", cleanId,
                                    "name", displayName + " (" + cleanId + ")"
                            ));
                        }
                    }
                    return result;
                }
            }
        } catch (Exception e) {
            System.err.println("Could not fetch available Gemini models: " + e.getMessage());
        }
        return List.of();
    }

    /**
     * Tests connectivity with Google Gemini API using provided model & key.
     */
    public Map<String, Object> testConnection(String modelName, String apiKey) {
        if (apiKey == null || apiKey.trim().isEmpty()) {
            return Map.of("success", false, "error", "API Key cannot be empty");
        }
        String model = normalizeModelName(modelName);
        try {
            String url = "https://generativelanguage.googleapis.com/v1beta/models/" + model + ":generateContent?key=" + apiKey.trim();
            Map<String, Object> payload = Map.of(
                    "contents", List.of(
                            Map.of("parts", List.of(Map.of("text", "Reply with 'OK'.")))
                    )
            );
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            HttpEntity<Map<String, Object>> entity = new HttpEntity<>(payload, headers);

            ResponseEntity<String> response = restTemplate.postForEntity(url, entity, String.class);
            if (response.getStatusCode().is2xxSuccessful()) {
                return Map.of("success", true, "message", "Connected successfully to " + model + "!");
            } else {
                return Map.of("success", false, "error", "Status " + response.getStatusCode());
            }
        } catch (org.springframework.web.client.HttpStatusCodeException ex) {
            String body = ex.getResponseBodyAsString();
            List<Map<String, String>> available = fetchAvailableModels(apiKey);
            String availHint = "";
            if (!available.isEmpty()) {
                List<String> names = available.stream().map(m -> m.get("id")).limit(6).toList();
                availHint = "\n\n💡 Supported active models for your API key:\n• " + String.join("\n• ", names);
            }
            try {
                JsonNode errNode = objectMapper.readTree(body).path("error");
                String msg = errNode.path("message").asText(ex.getMessage());
                return Map.of("success", false, "error", msg + availHint, "availableModels", available);
            } catch (Exception e) {
                return Map.of("success", false, "error", ex.getMessage() + availHint, "availableModels", available);
            }
        } catch (Exception e) {
            return Map.of("success", false, "error", "Connection failed: " + e.getMessage());
        }
    }

    /**
     * Generates an instant AI explanation for a student's Q&A question based on lesson transcripts / notes.
     */
    public String answerDoubt(Long orgId, String title, String content, String contextNotes) {
        OrgAiConfig config = getEffectiveConfig(orgId);
        String apiKey = config.getApiKey();
        if (apiKey == null || apiKey.isBlank()) {
            return generateQaFallback(title, content, contextNotes);
        }

        String prompt = "You are an expert AI Teaching Assistant at a digital academy for B.Tech engineering students. A student asks a question.\n\n"
                + "Title: " + title + "\n"
                + (content != null && !content.isBlank() ? "Details: " + content + "\n\n" : "\n\n")
                + (contextNotes != null && !contextNotes.isBlank() ? "Relevant Lecture Notes / Category:\n" + contextNotes + "\n\n" : "")
                + "Instructions:\n"
                + "1. Provide a clear, step-by-step, pedagogical answer in under 200 words suitable for college students.\n"
                + "2. Include short code examples or clear bullet points.\n"
                + "3. Conclude with a helpful key takeaway.\n"
                + "4. Respond directly and encouragingly to the student.";

        try {
            return callGemini(config.getModelName(), apiKey, prompt, 2048);
        } catch (Exception e) {
            System.err.println("Gemini Q&A resolution error with context (" + e.getMessage() + "). Retrying without extra notes...");
        }

        // Retry with pure question without context if heavy context caused 503/error
        try {
            String simplePrompt = "You are an expert AI Teaching Assistant for B.Tech students. A student asks:\n\n"
                    + "Question: " + title + "\n"
                    + (content != null && !content.isBlank() ? "Details: " + content + "\n\n" : "")
                    + "\nPlease provide a clear, beginner-friendly pedagogical answer with code or bullet points.";
            return callGemini(config.getModelName(), apiKey, simplePrompt, 2048);
        } catch (Exception e2) {
            System.err.println("Gemini Q&A retry failed: " + e2.getMessage());
        }

        // Reliable fallback answering the question
        return generateQaFallback(title, content, contextNotes);
    }

    /**
     * Generates a conversational AI tutor response for a student asking questions about a lesson.
     * Combines lesson materials + PDF notes context + broad model knowledge.
     * If PDF context causes 503/error or overload, automatically falls back to normal AI without PDF context.
     */
    public String answerLessonDoubt(Long orgId, String question, String lessonTitle, String lessonHeading,
                                     String lessonContent, String pdfContextText,
                                     List<Map<String, String>> chatHistory) {
        OrgAiConfig config = getEffectiveConfig(orgId);
        String apiKey = config.getApiKey();
        if (apiKey == null || apiKey.isBlank()) {
            return generatePedagogicalFallback(question, lessonTitle, lessonHeading, lessonContent);
        }

        // Attempt 1: Full context with PDF notes (if available)
        if (pdfContextText != null && !pdfContextText.isBlank()) {
            try {
                String fullPrompt = buildLessonDoubtPrompt(question, lessonTitle, lessonHeading, lessonContent, pdfContextText, chatHistory);
                return callGemini(config.getModelName(), apiKey, fullPrompt, 2048);
            } catch (Exception e) {
                System.err.println("Gemini full context resolution error: " + e.getMessage() + ". Retrying without heavy PDF context...");
            }
        }

        // Attempt 2: Direct question prompt with lesson topic
        try {
            String normalPrompt = buildLessonDoubtPrompt(question, lessonTitle, lessonHeading, lessonContent, null, chatHistory);
            return callGemini(config.getModelName(), apiKey, normalPrompt, 2048);
        } catch (Exception e2) {
            System.err.println("Gemini normal context resolution error: " + e2.getMessage() + ". Retrying pure question...");
        }

        // Attempt 3: Pure question prompt directly to AI model
        try {
            String purePrompt = "You are an expert AI Academic Tutor for B.Tech engineering students. Answer the following student question accurately, clearly, and directly with explanation and code/examples if helpful:\n\n"
                    + "Student Question: " + question + "\n\nAI Tutor:";
            return callGemini(config.getModelName(), apiKey, purePrompt, 2048);
        } catch (Exception e3) {
            System.err.println("Gemini pure question resolution error: " + e3.getMessage());
        }

        // Attempt 4: Intelligent pedagogical fallback so the student is never blocked with a 503 error
        return generatePedagogicalFallback(question, lessonTitle, lessonHeading, lessonContent);
    }

    private String buildLessonDoubtPrompt(String question, String lessonTitle, String lessonHeading,
                                          String lessonContent, String pdfContextText,
                                          List<Map<String, String>> chatHistory) {
        StringBuilder sb = new StringBuilder();
        sb.append("You are an expert AI Academic Tutor and Teaching Mentor for an engineering academy.\n");
        sb.append("Target audience: B.Tech undergraduate students. Explain clearly, directly, and encouragingly.\n\n");
        sb.append("Lesson Title: ").append(lessonTitle != null ? lessonTitle : "Lesson").append("\n");
        if (lessonHeading != null && !lessonHeading.isBlank()) {
            sb.append("Topic: ").append(lessonHeading).append("\n");
        }
        if (lessonContent != null && !lessonContent.isBlank()) {
            sb.append("\n[Lesson Content]:\n").append(lessonContent.trim()).append("\n");
        }
        if (pdfContextText != null && !pdfContextText.isBlank()) {
            // Trim PDF context safely to avoid exceeding token limits
            String safePdf = pdfContextText.trim();
            if (safePdf.length() > 12000) safePdf = safePdf.substring(0, 12000) + "\n...[truncated]";
            sb.append("\n[Lesson Reference Materials]:\n").append(safePdf).append("\n");
        }

        sb.append("\n--- INSTRUCTIONS ---\n");
        sb.append("1. Answer the student's question directly, clearly, and step by step.\n");
        sb.append("2. Use clean markdown formatting, bullet points, and code snippets with language headers where appropriate.\n");
        sb.append("3. Keep explanations tailored to undergraduate engineering students with practical, understandable analogies.\n\n");

        if (chatHistory != null && !chatHistory.isEmpty()) {
            sb.append("--- CONVERSATION HISTORY ---\n");
            int start = Math.max(0, chatHistory.size() - 6);
            for (int i = start; i < chatHistory.size(); i++) {
                Map<String, String> msg = chatHistory.get(i);
                String role = "user".equalsIgnoreCase(msg.get("role")) ? "Student" : "AI Tutor";
                String content = msg.get("content");
                if (content == null || content.isBlank()
                        || content.contains("503")
                        || content.contains("Service Unavailable")
                        || content.contains("encountered an issue")
                        || content.contains("processExample()")) {
                    continue;
                }
                sb.append(role).append(": ").append(content).append("\n");
            }
            sb.append("\n");
        }

        sb.append("Student Question: ").append(question).append("\n");
        sb.append("AI Tutor Response:");
        return sb.toString();
    }

    /**
     * Automatically generates multiple choice questions (MCQs) from lecture notes or topics.
     */
    public List<Map<String, Object>> generateMcqQuiz(Long orgId, String topicOrNotes, int count) {
        return generateMcqQuiz(orgId, topicOrNotes, count, "low");
    }

    public List<Map<String, Object>> generateMcqQuiz(Long orgId, String topicOrNotes, int count, String difficulty) {
        String diff = (difficulty == null || difficulty.isBlank()) ? "low" : difficulty.trim().toLowerCase();
        OrgAiConfig config = getEffectiveConfig(orgId);
        String apiKey = config.getApiKey();
        if (apiKey == null || apiKey.isBlank()) {
            return generateMockQuestions(topicOrNotes, count, diff);
        }

        String difficultyGuidance;
        switch (diff) {
            case "critical":
                difficultyGuidance = "CRITICAL / ADVANCED. Target audience is upper-level engineering students. Create thought-provoking questions testing edge cases, algorithmic efficiency, debugging, error identification, and deeper concepts.";
                break;
            case "medium":
                difficultyGuidance = "MEDIUM / INTERMEDIATE. Target audience is college B.Tech students. Create questions testing practical understanding, standard implementations, and core logic.";
                break;
            case "low":
            default:
                difficultyGuidance = "LOW / BASIC LEVEL. IMPORTANT: Target audience is undergraduate B.Tech college students (beginners/learners, NOT senior working professionals). Focus on fundamental definitions, primary syntax, basic principles, and clear foundational concepts without convoluted trick questions.";
                break;
        }

        String cleanTopic = cleanTopicConcept(topicOrNotes);
        String prompt = "You are an automated exam question paper generator for an engineering college.\n"
                + "Generate exactly " + count + " distinct, high-quality multiple choice questions based on the topic below:\n\n"
                + "Subject Concept: " + cleanTopic + "\n\n"
                + "Difficulty Level: " + difficultyGuidance + "\n\n"
                + "CRITICAL INSTRUCTIONS FOR QUESTION PHRASING:\n"
                + "1. Every question must be a natural, general conceptual question suitable for undergraduate B.Tech college students.\n"
                + "2. NEVER include syllabus metadata or numbering prefixes like 'Module 1', 'Module 2:', 'Chapter 3', 'Unit 2', or 'Section A' anywhere in the question text or options! (e.g., formulate: 'What is the primary role of variables in software development?' NEVER 'What is the primary role of Module 2: Variables...').\n"
                + "3. Do not include leading question numbers like '1.' or 'Q1:' in the 'question' field.\n"
                + "4. Each question must be completely distinct and unique (do NOT repeat questions or answer templates).\n"
                + "5. Provide exactly 4 options per question with exactly one clearly correct answer.\n"
                + "6. Output strictly valid JSON as an array of objects. No markdown formatting around the JSON, no explanations outside the JSON array.\n\n"
                + "JSON Schema:\n"
                + "[\n"
                + "  {\n"
                + "    \"question\": \"Question text here?\",\n"
                + "    \"options\": [\"Option A\", \"Option B\", \"Option C\", \"Option D\"],\n"
                + "    \"correctIndex\": 0,\n"
                + "    \"explanation\": \"Clear explanation of the correct choice.\"\n"
                + "  }\n"
                + "]";

        try {
            String raw = callGemini(config.getModelName(), apiKey, prompt, 4096);
            List<Map<String, Object>> parsed = parseMcqJson(raw, topicOrNotes, count, diff);
            if (!parsed.isEmpty()) return parsed;
        } catch (Exception e) {
            System.err.println("Failed to generate MCQs with Gemini (" + e.getMessage() + "). Using smart fallback questions.");
        }

        return generateMockQuestions(topicOrNotes, count, diff);
    }

    /**
     * Executes Gemini API call with automatic fallback across reliable models and transient retry.
     */
    public String callGemini(String model, String apiKey, String prompt) throws Exception {
        return callGemini(model, apiKey, prompt, 2048);
    }

    public String callGemini(String model, String apiKey, String prompt, int maxTokens) throws Exception {
        String cleanModel = normalizeModelName(model);
        List<String> candidateModels = new ArrayList<>(List.of("gemini-3.6-flash", cleanModel));
        candidateModels = candidateModels.stream()
                .filter(m -> m != null && !m.isBlank())
                .distinct()
                .toList();

        Exception lastException = null;
        for (String candidate : candidateModels) {
            for (int attempt = 0; attempt < 2; attempt++) {
                try {
                    return executeGeminiCall(candidate, apiKey, prompt, maxTokens);
                } catch (org.springframework.web.client.HttpStatusCodeException ex) {
                    lastException = ex;
                    int status = ex.getStatusCode().value();
                    if (status == 404) {
                        break; // Try next model immediately
                    }
                    if (status == 503 || status == 429 || status == 500) {
                        try { Thread.sleep(600L); } catch (InterruptedException ignored) {}
                        continue;
                    }
                    throw ex;
                } catch (Exception ex) {
                    lastException = ex;
                    try { Thread.sleep(500L); } catch (InterruptedException ignored) {}
                }
            }
        }
        if (lastException != null) throw lastException;
        throw new RuntimeException("All Gemini models failed to respond");
    }

    private String executeGeminiCall(String model, String apiKey, String prompt, int maxTokens) throws Exception {
        String url = "https://generativelanguage.googleapis.com/v1beta/models/" + model + ":generateContent?key=" + apiKey.trim();

        Map<String, Object> payload = Map.of(
                "contents", List.of(
                        Map.of("parts", List.of(Map.of("text", prompt)))
                ),
                "generationConfig", Map.of(
                        "temperature", 0.3,
                        "maxOutputTokens", Math.max(maxTokens, 2048)
                )
        );

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        HttpEntity<Map<String, Object>> entity = new HttpEntity<>(payload, headers);

        ResponseEntity<String> response = restTemplate.postForEntity(url, entity, String.class);
        if (!response.getStatusCode().is2xxSuccessful() || response.getBody() == null) {
            throw new RuntimeException("Gemini returned " + response.getStatusCode());
        }

        JsonNode root = objectMapper.readTree(response.getBody());
        JsonNode candidates = root.path("candidates");
        if (candidates.isArray() && !candidates.isEmpty()) {
            JsonNode parts = candidates.get(0).path("content").path("parts");
            if (parts.isArray() && !parts.isEmpty()) {
                return parts.get(0).path("text").asText();
            }
        }
        throw new RuntimeException("Empty response parts from Gemini");
    }

    public String cleanTopicConcept(String topic) {
        if (topic == null || topic.isBlank()) return "variables and core fundamentals";
        String clean = topic.replaceAll("(?i)^(?:Lesson Title|Topic|Lecture Notes|Subject)\\s*[:\\-–—]*", " ")
                            .replaceAll("(?i)\\b(?:module|chapter|unit|section|part|day|week|lecture)\\s*\\d+[:\\s\\-–—]*", " ")
                            .replaceAll("[:\\-–—,\\s]+", " ")
                            .trim();
        if (clean.isBlank()) return "variables and core fundamentals";
        return clean;
    }

    private List<Map<String, Object>> parseMcqJson(String rawText, String fallbackTopic, int count, String difficulty) {
        try {
            String cleaned = rawText.trim();
            // Remove markdown wrapper
            if (cleaned.startsWith("```json")) {
                cleaned = cleaned.substring(7);
            } else if (cleaned.startsWith("```")) {
                cleaned = cleaned.substring(3);
            }
            if (cleaned.endsWith("```")) {
                cleaned = cleaned.substring(0, cleaned.length() - 3);
            }
            cleaned = cleaned.trim();

            int startIdx = cleaned.indexOf('[');
            int endIdx = cleaned.lastIndexOf(']');
            if (startIdx != -1 && endIdx > startIdx) {
                cleaned = cleaned.substring(startIdx, endIdx + 1);
            }

            JsonNode arrayNode = objectMapper.readTree(cleaned);
            if (arrayNode.isArray()) {
                List<Map<String, Object>> list = new ArrayList<>();
                for (JsonNode item : arrayNode) {
                    String qText = item.path("question").asText("").trim();
                    if (qText.isEmpty()) continue;

                    // Strip leading numbers or "Module X:" references from the question text
                    String cleanQ = qText.replaceFirst("^\\s*\\d+[.)\\s:-]+", "")
                                         .replaceFirst("^(?i)Q(?:uestion)?\\s*\\d+[.)\\s:-]+", "")
                                         .replaceAll("(?i)\\b(?:module|chapter|unit|section|lecture)\\s*\\d+[:\\s\\-–—]*", "")
                                         .replaceAll("(?i)\\b(?:module|chapter|unit|section|lecture)\\s*\\d+\\b", "")
                                         .trim();
                    if (cleanQ.isEmpty()) cleanQ = qText;

                    List<String> options = new ArrayList<>();
                    for (JsonNode opt : item.path("options")) {
                        String o = opt.asText("").trim();
                        if (!o.isEmpty()) options.add(o);
                    }
                    if (options.size() < 2) continue;

                    int cIdx = item.path("correctIndex").asInt(0);
                    if (cIdx < 0 || cIdx >= options.size()) cIdx = 0;

                    Map<String, Object> q = new LinkedHashMap<>();
                    q.put("question", cleanQ);
                    q.put("options", options);
                    q.put("correctIndex", cIdx);
                    q.put("explanation", item.path("explanation").asText("Option " + (char)('A' + cIdx) + " is correct."));
                    list.add(q);
                }
                if (!list.isEmpty()) return list;
            }
        } catch (Exception e) {
            System.err.println("Error parsing Gemini JSON: " + e.getMessage() + " | Raw snippet: " + (rawText.length() > 200 ? rawText.substring(0, 200) : rawText));
        }
        return generateMockQuestions(fallbackTopic, count, difficulty);
    }

    private List<Map<String, Object>> generateMockQuestions(String topic, int count, String difficulty) {
        List<Map<String, Object>> list = new ArrayList<>();
        String safeTopic = cleanTopicConcept(topic);

        // Pre-defined set of high-quality beginner B.Tech engineering questions
        List<Map<String, Object>> questionPool = new ArrayList<>(List.of(
            createMcq("What is the primary role of a variable in software development?",
                    List.of("To store and reference data in memory with a designated name", "To eliminate the need for memory allocation", "To permanently store data on disk bypassing RAM", "To disable compile-time error checks"), 0,
                    "Variables provide named storage in memory so programs can store, retrieve, and manipulate data dynamically."),
            createMcq("Which of the following is considered a primitive data type in most programming languages?",
                    List.of("int", "ArrayList", "String (in Java)", "HashMap"), 0,
                    "int is a basic primitive type representing integers directly without object overhead."),
            createMcq("What is the main difference between the assignment operator '=' and the equality operator '=='?",
                    List.of("'=' assigns a value to a variable, while '==' compares two values for equality", "'=' compares values, while '==' assigns values", "Both operators perform identical operations", "There is no difference in modern languages"), 0,
                    "'=' is used for assignment, whereas '==' evaluates whether two operands are equal."),
            createMcq("What does variable scope define in computer programming?",
                    List.of("The region of a program where a variable is accessible and can be referenced", "The total bytes of memory a variable occupies", "The time taken to compile the program", "The physical hardware sector where data is stored"), 0,
                    "Scope determines the visibility and lifetime of a variable within blocks, methods, or classes."),
            createMcq("Which arithmetic operator is used to calculate the remainder of an integer division?",
                    List.of("% (Modulus operator)", "/ (Division operator)", "* (Multiplication operator)", "^ (Bitwise XOR)"), 0,
                    "The modulus operator (%) returns the remainder after integer division (e.g. 7 % 3 = 1)."),
            createMcq("What is type casting (type conversion) in software engineering?",
                    List.of("Converting a value from one data type to another compatible data type", "Deleting variables from system memory", "Running code without compiling it first", "Encrypting source code strings"), 0,
                    "Type casting converts a value from one data type into another (e.g. casting double to int)."),
            createMcq("What is the primary benefit of declaring a variable as constant (e.g. 'final' in Java or 'const' in JS/C++)?",
                    List.of("It prevents accidental modification of the value after initialization", "It forces the variable to change dynamically at runtime", "It increases execution time intentionally", "It bypasses standard scope rules"), 0,
                    "Constants ensure values remain immutable after assignment, improving safety and maintainability."),
            createMcq("Which of the following represents a valid identifier (variable name) convention in programming?",
                    List.of("studentAge", "1stStudent", "student-age (with hyphen)", "class (reserved keyword)"), 0,
                    "Identifiers cannot start with numbers, cannot be reserved keywords, and cannot use hyphens in standard languages."),
            createMcq("What type of data does a boolean variable hold?",
                    List.of("Either true or false", "Arbitrary floating-point numbers", "Single Unicode characters only", "Any textual string"), 0,
                    "A boolean represents truth values: true or false, used extensively in conditional statements."),
            createMcq("In programming, what is the consequence of dividing an integer by zero?",
                    List.of("It causes an ArithmeticException or runtime crash", "It returns zero automatically without any issue", "It clears all operating system memory", "It switches the processor into idle mode"), 0,
                    "Dividing by zero is mathematically undefined and triggers a runtime exception in most languages."),
            createMcq("Which logical operator returns true only if BOTH operands are true?",
                    List.of("&& (Logical AND)", "|| (Logical OR)", "! (Logical NOT)", "^ (Bitwise XOR)"), 0,
                    "Logical AND (&&) requires both condition A and condition B to be true to evaluate to true."),
            createMcq("What is an array in computer programming?",
                    List.of("A contiguous collection of elements of the same data type", "A random collection of unrelated file pointers", "A hardware component on the motherboard", "A database query language"), 0,
                    "An array is a linear data structure storing fixed-size elements of the same type in contiguous memory."),
            createMcq("What is the starting index of elements in most zero-indexed programming languages (C, C++, Java, Python)?",
                    List.of("0", "1", "-1", "Depends on RAM size"), 0,
                    "In zero-indexed languages, the first element of an array or list is always at index 0."),
            createMcq("What is the purpose of an 'if-else' statement in programming?",
                    List.of("To execute alternative blocks of code based on whether a condition evaluates to true or false", "To repeat an operation infinite times", "To declare new variables globally", "To terminate program execution permanently"), 0,
                    "if-else provides conditional branching based on boolean evaluations."),
            createMcq("Which loop is guaranteed to execute its code block at least once?",
                    List.of("do-while loop", "while loop", "for loop", "enhanced for-each loop"), 0,
                    "The do-while loop evaluates its condition at the end of the loop, ensuring at least one execution."),
            createMcq("What is the primary function of a method / function in a software application?",
                    List.of("To encapsulate reusable blocks of logic and avoid redundant code", "To increase code file size intentionally", "To slow down memory access", "To restart the host operating system"), 0,
                    "Functions promote modularity, reusability, and readability by grouping operations into named blocks."),
            createMcq("What happens when a variable goes out of its declared scope?",
                    List.of("It becomes inaccessible and eligible for memory deallocation or garbage collection", "It becomes a global variable permanently", "It triggers a hardware interrupt", "It is written to permanent disk storage"), 0,
                    "When execution leaves a variable's scope, its reference is destroyed and memory is freed."),
            createMcq("Which data type is best suited for storing monetary values with precise decimals?",
                    List.of("BigDecimal or double/float depending on precision requirements", "boolean", "char", "short"), 0,
                    "Floating-point types or dedicated decimal types like BigDecimal store fractional numerical values."),
            createMcq("What does a compiler do in programming languages like Java or C++?",
                    List.of("Translates human-readable source code into machine code or bytecode", "Runs a spell checker on documentation", "Replaces hardware CPU registers", "Connects to the internet"), 0,
                    "Compilers analyze and translate source code into executable binaries or bytecode."),
            createMcq("Why are clean code conventions and descriptive variable names emphasized in engineering?",
                    List.of("To improve code readability, ease debugging, and facilitate team collaboration", "To make compilation slower", "To confuse unauthorized viewers", "To bypass code reviews"), 0,
                    "Readable, well-named code is essential for maintainability and collaboration in software engineering.")
        ));

        int total = Math.min(count, questionPool.size());
        for (int i = 0; i < total; i++) {
            list.add(questionPool.get(i));
        }

        // If user requested more questions than in pool, create distinct conceptual variations
        if (list.size() < count) {
            int extra = count - list.size();
            for (int k = 0; k < extra; k++) {
                int idx = k % questionPool.size();
                Map<String, Object> base = questionPool.get(idx);
                Map<String, Object> copy = new LinkedHashMap<>(base);
                copy.put("question", "(Review Question) " + base.get("question"));
                list.add(copy);
            }
        }
        return list;
    }

    private Map<String, Object> createMcq(String question, List<String> options, int correctIdx, String explanation) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("question", question);
        m.put("options", options);
        m.put("correctIndex", correctIdx);
        m.put("explanation", explanation);
        return m;
    }

    public String generatePedagogicalFallback(String question, String lessonTitle, String lessonHeading, String lessonContent) {
        String qLower = question != null ? question.toLowerCase() : "";
        String topic = lessonHeading != null && !lessonHeading.isBlank() ? lessonHeading : (lessonTitle != null ? lessonTitle : "Engineering Concept");

        // Specific high-quality explanations for common student questions
        if (qLower.contains("jdk") || qLower.contains("jre") || qLower.contains("jvm")) {
            return "🤖 **AI Tutor**\n\n"
                    + "### Understanding JDK, JRE, and JVM\n\n"
                    + "• **JDK (Java Development Kit)**:\n"
                    + "The complete software development environment needed to **build** Java applications. It includes the Java compiler (`javac`), development tools (like `jdb` and `javadoc`), and the JRE. As a developer writing code, you need the JDK.\n\n"
                    + "• **JRE (Java Runtime Environment)**:\n"
                    + "The package required to **run** Java applications. It contains the Java Virtual Machine (JVM) plus core class libraries (`java.lang`, `java.util`, etc.) and supporting files. Users who only need to execute compiled programs need the JRE.\n\n"
                    + "• **JVM (Java Virtual Machine)**:\n"
                    + "The abstract execution engine that actually runs Java bytecode (`.class` files). It converts bytecode into native machine instructions for your specific OS (Windows, Linux, macOS). This is what makes Java **platform-independent** (\"Write Once, Run Anywhere\").\n\n"
                    + "💡 **Hierarchy Summary**:\n"
                    + "`JDK ⊃ JRE ⊃ JVM` (JDK contains the JRE, which contains the JVM).";
        }

        if (qLower.contains("variable") || qLower.contains("data type")) {
            return "🤖 **AI Tutor**\n\n"
                    + "### Core Fundamentals: Variables & Data Types\n\n"
                    + "• **Variables**: Named storage locations in computer memory that hold data which can be modified during program execution.\n\n"
                    + "• **Primitive Data Types**: Basic building blocks (e.g., `int`, `float`, `double`, `char`, `boolean`) that store raw values directly in memory.\n\n"
                    + "• **Non-Primitive (Reference) Types**: Complex types like Objects, Arrays, and Strings that reference memory addresses.\n\n"
                    + "💡 **Best Practice for College Students**:\n"
                    + "Always choose the smallest data type that safely accommodates your range of values to optimize memory efficiency.";
        }

        // Direct pedagogical breakdown for general questions
        return "🤖 **AI Tutor**\n\n"
                + "### Addressing Your Doubt on " + topic + "\n\n"
                + "**Question**: \"" + question + "\"\n\n"
                + "1. **Definition & Purpose**: In " + topic + ", this concept is fundamental for organizing program state, ensuring predictable execution, and eliminating unintended side effects.\n\n"
                + "2. **Key Mechanism**: Always follow established engineering standards—declare appropriate scopes, validate inputs, and structure operations so that each function has a single, well-defined responsibility.\n\n"
                + "3. **Recommended College Practice**: Use descriptive variable names, write clear comments explaining why rather than what, and test boundary conditions.\n\n"
                + "💡 **Study Tip**: Review your lecture notes on **" + topic + "** and try tracing variable states step-by-step with a quick example!";
    }

    private String generateQaFallback(String title, String content, String contextNotes) {
        String combined = (title + " " + (content != null ? content : "")).toLowerCase();
        if (combined.contains("jdk") || combined.contains("jre") || combined.contains("jvm")) {
            return "🤖 **AI Teaching Assistant**\n\n"
                    + "### JDK vs JRE vs JVM Overview\n\n"
                    + "• **JDK (Java Development Kit)**: Contains the compiler (`javac`) + development utilities + JRE. Used to **develop** Java code.\n"
                    + "• **JRE (Java Runtime Environment)**: Contains libraries + JVM. Used to **run** Java applications.\n"
                    + "• **JVM (Java Virtual Machine)**: The core engine that executes bytecode on host hardware.\n\n"
                    + "💡 **Relationship**: JDK > JRE > JVM.";
        }

        return "🤖 **AI Teaching Assistant**\n\n"
                + "Thank you for asking: **" + title + "**\n\n"
                + "### Solution Steps:\n"
                + "1. **Core Principle**: In software development, ensure clear separation of concerns and check that all inputs and types match expected interfaces.\n"
                + "2. **Debugging Tip**: Place print statements or debug breakpoints to inspect variable values at each transition.\n"
                + (content != null && !content.isBlank() ? "3. **Regarding details**: Ensure proper memory lifecycle and object state initialization.\n" : "")
                + "\n💡 If you need specialized guidance from your mentor, click **'Escalate to Faculty'**!";
    }
}
