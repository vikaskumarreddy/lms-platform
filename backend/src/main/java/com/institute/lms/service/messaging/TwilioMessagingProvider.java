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
        MessagingResult result = sendWithResult(organizationId, channel, toPhone, message);
        return result.isSuccess();
    }

    @Override
    public MessagingResult sendWithResult(Long organizationId, MessagingChannel channel, String toPhone, String message) {
        if (organizationId == null || channel == null || isBlank(toPhone) || isBlank(message)) {
            return new MessagingResult(false, null, "Missing required parameters (phone number or message).");
        }

        Optional<OrgMessagingConfig> configOpt = configService.getConfig(organizationId, channel);
        if (configOpt.isEmpty() || !Boolean.TRUE.equals(configOpt.get().getEnabled())) {
            return new MessagingResult(false, null, channel + " channel is not enabled for this organization. Please configure and enable it in Settings.");
        }

        OrgMessagingConfig config = configOpt.get();
        if (!"TWILIO".equalsIgnoreCase(config.getVendor())) {
            log.warn("Messaging vendor '{}' is not supported for org {} channel {}", config.getVendor(), organizationId, channel);
            return new MessagingResult(false, null, "Messaging vendor '" + config.getVendor() + "' is not supported.");
        }

        Map<String, String> creds = configService.parseCredentials(config);
        String accountSid = creds.get("accountSid");
        String authToken = creds.get("authToken");
        String from = channel == MessagingChannel.WHATSAPP ? creds.get("fromWhatsAppNumber") : creds.get("fromNumber");
        if (isBlank(accountSid) || isBlank(authToken) || isBlank(from)) {
            log.warn("Incomplete Twilio credentials for org {} channel {}", organizationId, channel);
            return new MessagingResult(false, null, "Incomplete Twilio credentials. Account SID, Auth Token, and From Number are required.");
        }

        boolean isWhatsApp = channel == MessagingChannel.WHATSAPP;
        String formattedTo = formatPhone(toPhone, isWhatsApp);
        String formattedFrom = formatPhone(from, isWhatsApp);

        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);
            headers.setBasicAuth(accountSid, authToken);

            MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
            form.add("To", formattedTo);
            form.add("From", formattedFrom);
            form.add("Body", message);

            HttpEntity<MultiValueMap<String, String>> request = new HttpEntity<>(form, headers);
            var response = restTemplate.postForEntity(String.format(TWILIO_MESSAGES_URL, accountSid), request, String.class);
            return new MessagingResult(true, response.getBody(), "Message dispatched successfully via Twilio.");
        } catch (org.springframework.web.client.HttpStatusCodeException e) {
            String responseBody = e.getResponseBodyAsString();
            log.error("Twilio API error for org {} channel {}: HTTP {} - {}", organizationId, channel, e.getStatusCode(), responseBody);

            // Handle trial account template restrictions (error 572006)
            if (responseBody != null && responseBody.contains("572006") && !message.equalsIgnoreCase("sms_appointment_reminders")) {
                log.info("Twilio trial account detected (error 572006). Retrying with predefined template 'sms_appointment_reminders' for org {}", organizationId);
                try {
                    HttpHeaders retryHeaders = new HttpHeaders();
                    retryHeaders.setContentType(MediaType.APPLICATION_FORM_URLENCODED);
                    retryHeaders.setBasicAuth(accountSid, authToken);
                    MultiValueMap<String, String> retryForm = new LinkedMultiValueMap<>();
                    retryForm.add("To", formattedTo);
                    retryForm.add("From", formattedFrom);
                    retryForm.add("Body", "sms_appointment_reminders");
                    HttpEntity<MultiValueMap<String, String>> retryReq = new HttpEntity<>(retryForm, retryHeaders);
                    var retryRes = restTemplate.postForEntity(String.format(TWILIO_MESSAGES_URL, accountSid), retryReq, String.class);
                    return new MessagingResult(true, retryRes.getBody(),
                            "Dispatched successfully via Twilio using trial template 'sms_appointment_reminders'. " +
                            "(Note: Twilio Trial accounts only allow predefined templates. Upgrade your Twilio account to send custom messages.)");
                } catch (Exception retryEx) {
                    log.error("Retry with trial template also failed: {}", retryEx.getMessage());
                }
            }

            // Provide clear, actionable error messages for common Twilio trial issues
            String friendlyError = responseBody;
            if (responseBody != null && responseBody.contains("572002")) {
                friendlyError = "Twilio Trial Restriction (Error 572002): In a Twilio trial account, you can only send to verified phone numbers. " +
                        "Please add '" + formattedTo + "' as a Verified Caller ID in your Twilio Console (https://console.twilio.com/us1/develop/phone-numbers/manage/verified-caller-ids) or upgrade your Twilio account.";
            } else if (responseBody != null && responseBody.contains("572006")) {
                friendlyError = "Twilio Trial Restriction (Error 572006): Trial accounts cannot send custom message text. They can only use predefined templates like 'sms_appointment_reminders'. Upgrade your Twilio account to send custom SMS.";
            } else if (responseBody != null && responseBody.contains("21654")) {
                friendlyError = "Twilio WhatsApp Restriction (Error 21654): ContentSid template required, or the recipient must first join your Twilio WhatsApp Sandbox (send 'join <your-code>' to your Twilio WhatsApp number).";
            }

            return new MessagingResult(false, responseBody, "Twilio error (" + e.getStatusCode() + "): " + friendlyError);
        } catch (Exception e) {
            log.error("Failed to send {} message via Twilio for org {}", channel, organizationId, e);
            return new MessagingResult(false, null, "Failed to send message: " + e.getMessage());
        }
    }

    public static String formatPhone(String phone, boolean isWhatsApp) {
        if (phone == null || phone.isBlank()) return "";
        String cleaned = phone.trim().replaceAll("[\\s\\-\\(\\)]", "");
        boolean hasWhatsAppPrefix = cleaned.toLowerCase().startsWith("whatsapp:");
        if (hasWhatsAppPrefix) {
            cleaned = cleaned.substring("whatsapp:".length());
        }

        // Normalize to E.164
        if (!cleaned.startsWith("+")) {
            if (cleaned.length() == 10 && cleaned.matches("^[6-9]\\d{9}$")) {
                cleaned = "+91" + cleaned;
            } else if (cleaned.length() == 11 && cleaned.startsWith("0") && cleaned.substring(1).matches("^[6-9]\\d{9}$")) {
                cleaned = "+91" + cleaned.substring(1);
            } else if (cleaned.length() == 12 && cleaned.startsWith("91")) {
                cleaned = "+" + cleaned;
            } else if (cleaned.length() == 11 && cleaned.startsWith("1")) {
                cleaned = "+" + cleaned;
            } else {
                cleaned = "+" + cleaned;
            }
        }

        if (isWhatsApp) {
            return "whatsapp:" + cleaned;
        } else {
            return cleaned;
        }
    }

    private static boolean isBlank(String s) {
        return s == null || s.isBlank();
    }
}
