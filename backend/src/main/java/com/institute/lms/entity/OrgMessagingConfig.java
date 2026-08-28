package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.*;

/**
 * Per-organization, per-channel messaging vendor configuration (e.g. Twilio
 * SMS or Twilio WhatsApp). Mirrors {@link OrgRazorpayConfig}: credentials live
 * in {@link #credentialsJson} and are never echoed back verbatim by the
 * controller layer, only as a masked hint.
 */
@Entity
@Table(name = "org_messaging_config")
@Data
@EqualsAndHashCode(callSuper = true)
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OrgMessagingConfig extends BaseEntity {

    @Enumerated(EnumType.STRING)
    @Column(name = "channel", nullable = false, length = 20)
    private MessagingChannel channel;

    /** e.g. "TWILIO". Kept as a plain string so adding a vendor is not a schema change. */
    @Column(name = "vendor", nullable = false, length = 30)
    private String vendor;

    /** JSON blob of vendor-specific credentials, e.g. {"accountSid","authToken","fromNumber"}. */
    @Column(name = "credentials_json", columnDefinition = "TEXT")
    private String credentialsJson;

    @Column(name = "enabled")
    private Boolean enabled = false;
}
