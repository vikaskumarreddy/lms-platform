package com.institute.lms.entity;

import com.institute.lms.subscription.BillingCycle;
import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * A tenant's request to move to a different plan.
 *
 * <p>The Account page's Upgrade button writes here rather than switching the plan
 * outright. Without a live payment gateway, an instant self-serve upgrade would grant
 * a higher plan's entitlements against money that has not been collected — so by
 * default the platform team approves, and only a plan with
 * {@code self_serve_upgrade_enabled} may be applied immediately.
 *
 * <p>A partial unique index allows only one PENDING row per organization, so an
 * impatient admin clicking Upgrade repeatedly does not queue duplicates.
 */
@Entity
@Table(name = "org_plan_change_requests")
@Data
@NoArgsConstructor
public class OrgPlanChangeRequest {

    public static final String STATUS_PENDING = "PENDING";
    public static final String STATUS_APPROVED = "APPROVED";
    public static final String STATUS_REJECTED = "REJECTED";
    public static final String STATUS_CANCELLED = "CANCELLED";

    public static final String KIND_UPGRADE = "UPGRADE";
    public static final String KIND_DOWNGRADE = "DOWNGRADE";
    public static final String KIND_CYCLE_CHANGE = "CYCLE_CHANGE";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "organization_id", nullable = false)
    private Long organizationId;

    @Column(name = "current_instance_id")
    private Long currentInstanceId;

    @Column(name = "requested_plan_id", nullable = false)
    private Long requestedPlanId;

    @Column(name = "requested_plan_code", nullable = false, length = 40)
    private String requestedPlanCode;

    @Enumerated(EnumType.STRING)
    @Column(name = "requested_billing_cycle", nullable = false, length = 10)
    private BillingCycle requestedBillingCycle = BillingCycle.MONTHLY;

    @Column(name = "request_kind", nullable = false, length = 20)
    private String requestKind = KIND_UPGRADE;

    @Column(nullable = false, length = 20)
    private String status = STATUS_PENDING;

    @Column(name = "requested_by_user_id")
    private Long requestedByUserId;

    @Column(name = "requested_by_email")
    private String requestedByEmail;

    @Column(name = "requested_note", columnDefinition = "TEXT")
    private String requestedNote;

    @Column(name = "decided_by")
    private String decidedBy;

    @Column(name = "decided_at")
    private LocalDateTime decidedAt;

    @Column(name = "decision_note", columnDefinition = "TEXT")
    private String decisionNote;

    /** The term created when the request was approved. */
    @Column(name = "resulting_instance_id")
    private Long resultingInstanceId;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @Transient
    public boolean isPending() {
        return STATUS_PENDING.equalsIgnoreCase(status);
    }

    @PrePersist
    public void prePersist() {
        if (createdAt == null) createdAt = LocalDateTime.now();
        if (updatedAt == null) updatedAt = LocalDateTime.now();
        applyDefaults();
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = LocalDateTime.now();
        applyDefaults();
    }

    private void applyDefaults() {
        if (status == null || status.isBlank()) status = STATUS_PENDING;
        if (requestKind == null || requestKind.isBlank()) requestKind = KIND_UPGRADE;
        if (requestedBillingCycle == null) requestedBillingCycle = BillingCycle.MONTHLY;
    }
}
