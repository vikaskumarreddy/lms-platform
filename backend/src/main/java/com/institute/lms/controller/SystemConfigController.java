package com.institute.lms.controller;

import com.institute.lms.entity.SystemConfig;
import com.institute.lms.repository.SystemConfigRepository;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Admin-managed system configuration (Firebase, Razorpay, JWT, etc.).
 * SystemConfig is a GlobalEntity (shared across every tenant, not per-org),
 * so this is intentionally restricted to admins rather than scoped by tenant.
 * The "/public/firebase" endpoint is intentionally open so the mobile app can
 * bootstrap its Firebase config at startup without a login.
 */
@RestController
@RequestMapping("/api/system-config")
public class SystemConfigController {

    private final SystemConfigRepository systemConfigRepository;
    private final UserContext userContext;

    public SystemConfigController(SystemConfigRepository systemConfigRepository, UserContext userContext) {
        this.systemConfigRepository = systemConfigRepository;
        this.userContext = userContext;
    }

    @GetMapping
    public List<SystemConfig> getAll() {
        userContext.requireOrgAdmin();
        return redact(systemConfigRepository.findAll());
    }

    @GetMapping("/category/{category}")
    public List<SystemConfig> getByCategory(@PathVariable String category) {
        userContext.requireOrgAdmin();
        return redact(systemConfigRepository.findByCategory(category));
    }

    @PutMapping("/{id}")
    public ResponseEntity<SystemConfig> update(@PathVariable Long id, @RequestBody Map<String, String> body) {
        userContext.requireOrgAdmin();
        return systemConfigRepository.findById(id)
                .map(existing -> {
                    if (body.containsKey("configValue")) {
                        existing.setConfigValue(body.get("configValue"));
                    }
                    return ResponseEntity.ok(systemConfigRepository.save(existing));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/by-key/{key}")
    public ResponseEntity<SystemConfig> updateByKey(@PathVariable("key") String key, @RequestBody Map<String, String> body) {
        userContext.requireOrgAdmin();
        return systemConfigRepository.findByConfigKey(key)
                .map(existing -> {
                    if (body.containsKey("configValue")) {
                        existing.setConfigValue(body.get("configValue"));
                    }
                    return ResponseEntity.ok(systemConfigRepository.save(existing));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    /** Masks configValue for secret rows so it isn't echoed back over the wire once set. */
    private List<SystemConfig> redact(List<SystemConfig> configs) {
        for (SystemConfig cfg : configs) {
            if (Boolean.TRUE.equals(cfg.getIsSecret()) && cfg.getConfigValue() != null && !cfg.getConfigValue().isBlank()) {
                cfg.setConfigValue("••••••••");
            }
        }
        return configs;
    }

    /**
     * Public, unauthenticated endpoint the mobile app calls at startup to fetch its
     * Firebase config, so Firebase credentials no longer need to be hardcoded/committed
     * in firebase_options.dart and can be rotated from the admin portal.
     */
    @GetMapping("/public/firebase")
    public Map<String, String> getPublicFirebaseConfig() {
        Map<String, String> result = new LinkedHashMap<>();
        for (String key : List.of("firebase.apiKey", "firebase.appId", "firebase.messagingSenderId", "firebase.projectId")) {
            systemConfigRepository.findByConfigKey(key).ifPresent(cfg ->
                    result.put(key.substring("firebase.".length()), cfg.getConfigValue()));
        }
        return result;
    }
}
