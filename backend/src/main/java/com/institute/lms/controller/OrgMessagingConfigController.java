package com.institute.lms.controller;

import com.institute.lms.entity.MessagingChannel;
import com.institute.lms.entity.OrgMessagingConfig;
import com.institute.lms.service.OrgMessagingConfigService;
import com.institute.lms.util.OrganizationContext;
import com.institute.lms.util.UserContext;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * The tenant's own SMS/WhatsApp vendor configuration (Twilio today; the
 * abstraction is vendor-pluggable so adding another provider is a new
 * {@code MessagingService} implementation, not a redesign).
 *
 * <p>Credentials are write-only, same as {@link OrgRazorpayConfigController}:
 * reads return a masked hint per credential key, and a blank value on write
 * means "keep the existing one".
 */
@RestController
@RequestMapping("/api/org-messaging-config")
@RequiredArgsConstructor
@Slf4j
public class OrgMessagingConfigController {
    private final OrgMessagingConfigService configService;
    private final com.institute.lms.service.messaging.MessagingService messagingService;
    private final OrganizationContext organizationContext;
    private final UserContext userContext;

    @GetMapping
    public ResponseEntity<Map<String, Object>> get() {
        Long orgId = organizationContext.getCurrentOrgId();
        Map<String, Object> body = new LinkedHashMap<>();
        for (MessagingChannel channel : MessagingChannel.values()) {
            body.put(channel.name(), toMap(configService.getConfig(orgId, channel).orElse(null)));
        }
        return ResponseEntity.ok(body);
    }

    @PostMapping("/{channel}/test")
    public ResponseEntity<?> test(@PathVariable String channel, @RequestBody Map<String, Object> payload) {
        userContext.requireOrgAdmin();
        Long orgId = organizationContext.getCurrentOrgId();

        MessagingChannel ch;
        try {
            ch = MessagingChannel.valueOf(channel.trim().toUpperCase());
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", "Unknown channel: " + channel));
        }

        String toPhone = str(payload.get("toPhone"));
        String message = str(payload.get("message"));
        if (toPhone == null || toPhone.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "Recipient phone number is required."));
        }
        if (message == null || message.isBlank()) {
            message = "Test " + ch.name() + " notification from LMS platform. Your messaging integration is working properly!";
        }

        var result = messagingService.sendWithResult(orgId, ch, toPhone, message);
        if (result.isSuccess()) {
            return ResponseEntity.ok(Map.of(
                    "success", true,
                    "message", "Test " + ch.name() + " message dispatched successfully!",
                    "details", result.message()
            ));
        } else {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "error", result.message() != null ? result.message() : "Failed to dispatch test message."
            ));
        }
    }

    @PutMapping("/{channel}")
    public ResponseEntity<?> save(@PathVariable String channel, @RequestBody Map<String, Object> payload) {
        userContext.requireOrgAdmin();
        Long orgId = organizationContext.getCurrentOrgId();

        MessagingChannel ch;
        try {
            ch = MessagingChannel.valueOf(channel.trim().toUpperCase());
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", "Unknown channel: " + channel));
        }

        try {
            String vendor = str(payload.get("vendor"));
            Boolean enabled = payload.get("enabled") instanceof Boolean b ? b : null;
            Map<String, String> credentials = new LinkedHashMap<>();
            if (payload.get("credentials") instanceof Map<?, ?> map) {
                map.forEach((k, v) -> credentials.put(String.valueOf(k), v != null ? String.valueOf(v) : null));
            }
            configService.saveConfig(orgId, ch, vendor, credentials, enabled);
            return get();
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            log.error("Failed to save messaging config for org {} channel {}", orgId, channel, e);
            return ResponseEntity.badRequest().body(Map.of("error", "Could not save the messaging settings."));
        }
    }

    private Map<String, Object> toMap(OrgMessagingConfig config) {
        Map<String, Object> map = new LinkedHashMap<>();
        if (config == null) {
            map.put("configured", false);
            map.put("enabled", false);
            map.put("vendor", null);
            map.put("credentialHints", Map.of());
            return map;
        }
        map.put("configured", true);
        map.put("enabled", Boolean.TRUE.equals(config.getEnabled()));
        map.put("vendor", config.getVendor());
        Map<String, String> hints = new LinkedHashMap<>();
        configService.parseCredentials(config).forEach((k, v) -> hints.put(k, mask(v)));
        map.put("credentialHints", hints);
        return map;
    }

    private static String str(Object value) {
        return value instanceof String s ? s : null;
    }

    private static String mask(String secret) {
        if (secret == null || secret.isBlank()) return null;
        String trimmed = secret.trim();
        return trimmed.length() <= 4 ? "****" : "****" + trimmed.substring(trimmed.length() - 4);
    }
}
