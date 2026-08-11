package com.institute.lms.controller;

import com.institute.lms.entity.SystemConfig;
import com.institute.lms.repository.SystemConfigRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Admin-managed system configuration (Firebase, Razorpay, JWT, etc.).
 * The admin CRUD endpoints require authentication (see SecurityConfig); the
 * "/public/firebase" endpoint is intentionally open so the mobile app can
 * bootstrap its Firebase config at startup without a login.
 */
@RestController
@RequestMapping("/api/system-config")
public class SystemConfigController {

    private final SystemConfigRepository systemConfigRepository;

    public SystemConfigController(SystemConfigRepository systemConfigRepository) {
        this.systemConfigRepository = systemConfigRepository;
    }

    @GetMapping
    public List<SystemConfig> getAll() {
        return systemConfigRepository.findAll();
    }

    @GetMapping("/category/{category}")
    public List<SystemConfig> getByCategory(@PathVariable String category) {
        return systemConfigRepository.findByCategory(category);
    }

    @PutMapping("/{id}")
    public ResponseEntity<SystemConfig> update(@PathVariable Long id, @RequestBody Map<String, String> body) {
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
        return systemConfigRepository.findByConfigKey(key)
                .map(existing -> {
                    if (body.containsKey("configValue")) {
                        existing.setConfigValue(body.get("configValue"));
                    }
                    return ResponseEntity.ok(systemConfigRepository.save(existing));
                })
                .orElse(ResponseEntity.notFound().build());
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
