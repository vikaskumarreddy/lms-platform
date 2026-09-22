package com.institute.lms.service;

import com.institute.lms.entity.ChatMessage;
import com.institute.lms.repository.SystemConfigRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.HashMap;
import java.util.Map;

@Service
@Slf4j
public class FirebaseRealtimeSyncService {

    private final SystemConfigRepository systemConfigRepository;
    private final RestTemplate restTemplate;

    public FirebaseRealtimeSyncService(SystemConfigRepository systemConfigRepository, RestTemplate restTemplate) {
        this.systemConfigRepository = systemConfigRepository;
        this.restTemplate = restTemplate;
    }

    /**
     * Syncs a chat message to Firebase Realtime Database if a database URL or project ID is configured.
     * Fails safe: errors in Firebase sync are logged but do NOT abort saving to PostgreSQL.
     */
    public void syncMessage(Long orgId, ChatMessage message) {
        try {
            var dbUrlOpt = systemConfigRepository.findByConfigKey("firebase.databaseUrl");
            var projectIdOpt = systemConfigRepository.findByConfigKey("firebase.projectId");

            String firebaseUrl = null;
            if (dbUrlOpt.isPresent() && !dbUrlOpt.get().getConfigValue().isBlank()) {
                firebaseUrl = dbUrlOpt.get().getConfigValue().trim();
            } else if (projectIdOpt.isPresent() && !projectIdOpt.get().getConfigValue().isBlank()) {
                firebaseUrl = "https://" + projectIdOpt.get().getConfigValue().trim() + "-default-rtdb.firebaseio.com";
            }

            if (firebaseUrl == null) {
                return;
            }

            if (firebaseUrl.endsWith("/")) {
                firebaseUrl = firebaseUrl.substring(0, firebaseUrl.length() - 1);
            }

            String path = String.format("%s/tenants/%s/batches/%s/messages/%s.json",
                    firebaseUrl,
                    orgId != null ? orgId : "default",
                    message.getBatchId() != null ? message.getBatchId() : "general",
                    message.getId());

            Map<String, Object> payload = new HashMap<>();
            payload.put("id", message.getId());
            payload.put("batchId", message.getBatchId());
            payload.put("senderId", message.getSenderId());
            payload.put("senderName", message.getSenderName());
            payload.put("senderRole", message.getSenderRole());
            payload.put("content", message.getContent());
            payload.put("messageType", message.getMessageType());
            payload.put("codeLanguage", message.getCodeLanguage());
            payload.put("createdAt", message.getCreatedAt() != null ? message.getCreatedAt().toString() : "");

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            HttpEntity<Map<String, Object>> entity = new HttpEntity<>(payload, headers);

            restTemplate.put(path, entity);
            log.info("Synced chat message {} to Firebase Realtime DB", message.getId());
        } catch (Exception e) {
            log.warn("Firebase sync skipped/failed for message {}: {}", message.getId(), e.getMessage());
        }
    }
}
