package com.institute.lms.controller;

import com.institute.lms.entity.OrgPaymentGatewayConfig;
import com.institute.lms.entity.PaymentGateway;
import com.institute.lms.service.OrgPaymentGatewayConfigService;
import com.institute.lms.service.OrganizationService;
import com.institute.lms.util.OrganizationContext;
import com.institute.lms.util.UserContext;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * The tenant's non-Razorpay payment vendor configuration (PayU, Cashfree today).
 * Razorpay keeps its own dedicated {@code /api/org-razorpay-config} endpoint and
 * controller untouched; this one is purely additive for the vendors introduced
 * alongside it, mirroring {@link OrgMessagingConfigController}'s masked-credential
 * pattern since each gateway has its own distinct credential field set.
 */
@RestController
@RequestMapping("/api/org-payment-gateway-config")
@RequiredArgsConstructor
@Slf4j
public class OrgPaymentGatewayConfigController {
    private final OrgPaymentGatewayConfigService configService;
    private final OrganizationService organizationService;
    private final OrganizationContext organizationContext;
    private final UserContext userContext;

    @GetMapping
    public ResponseEntity<Map<String, Object>> get() {
        Long orgId = organizationContext.getCurrentOrgId();
        Map<String, Object> body = new LinkedHashMap<>();
        for (PaymentGateway gateway : PaymentGateway.values()) {
            body.put(gateway.name(), toMap(configService.getConfig(orgId, gateway).orElse(null)));
        }
        body.put("activeGateway", resolveActiveGateway(orgId).name());
        return ResponseEntity.ok(body);
    }

    @PutMapping("/active-gateway")
    public ResponseEntity<Map<String, Object>> setActiveGateway(@RequestBody Map<String, String> payload) {
        userContext.requireOrgAdmin();
        Long orgId = organizationContext.getCurrentOrgId();
        String gateway = payload.get("activeGateway");
        try {
            PaymentGateway.valueOf(gateway.trim().toUpperCase());
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", "Unknown gateway: " + gateway));
        }
        organizationService.updateActiveGateway(orgId, gateway);
        return get();
    }

    @PutMapping("/{gateway}")
    public ResponseEntity<?> save(@PathVariable String gateway, @RequestBody Map<String, Object> payload) {
        userContext.requireOrgAdmin();
        Long orgId = organizationContext.getCurrentOrgId();

        PaymentGateway gw;
        try {
            gw = PaymentGateway.valueOf(gateway.trim().toUpperCase());
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", "Unknown gateway: " + gateway));
        }
        if (gw == PaymentGateway.RAZORPAY) {
            return ResponseEntity.badRequest().body(Map.of(
                    "error", "Razorpay credentials are managed at /api/org-razorpay-config"));
        }

        try {
            Boolean enabled = payload.get("enabled") instanceof Boolean b ? b : null;
            Long amountPerStudent = payload.get("amountPerStudent") instanceof Number n ? n.longValue() : null;
            Map<String, String> credentials = new LinkedHashMap<>();
            if (payload.get("credentials") instanceof Map<?, ?> map) {
                map.forEach((k, v) -> credentials.put(String.valueOf(k), v != null ? String.valueOf(v) : null));
            }
            configService.saveConfig(orgId, gw, credentials, amountPerStudent, enabled);
            return get();
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            log.error("Failed to save payment gateway config for org {} gateway {}", orgId, gateway, e);
            return ResponseEntity.badRequest().body(Map.of("error", "Could not save the payment gateway settings."));
        }
    }

    private PaymentGateway resolveActiveGateway(Long orgId) {
        var org = organizationService.getOrganizationById(orgId);
        return org != null && org.getActiveGateway() != null ? org.getActiveGateway() : PaymentGateway.RAZORPAY;
    }

    private Map<String, Object> toMap(OrgPaymentGatewayConfig config) {
        Map<String, Object> map = new LinkedHashMap<>();
        if (config == null) {
            map.put("configured", false);
            map.put("enabled", false);
            map.put("amountPerStudent", null);
            map.put("credentialHints", Map.of());
            return map;
        }
        map.put("configured", true);
        map.put("enabled", Boolean.TRUE.equals(config.getPaymentEnabled()));
        map.put("amountPerStudent", config.getAmountPerStudent());
        Map<String, String> hints = new LinkedHashMap<>();
        configService.parseCredentials(config).forEach((k, v) -> hints.put(k, mask(v)));
        map.put("credentialHints", hints);
        return map;
    }

    private static String mask(String secret) {
        if (secret == null || secret.isBlank()) return null;
        String trimmed = secret.trim();
        return trimmed.length() <= 4 ? "****" : "****" + trimmed.substring(trimmed.length() - 4);
    }
}
