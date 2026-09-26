package com.institute.lms.service.messaging;

import com.institute.lms.entity.MessagingChannel;

/**
 * Vendor-pluggable SMS/WhatsApp dispatch. Implementations resolve the org's
 * configured vendor (e.g. Twilio) and credentials themselves; callers only
 * need an organization, a channel, and a recipient phone number.
 */
public interface MessagingService {
    /**
     * Sends {@code message} to {@code toPhone} over {@code channel} using the org's
     * configured vendor. Returns {@code true} only if the vendor call was actually
     * attempted and did not throw; never throws itself, so a messaging outage never
     * breaks the caller (matches the existing safeNotify resilience pattern).
     */
    boolean send(Long organizationId, MessagingChannel channel, String toPhone, String message);

    /**
     * Detailed dispatch method returning vendor response or failure message.
     */
    MessagingResult sendWithResult(Long organizationId, MessagingChannel channel, String toPhone, String message);

    record MessagingResult(boolean success, String responseBody, String message) {
        public boolean isSuccess() { return success; }
    }
}
