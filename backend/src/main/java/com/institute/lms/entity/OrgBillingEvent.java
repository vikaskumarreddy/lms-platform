package com.institute.lms.entity;

import com.institute.lms.subscription.BillingEventType;
import com.institute.lms.subscription.SubscriptionStatus;
import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * An append-only audit record of a billing or lifecycle action.
 *
 * <p>Billing disputes are argued from this table, so rows are never updated or
 * deleted — a correction is a new event, not an edit. There is deliberately no
 * {@code @PreUpdate} here.
 */
@Entity
@Table(name = "org_billing_events")
@Data
@NoArgsConstructor
public class OrgBillingEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "organization_id", nullable = false)
    private Long organizationId;

    @Column(name = "subscription_instance_id")
    private Long subscriptionInstanceId;

    @Enumerated(EnumType.STRING)
    @Column(name = "event_type", nullable = false, length = 40)
    private BillingEventType eventType;

    @Enumerated(EnumType.STRING)
    @Column(name = "from_status", length = 20)
    private SubscriptionStatus fromStatus;

    @Enumerated(EnumType.STRING)
    @Column(name = "to_status", length = 20)
    private SubscriptionStatus toStatus;

    /** Who caused this — a user email, or {@code system:<component>} for automated sweeps. */
    @Column
    private String actor;

    /** One-line human summary, shown directly in the billing history UI. */
    @Column(length = 500)
    private String summary;

    /** Optional JSON with the machine-readable specifics (amounts, keys, ids). */
    @Column(columnDefinition = "TEXT")
    private String detail;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    public static OrgBillingEvent of(Long organizationId, Long instanceId,
                                     BillingEventType type, String actor, String summary) {
        OrgBillingEvent e = new OrgBillingEvent();
        e.organizationId = organizationId;
        e.subscriptionInstanceId = instanceId;
        e.eventType = type;
        e.actor = actor;
        e.summary = truncate(summary);
        return e;
    }

    /** Column is 500 chars; a long summary must not lose the whole audit row. */
    private static String truncate(String s) {
        if (s == null) {
            return null;
        }
        return s.length() <= 500 ? s : s.substring(0, 497) + "...";
    }

    public void setSummary(String summary) {
        this.summary = truncate(summary);
    }

    @PrePersist
    public void prePersist() {
        if (createdAt == null) createdAt = LocalDateTime.now();
    }
}
