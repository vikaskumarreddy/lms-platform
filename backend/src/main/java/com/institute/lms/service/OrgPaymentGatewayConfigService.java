package com.institute.lms.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.institute.lms.entity.OrgPaymentGatewayConfig;
import com.institute.lms.entity.PaymentGateway;
import com.institute.lms.repository.OrgPaymentGatewayConfigRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;

/**
 * Per-organization credentials for the non-Razorpay payment gateways (PayU,
 * Cashfree). Mirrors {@link OrgMessagingConfigService}: a blank incoming
 * credential value means "leave the stored one alone", so echoing a masked
 * hint back into the admin form can never overwrite the real secret.
 */
@Service
@RequiredArgsConstructor
public class OrgPaymentGatewayConfigService {
    private final OrgPaymentGatewayConfigRepository configRepository;
    private final ObjectMapper objectMapper;

    public Optional<OrgPaymentGatewayConfig> getConfig(Long organizationId, PaymentGateway gateway) {
        return configRepository.findByOrganizationIdAndGateway(organizationId, gateway);
    }

    @Transactional
    public OrgPaymentGatewayConfig saveConfig(Long organizationId, PaymentGateway gateway,
                                               Map<String, String> credentials, Long amountPerStudent, Boolean enabled) {
        OrgPaymentGatewayConfig config = configRepository.findByOrganizationIdAndGateway(organizationId, gateway)
                .orElseGet(() -> {
                    OrgPaymentGatewayConfig fresh = new OrgPaymentGatewayConfig();
                    fresh.setOrganizationId(organizationId);
                    fresh.setGateway(gateway);
                    fresh.setPaymentEnabled(false);
                    return fresh;
                });

        if (credentials != null && !credentials.isEmpty()) {
            Map<String, String> merged = new LinkedHashMap<>(parseCredentials(config));
            credentials.forEach((key, value) -> {
                if (value != null && !value.isBlank()) merged.put(key, value.trim());
            });
            try {
                config.setCredentialsJson(objectMapper.writeValueAsString(merged));
            } catch (Exception e) {
                throw new IllegalArgumentException("Could not save gateway credentials.");
            }
        }

        if (amountPerStudent != null) config.setAmountPerStudent(amountPerStudent);
        if (enabled != null) config.setPaymentEnabled(enabled);

        // Turning collection on without credentials would strand every new ONLINE
        // student at a payment screen that can never create an order.
        if (Boolean.TRUE.equals(config.getPaymentEnabled())
                && (config.getCredentialsJson() == null || config.getCredentialsJson().isBlank())) {
            throw new IllegalArgumentException("Add your " + gateway + " credentials before enabling online payments.");
        }

        return configRepository.save(config);
    }

    /** Decodes the stored credentials JSON blob into a plain map. Never throws. */
    public Map<String, String> parseCredentials(OrgPaymentGatewayConfig config) {
        if (config == null || config.getCredentialsJson() == null || config.getCredentialsJson().isBlank()) {
            return Map.of();
        }
        try {
            return objectMapper.readValue(config.getCredentialsJson(), new TypeReference<Map<String, String>>() {});
        } catch (Exception e) {
            return Map.of();
        }
    }
}
