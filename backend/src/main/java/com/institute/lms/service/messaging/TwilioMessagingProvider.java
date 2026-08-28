package com.institute.lms.service.messaging;

import com.institute.lms.entity.MessagingChannel;
import com.institute.lms.entity.OrgMessagingConfig;
import com.institute.lms.service.OrgMessagingConfigService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestTemplate;

import java.util.Map;
import java.util.Optional;

/**
 * Twilio-backed {@link MessagingService}. Covers both SMS and WhatsApp through
 * the same account/API, per the org's stored {@link OrgMessagingConfig}
 * credentials ({@code accountSid}, {@code authToken}, and {@code fromNumber}
 * or {@code fromWhatsAppNumber} depending on channel).
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class TwilioMessagingProvider implements MessagingService {
    private static final String TWILIO_MESSAGES_URL = "https://api.twilio.com/2010-04-01/Accounts/%s/Messages.json";

    private final OrgMessagingConfigService configService;
    private final RestTemplate restTemplate;

    @Override
    public boolean send(Long organizationId, MessagingChannel channel, String toPhone, String message) {
        if (organizationId == null || channel == null || isBlank(toPhone) || isBlank(message)) return false;

        Optional<OrgMessagingConfig> configOpt = configService.getConfig(organizationId, channel);
        if (configOpt.isEmpty() || !Boolean.TRUE.equals(configOpt.get().getEnabled())) return false;

        OrgMessagingConfig config = configOpt.get();
        if (!"TWILIO".equalsIgnoreCase(config.getVendor())) {
            log.warn("Messaging vendor '{}' is not supported for org {} channel {}", config.getVendor(), organizationId, channel);
            return false;
        }

        Map<String, String> creds = configService.parseCredentials(config);
        String accountSid = creds.get("accountSid");
        String authToken = creds.get("authToken");
        String from = channel == MessagingChannel.WHATSAPP ? creds.get("fromWhatsAppNumber") : creds.get("fromNumber");
        if (isBlank(accountSid) || isBlank(authToken) || isBlank(from)) {
            log.warn("Incomplete Twilio credentials for org {} channel {}", organizationId, channel);
            return false;
        }

        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);
            headers.setBasicAuth(accountSid, authToken);

            MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
            form.add("To", channel == MessagingChannel.WHATSAPP ? "whatsapp:" + toPhone : toPhone);
            form.add("From", channel == MessagingChannel.WHATSAPP ? "whatsapp:" + from : from);
            form.add("Body", message);

            HttpEntity<MultiValueMap<String, String>> request = new HttpEntity<>(form, headers);
            restTemplate.postForEntity(String.format(TWILIO_MESSAGES_URL, accountSid), request, String.class);
            return true;
        } catch (Exception e) {
            log.error("Failed to send {} message via Twilio for org {}", channel, organizationId, e);
            return false;
        }
    }

    private static boolean isBlank(String s) {
        return s == null || s.isBlank();
    }
}
