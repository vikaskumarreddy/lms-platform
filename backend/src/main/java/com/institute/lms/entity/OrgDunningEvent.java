package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * One step in the escalating sequence of reminders on an overdue invoice.
 *
 * <p>Recorded rather than just sent, for two reasons: a unique index on
 * {@code (invoice_id, event_type)} stops the same reminder going out twice, and
 * suspending a tenant for non-payment needs to be justifiable with a list of exactly
 * what was sent and when.
 */
@Entity
@Table(name = "org_dunning_events")
@Data
@NoArgsConstructor
public class OrgDunningEvent {

    /** Courtesy note a few days before the due date. */
    public static final String TYPE_REMINDER_BEFORE_DUE = "REMINDER_BEFORE_DUE";
    public static final String TYPE_REMINDER_OVERDUE = "REMINDER_OVERDUE";
    public static final String TYPE_ESCALATION = "ESCALATION";
    /** Final notice before access is restricted. */
    public static final String TYPE_SUSPENSION_WARNING = "SUSPENSION_WARNING";
    public static final String TYPE_SUSPENDED = "SUSPENDED";

    public static final String CHANNEL_EMAIL = "EMAIL";
    public static final String CHANNEL_SMS = "SMS";
    public static final String CHANNEL_WHATSAPP = "WHATSAPP";
    public static final String CHANNEL_IN_APP = "IN_APP";
    public static final String CHANNEL_MANUAL = "MANUAL";

    public static final String STATUS_SENT = "SENT";
    public static final String STATUS_FAILED = "FAILED";
    public static final String STATUS_SKIPPED = "SKIPPED";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "organization_id", nullable = false)
    private Long organizationId;

    @Column(name = "invoice_id")
    private Long invoiceId;

    @Column(name = "attempt_no", nullable = false)
    private Integer attemptNo = 1;

    @Column(name = "event_type", nullable = false, length = 30)
    private String eventType;

    @Column(nullable = false, length = 20)
    private String channel = CHANNEL_EMAIL;

    @Column
    private String recipient;

    @Column
    private String subject;

    @Column(nullable = false, length = 20)
    private String status = STATUS_SENT;

    @Column(name = "failure_reason", columnDefinition = "TEXT")
    private String failureReason;

    @Column(name = "sent_at", nullable = false)
    private LocalDateTime sentAt = LocalDateTime.now();

    /** When the next escalation becomes due. Drives the scheduled sweep. */
    @Column(name = "next_action_at")
    private LocalDateTime nextActionAt;

    @Column(columnDefinition = "TEXT")
    private String payload;

    @PrePersist
    public void prePersist() {
        if (sentAt == null) sentAt = LocalDateTime.now();
        if (attemptNo == null) attemptNo = 1;
        if (channel == null) channel = CHANNEL_EMAIL;
        if (status == null) status = STATUS_SENT;
    }
}
