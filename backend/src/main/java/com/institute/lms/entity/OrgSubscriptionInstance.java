package com.institute.lms.entity;

import com.institute.lms.subscription.BillingCycle;
import com.institute.lms.subscription.SubscriptionChangeReason;
import com.institute.lms.subscription.SubscriptionStatus;
import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * One subscription term for one organization — what the tenant actually bought, as
 * opposed to {@link OrgSubscription}, which is the catalog template they bought it from.
 *
 * <p><strong>This row is the source of truth for enforcement.</strong>
 * {@link #limitsSnapshot} and {@link #entitlementsSnapshot} are frozen copies taken
 * from the plan at purchase or renewal, so editing a plan in the catalog can never
 * reprice or re-limit a tenant mid-term. That is what makes grandfathering work; the
 * previous model, which pointed the organization straight at a live plan row, made it
 * impossible.
 *
 * <p>Not a {@link BaseEntity}: it holds a plain {@code organization_id} with no
 * {@code @TenantId}, so the platform super admin can read and aggregate across
 * organizations through JPA.
 */
@Entity
@Table(name = "org_subscription_instances")
@Data
@NoArgsConstructor
public class OrgSubscriptionInstance {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "organization_id", nullable = false)
    private Long organizationId;

    @Column(name = "plan_id", nullable = false)
    private Long planId;

    /** Denormalised so history stays readable if the plan is renamed or retired. */
    @Column(name = "plan_code", nullable = false, length = 40)
    private String planCode;

    @Column(name = "plan_name")
    private String planName;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private SubscriptionStatus status = SubscriptionStatus.ACTIVE;

    @Enumerated(EnumType.STRING)
    @Column(name = "billing_cycle", nullable = false, length = 10)
    private BillingCycle billingCycle = BillingCycle.MONTHLY;

    // ---- Frozen commercial terms ---------------------------------------

    /** The agreed price for one billing period, as at purchase. Never re-read from the plan. */
    @Column(name = "unit_price")
    private BigDecimal unitPrice;

    @Column(nullable = false, length = 3)
    private String currency = "INR";

    /** Frozen so a reissued invoice reproduces the original tax treatment exactly. */
    @Column(name = "tax_inclusive", nullable = false)
    private Boolean taxInclusive = false;

    @Column(name = "gst_rate_pct", nullable = false)
    private BigDecimal gstRatePct = new BigDecimal("18.00");

    @Column(name = "hsn_sac_code", length = 10)
    private String hsnSacCode;

    // ---- Snapshots and overrides ---------------------------------------

    /** Frozen plan limits. JSON of {@code LimitKey} name to number; absent means unlimited. */
    @Column(name = "limits_snapshot", columnDefinition = "TEXT", nullable = false)
    private String limitsSnapshot = "{}";

    /** Frozen plan entitlements. JSON of {@code Entitlement} name to true or a number. */
    @Column(name = "entitlements_snapshot", columnDefinition = "TEXT", nullable = false)
    private String entitlementsSnapshot = "{}";

    /**
     * Per-tenant negotiated limit overrides, for plans whose limits are declared
     * configurable (Managed Academy, Enterprise). Applied over the snapshot; add-ons
     * are then added on top, so a negotiated 1,500-student limit plus 100 purchased
     * seats resolves to 1,600.
     */
    @Column(name = "limits_override", columnDefinition = "TEXT")
    private String limitsOverride;

    @Column(name = "entitlements_override", columnDefinition = "TEXT")
    private String entitlementsOverride;

    // ---- Term dates ----------------------------------------------------

    @Column(name = "period_start", nullable = false)
    private LocalDateTime periodStart = LocalDateTime.now();

    @Column(name = "period_end")
    private LocalDateTime periodEnd;

    @Column(name = "trial_ends_at")
    private LocalDateTime trialEndsAt;

    /** End of the fully-usable grace window after {@link #periodEnd}. */
    @Column(name = "grace_ends_at")
    private LocalDateTime graceEndsAt;

    /** Set when cancellation is scheduled for term end rather than taking effect now. */
    @Column(name = "cancel_at")
    private LocalDateTime cancelAt;

    @Column(name = "cancelled_at")
    private LocalDateTime cancelledAt;

    @Column(name = "activated_at")
    private LocalDateTime activatedAt;

    @Column(name = "expired_at")
    private LocalDateTime expiredAt;

    @Column(name = "suspended_at")
    private LocalDateTime suspendedAt;

    @Column(name = "suspension_reason", columnDefinition = "TEXT")
    private String suspensionReason;

    @Column(name = "auto_renew", nullable = false)
    private Boolean autoRenew = true;

    // ---- Chain and provenance ------------------------------------------

    @Column(name = "previous_instance_id")
    private Long previousInstanceId;

    @Enumerated(EnumType.STRING)
    @Column(name = "change_reason", nullable = false, length = 30)
    private SubscriptionChangeReason changeReason = SubscriptionChangeReason.NEW;

    @Column(name = "change_note", columnDefinition = "TEXT")
    private String changeNote;

    @Column(name = "po_number", length = 80)
    private String poNumber;

    @Column(name = "quotation_ref", length = 80)
    private String quotationRef;

    @Column(name = "sales_owner", length = 160)
    private String salesOwner;

    @Column(name = "coupon_code", length = 60)
    private String couponCode;

    @Column(name = "discount_amount", nullable = false)
    private BigDecimal discountAmount = BigDecimal.ZERO;

    @Column(columnDefinition = "TEXT")
    private String notes;

    /** Exactly one per organization, enforced by a partial unique index. */
    @Column(name = "is_current", nullable = false)
    private Boolean isCurrent = true;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @Column(name = "created_by")
    private String createdBy;

    // ---- Derived helpers -----------------------------------------------

    @Transient
    public boolean allowsWrites() {
        return status != null && status.allowsWrites();
    }

    @Transient
    public boolean allowsReads() {
        return status != null && status.allowsReads();
    }

    /** True once the paid term has elapsed, regardless of stored status. */
    @Transient
    public boolean isPastPeriodEnd() {
        return periodEnd != null && periodEnd.isBefore(LocalDateTime.now());
    }

    /** True once the grace window after {@link #periodEnd} has elapsed. */
    @Transient
    public boolean isPastGrace() {
        return graceEndsAt != null && graceEndsAt.isBefore(LocalDateTime.now());
    }

    /** Whole days until the term ends; negative once past. Null when there is no end date. */
    @Transient
    public Long getDaysRemaining() {
        if (periodEnd == null) {
            return null;
        }
        return java.time.Duration.between(LocalDateTime.now(), periodEnd).toDays();
    }

    /**
     * The status this term <em>should</em> be in given the clock, independent of what
     * is stored. The scheduled sweep persists these transitions, but read paths also
     * consult this so a tenant is never treated as active purely because the sweep has
     * not run yet — the bug pattern that previously let an expired organization keep
     * full access until someone noticed.
     */
    @Transient
    public SubscriptionStatus getEffectiveStatus() {
        if (status == SubscriptionStatus.SUSPENDED
                || status == SubscriptionStatus.CANCELLED
                || status == SubscriptionStatus.READ_ONLY) {
            return status;
        }
        if (isPastGrace()) {
            return SubscriptionStatus.EXPIRED;
        }
        if (isPastPeriodEnd()) {
            return SubscriptionStatus.GRACE;
        }
        return status;
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
        if (status == null) status = SubscriptionStatus.ACTIVE;
        if (billingCycle == null) billingCycle = BillingCycle.MONTHLY;
        if (currency == null) currency = "INR";
        if (taxInclusive == null) taxInclusive = false;
        if (gstRatePct == null) gstRatePct = new BigDecimal("18.00");
        if (limitsSnapshot == null || limitsSnapshot.isBlank()) limitsSnapshot = "{}";
        if (entitlementsSnapshot == null || entitlementsSnapshot.isBlank()) entitlementsSnapshot = "{}";
        if (periodStart == null) periodStart = LocalDateTime.now();
        if (autoRenew == null) autoRenew = true;
        if (changeReason == null) changeReason = SubscriptionChangeReason.NEW;
        if (discountAmount == null) discountAmount = BigDecimal.ZERO;
        if (isCurrent == null) isCurrent = true;
    }
}
