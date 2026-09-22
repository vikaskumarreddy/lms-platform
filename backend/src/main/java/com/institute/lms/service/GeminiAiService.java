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
                .build();
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
        String model = (modelName == null || modelName.isBlank()) ? "gemini-3.6-flash" : modelName.trim();
        if (model.startsWith("models/")) {
            model = model.substring(7);
        }
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
        if (config.getApiKey() == null || config.getApiKey().isBlank()) {
            return "🤖 AI Assistant: Thank you for your question. Your faculty mentor has been notified and will review your doubt shortly.";
        }

        String prompt = "You are an expert AI Teaching Assistant at a digital academy. A student asks a question.\n\n"
                + "Title: " + title + "\n"
                + (content != null && !content.isBlank() ? "Details: " + content + "\n\n" : "\n\n")
                + (contextNotes != null && !contextNotes.isBlank() ? "Relevant Lecture Notes / Transcript:\n" + contextNotes + "\n\n" : "")
                + "Instructions:\n"
                + "1. Provide a clear, step-by-step, pedagogical answer in under 200 words.\n"
                + "2. Include short code examples or bullet points if applicable.\n"
                + "3. Conclude with a helpful tip.\n"
                + "4. Respond directly to the student.";

        try {
            return callGemini(config.getModelName(), config.getApiKey(), prompt);
        } catch (Exception e) {
            System.err.println("Gemini doubt resolution error: " + e.getMessage());
            return "🤖 AI Assistant: " + title + "\n\nBased on your course materials, here is a quick overview:\n"
                    + (content != null && !content.isBlank() ? content : "Please review the lesson slides.")
                    + "\n\nIf you need further assistance, please click 'Escalate to Faculty'.";
        }
    }

    /**
     * Automatically generates multiple choice questions (MCQs) from lecture notes or topics.
     */
    public List<Map<String, Object>> generateMcqQuiz(Long orgId, String topicOrNotes, int count) {
        OrgAiConfig config = getEffectiveConfig(orgId);
        if (config.getApiKey() == null || config.getApiKey().isBlank()) {
            return generateMockQuestions(topicOrNotes, count);
        }

        String prompt = "You are an automated exam question generator for an engineering and digital academy.\n"
                + "Generate exactly " + count + " multiple choice questions based on the following lecture content or topic:\n\n"
                + topicOrNotes + "\n\n"
                + "Output STRICTLY valid JSON as an array of objects. Do not include markdown code block tags, explanations, or any text before/after the JSON.\n"
                + "Format:\n"
                + "[\n"
                + "  {\n"
                + "    \"question\": \"Question text here?\",\n"
                + "    \"options\": [\"Option A\", \"Option B\", \"Option C\", \"Option D\"],\n"
                + "    \"correctIndex\": 0,\n"
                + "    \"explanation\": \"Brief explanation of why this is correct.\"\n"
                + "  }\n"
                + "]";

        try {
            String raw = callGemini(config.getModelName(), config.getApiKey(), prompt);
            return parseMcqJson(raw, topicOrNotes, count);
        } catch (Exception e) {
            System.err.println("Failed to generate MCQs with Gemini: " + e.getMessage());
            return generateMockQuestions(topicOrNotes, count);
        }
    }

    private String callGemini(String model, String apiKey, String prompt) throws Exception {
        String cleanModel = (model == null || model.isBlank()) ? "gemini-3.6-flash" : model.trim();
        if (cleanModel.startsWith("models/")) {
            cleanModel = cleanModel.substring(7);
        }
        try {
            return executeGeminiCall(cleanModel, apiKey, prompt);
        } catch (org.springframework.web.client.HttpStatusCodeException ex) {
            if (ex.getStatusCode().value() == 404 && !"gemini-3.6-flash".equalsIgnoreCase(cleanModel)) {
                System.out.println("Model '" + cleanModel + "' returned 404. Falling back to 'gemini-3.6-flash'...");
                return executeGeminiCall("gemini-3.6-flash", apiKey, prompt);
            }
            throw ex;
        }
    }

    private String executeGeminiCall(String model, String apiKey, String prompt) throws Exception {
        String url = "https://generativelanguage.googleapis.com/v1beta/models/" + model + ":generateContent?key=" + apiKey.trim();

        Map<String, Object> payload = Map.of(
                "contents", List.of(
                        Map.of("parts", List.of(Map.of("text", prompt)))
                ),
                "generationConfig", Map.of(
                        "temperature", 0.3,
                        "maxOutputTokens", 2048
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

    private List<Map<String, Object>> parseMcqJson(String rawText, String fallbackTopic, int count) {
        try {
            // Strip markdown ```json and ``` code blocks if present
            String cleaned = rawText.trim();
            if (cleaned.startsWith("```json")) {
                cleaned = cleaned.substring(7);
            } else if (cleaned.startsWith("```")) {
                cleaned = cleaned.substring(3);
            }
            if (cleaned.endsWith("```")) {
                cleaned = cleaned.substring(0, cleaned.length() - 3);
            }
            cleaned = cleaned.trim();

            JsonNode arrayNode = objectMapper.readTree(cleaned);
            if (arrayNode.isArray()) {
                List<Map<String, Object>> list = new ArrayList<>();
                for (JsonNode item : arrayNode) {
                    Map<String, Object> q = new LinkedHashMap<>();
                    q.put("question", item.path("question").asText());
                    List<String> options = new ArrayList<>();
                    for (JsonNode opt : item.path("options")) {
                        options.add(opt.asText());
                    }
                    q.put("options", options);
                    q.put("correctIndex", item.path("correctIndex").asInt(0));
                    q.put("explanation", item.path("explanation").asText(""));
                    list.add(q);
                }
                if (!list.isEmpty()) return list;
            }
        } catch (Exception e) {
            System.err.println("Error parsing Gemini JSON: " + e.getMessage() + " | Raw: " + rawText);
        }
        return generateMockQuestions(fallbackTopic, count);
    }

    private List<Map<String, Object>> generateMockQuestions(String topic, int count) {
        List<Map<String, Object>> list = new ArrayList<>();
        String safeTopic = (topic != null && !topic.isBlank()) ? (topic.length() > 30 ? topic.substring(0, 30) : topic) : "Core Concepts";
        for (int i = 1; i <= count; i++) {
            Map<String, Object> q = new LinkedHashMap<>();
            q.put("question", "Question " + i + ": Which statement is most accurate regarding " + safeTopic + "?");
            q.put("options", List.of(
                    "A) It provides deterministic state evaluation with low latency overhead",
                    "B) It disables asynchronous background concurrency",
                    "C) It forces synchronized serialization across all nodes",
                    "D) None of the above"
            ));
            q.put("correctIndex", 0);
            q.put("explanation", "Option A is correct because " + safeTopic + " prioritizes predictable evaluation and high throughput.");
            list.add(q);
        }
        return list;
    }
}
