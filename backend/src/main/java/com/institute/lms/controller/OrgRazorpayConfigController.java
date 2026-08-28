package com.institute.lms.controller;

import com.institute.lms.entity.OrgRazorpayConfig;
import com.institute.lms.service.StudentPaymentService;
import com.institute.lms.util.OrganizationContext;
import com.institute.lms.util.UserContext;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * The tenant's own Razorpay credentials.
 *
 * <p>Multi-account by design: each organization collects into its own Razorpay
 * account, so student fees land in the institute's bank rather than the platform's
 * and are never pooled across tenants.
 *
 * <p>Secrets are write-only. Reads return a masked hint (last 4 characters) so an
 * admin can confirm which key is stored without the value being recoverable from
 * the browser, and a blank secret on write means "keep the existing one".
 */
@RestController
@RequestMapping("/api/org-razorpay-config")
@RequiredArgsConstructor
@Slf4j
public class OrgRazorpayConfigController {
  private final StudentPaymentService paymentService;
  private final OrganizationContext organizationContext;
  private final UserContext userContext;

  @GetMapping
  public ResponseEntity<Map<String, Object>> get() {
    Long orgId = organizationContext.getCurrentOrgId();
    Map<String, Object> body = new LinkedHashMap<>();

    var existing = paymentService.getConfig(orgId);
    if (existing.isEmpty()) {
      body.put("configured", false);
      body.put("paymentEnabled", false);
      body.put("amountPerStudent", 0L);
      body.put("razorpayKeyId", null);
      body.put("keySecretSet", false);
      body.put("webhookSecretSet", false);
      return ResponseEntity.ok(body);
    }

    OrgRazorpayConfig config = existing.get();
    body.put("configured", true);
    body.put("paymentEnabled", Boolean.TRUE.equals(config.getPaymentEnabled()));
    body.put("amountPerStudent", config.getAmountPerStudent() != null ? config.getAmountPerStudent() : 0L);
    // The key id is a public identifier and is safe to echo; the secrets are not.
    body.put("razorpayKeyId", config.getRazorpayKeyId());
    body.put("keySecretSet", notBlank(config.getRazorpayKeySecret()));
    body.put("keySecretHint", mask(config.getRazorpayKeySecret()));
    body.put("webhookSecretSet", notBlank(config.getRazorpayWebhookSecret()));
    body.put("webhookSecretHint", mask(config.getRazorpayWebhookSecret()));
    return ResponseEntity.ok(body);
  }

  @PutMapping
  public ResponseEntity<?> save(@RequestBody Map<String, Object> payload) {
    userContext.requireOrgAdmin();
    Long orgId = organizationContext.getCurrentOrgId();
    try {
      paymentService.saveConfig(
              orgId,
              str(payload.get("razorpayKeyId")),
              str(payload.get("razorpayKeySecret")),
              str(payload.get("razorpayWebhookSecret")),
              payload.get("amountPerStudent") instanceof Number n ? n.longValue() : null,
              payload.get("paymentEnabled") instanceof Boolean b ? b : null
      );
      return get();
    } catch (IllegalArgumentException e) {
      return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
    } catch (Exception e) {
      log.error("Failed to save Razorpay config for org {}", orgId, e);
      return ResponseEntity.badRequest().body(Map.of("error", "Could not save the gateway settings."));
    }
  }

  private static String str(Object value) {
    return value instanceof String s ? s : null;
  }

  private static boolean notBlank(String value) {
    return value != null && !value.isBlank();
  }

  private static String mask(String secret) {
    if (!notBlank(secret)) return null;
    String trimmed = secret.trim();
    return trimmed.length() <= 4 ? "****" : "****" + trimmed.substring(trimmed.length() - 4);
  }
}
