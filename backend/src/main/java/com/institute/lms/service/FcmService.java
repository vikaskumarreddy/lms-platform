package com.institute.lms.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.auth.oauth2.GoogleCredentials;
import com.institute.lms.repository.SystemConfigRepository;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Sends real push notifications via the Firebase Cloud Messaging HTTP v1 API,
 * using credentials the admin pastes into the System Config screen
 * (firebase.serviceAccountJson). Nothing here is hardcoded: as soon as the
 * admin fills in the service-account JSON and flips push.enabled = true,
 * every call site below (broadcasts, deadline reminders, class reminders,
 * leaderboard shout-outs, interview slot confirmations) starts actually
 * delivering pushes with zero redeploy.
 */
@Service
public class FcmService {

    private final SystemConfigRepository systemConfigRepository;
    private final RestTemplate restTemplate = new RestTemplate();
    private final ObjectMapper objectMapper = new ObjectMapper();

    private static final String FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";

    public FcmService(SystemConfigRepository systemConfigRepository) {
        this.systemConfigRepository = systemConfigRepository;
    }

    private String getConfig(String key, String defaultValue) {
        return systemConfigRepository.findByConfigKey(key)
                .map(c -> c.getConfigValue())
                .filter(v -> v != null && !v.isBlank())
                .orElse(defaultValue);
    }

    public boolean isPushEnabled() {
        return "true".equalsIgnoreCase(getConfig("push.enabled", "false"));
    }

    private String getServiceAccountJson() {
        return getConfig("firebase.serviceAccountJson", "");
    }

    /**
     * Sends a push notification to a single device token. Silently no-ops
     * (returns false) if push isn't configured/enabled yet, or the token is
     * missing -- callers always keep working (and keep saving in-app
     * Notification rows) whether or not push is turned on.
     */
    public boolean sendToToken(String fcmToken, String title, String body, Map<String, String> data) {
        if (!isPushEnabled() || fcmToken == null || fcmToken.isBlank()) {
            return false;
        }
        String serviceAccountJson = getServiceAccountJson();
        if (serviceAccountJson.isBlank()) {
            return false;
        }
        try {
            String projectId = extractProjectId(serviceAccountJson);
            String accessToken = mintAccessToken(serviceAccountJson);

            Map<String, Object> message = new LinkedHashMap<>();
            Map<String, Object> notification = new LinkedHashMap<>();
            notification.put("title", title);
            notification.put("body", body);
            message.put("token", fcmToken);
            message.put("notification", notification);
            if (data != null && !data.isEmpty()) {
                message.put("data", data);
            }
            Map<String, Object> requestBody = Map.of("message", message);

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.setBearerAuth(accessToken);

            String url = "https://fcm.googleapis.com/v1/projects/" + projectId + "/messages:send";
            HttpEntity<Map<String, Object>> entity = new HttpEntity<>(requestBody, headers);
            var response = restTemplate.postForEntity(url, entity, String.class);
            return response.getStatusCode() == HttpStatus.OK;
        } catch (Exception e) {
            System.err.println("FCM send failed: " + e.getMessage());
            return false;
        }
    }

    /** Sends the same notification to multiple device tokens, skipping blanks. */
    public void sendToTokens(List<String> tokens, String title, String body, Map<String, String> data) {
        if (tokens == null) return;
        for (String token : tokens) {
            sendToToken(token, title, body, data);
        }
    }

    private String extractProjectId(String serviceAccountJson) throws Exception {
        Map<?, ?> parsed = objectMapper.readValue(serviceAccountJson, Map.class);
        Object projectId = parsed.get("project_id");
        if (projectId == null) throw new IllegalStateException("service account JSON missing project_id");
        return projectId.toString();
    }

    private String mintAccessToken(String serviceAccountJson) throws Exception {
        GoogleCredentials credentials = GoogleCredentials
                .fromStream(new ByteArrayInputStream(serviceAccountJson.getBytes(StandardCharsets.UTF_8)))
                .createScoped(List.of(FCM_SCOPE));
        credentials.refreshIfExpired();
        return credentials.getAccessToken().getTokenValue();
    }
}
