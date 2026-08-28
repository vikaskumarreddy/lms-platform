package com.institute.lms.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.institute.lms.entity.MessagingChannel;
import com.institute.lms.entity.OrgMessagingConfig;
import com.institute.lms.repository.OrgMessagingConfigRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Per-organization messaging vendor configuration (SMS / WhatsApp).
 *
 * <p>Mirrors {@code StudentPaymentService}'s gateway-settings section: a blank
 * incoming credential value means "leave the stored one alone", so echoing a
 * masked hint back into the admin form can never overwrite the real secret.
 */
@Service
@RequiredArgsConstructor
public class OrgMessagingConfigService {
    private final OrgMessagingConfigRepository configRepository;
    private final ObjectMapper objectMapper;

    public Optional<OrgMessagingConfig> getConfig(Long organizationId, MessagingChannel channel) {
        return configRepository.findByOrganizationIdAndChannel(organizationId, channel);
    }

    public List<OrgMessagingConfig> getAllConfigs(Long organizationId) {
        return configRepository.findByOrganizationId(organizationId);
    }

    @Transactional
    public OrgMessagingConfig saveConfig(Long organizationId, MessagingChannel channel, String vendor,
                                         Map<String, String> credentials, Boolean enabled) {
        OrgMessagingConfig config = configRepository.findByOrganizationIdAndChannel(organizationId, channel)
                .orElseGet(() -> {
                    OrgMessagingConfig fresh = new OrgMessagingConfig();
                    fresh.setOrganizationId(organizationId);
                    fresh.setChannel(channel);
                    fresh.setEnabled(false);
                    return fresh;
                });

        if (vendor != null && !vendor.isBlank()) config.setVendor(vendor.trim().toUpperCase());

        if (credentials != null && !credentials.isEmpty()) {
            Map<String, String> merged = new LinkedHashMap<>(parseCredentials(config));
            credentials.forEach((key, value) -> {
                if (value != null && !value.isBlank()) merged.put(key, value.trim());
            });
            try {
                config.setCredentialsJson(objectMapper.writeValueAsString(merged));
            } catch (Exception e) {
                throw new IllegalArgumentException("Could not save messaging credentials.");
            }
        }

        if (enabled != null) config.setEnabled(enabled);

        // Turning a channel on without a vendor + credentials would strand every
        // notification meant to go out through it, so refuse it up front.
        if (Boolean.TRUE.equals(config.getEnabled())
                && (config.getVendor() == null || config.getVendor().isBlank()
                || config.getCredentialsJson() == null || config.getCredentialsJson().isBlank())) {
            throw new IllegalArgumentException("Choose a vendor and add its credentials before enabling this channel.");
        }

        return configRepository.save(config);
    }

    /** Decodes the stored credentials JSON blob into a plain map. Never throws. */
    public Map<String, String> parseCredentials(OrgMessagingConfig config) {
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
