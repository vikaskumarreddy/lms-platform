package com.institute.lms.entity;

import com.institute.lms.subscription.AddonPricingModel;
import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * An add-on a tenant has actually bought (or requested), as opposed to
 * {@link PlanAddon}, which is the catalog definition.
 *
 * <p>The catalog fields are copied onto this row at purchase — code, name, unit price,
 * pricing model, and crucially {@link #incrementsLimitKey} /
 * {@link #grantsEntitlementKey}. Freezing those two is what stops a later catalog edit
 * from changing what an existing customer receives: if someone repoints the
 * "additional students" definition at a different limit, everyone who already paid for
 * seats must keep getting seats.
 *
 * <p>{@link #status} matters for enforcement. Only {@code ACTIVE} rows contribute to
 * effective limits, so a request raised from the Account page grants nothing until the
 * platform team approves it — necessary because there is no gateway collecting the
 * money at the moment of request.
 */
@Entity
@Table(name = "org_subscription_addons")
@Data
@NoArgsConstructor
public class OrgSubscriptionAddon {

    /** Only ACTIVE contributes to effective limits and entitlements. */
    public static final String STATUS_ACTIVE = "ACTIVE";
    public static final String STATUS_CANCELLED = "CANCELLED";
    /** Requested by a tenant admin, awaiting platform approval. Grants nothing yet. */
    public static final String STATUS_PENDING_APPROVAL = "PENDING_APPROVAL";
    /** Requested, but the add-on is quoted so sales must price it first. */
    public static final String STATUS_PENDING_QUOTE = "PENDING_QUOTE";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "organization_id", nullable = false)
    private Long organizationId;

    /** The term this add-on belongs to. Recurring add-ons are carried onto renewals. */
    @Column(name = "subscription_instance_id")
    private Long subscriptionInstanceId;

    @Column(name = "addon_id")
    private Long addonId;

    @Column(name = "addon_code", nullable = false, length = 60)
    private String addonCode;

    @Column(name = "addon_name", length = 160)
    private String addonName;

    @Column(nullable = false)
    private Integer qty = 1;

    /** Frozen agreed unit price, within the catalog's price band at time of sale. */
    @Column(name = "unit_price")
    private BigDecimal unitPrice;

    @Column(name = "unit_label", length = 60)
    private String unitLabel;

    @Enumerated(EnumType.STRING)
    @Column(name = "pricing_model", nullable = false, length = 20)
    private AddonPricingModel pricingModel = AddonPricingModel.FLAT_ONCE;

    /** Frozen: name of the {@code LimitKey} this purchase raises, or null. */
    @Column(name = "increments_limit_key", length = 60)
    private String incrementsLimitKey;

    /** Frozen: name of the {@code Entitlement} this purchase grants, or null. */
    @Column(name = "grants_entitlement_key", length = 60)
    private String grantsEntitlementKey;

    /** MONTHLY | YEARLY | ONE_TIME */
    @Column(name = "billing_period", nullable = false, length = 10)
    private String billingPeriod = "MONTHLY";

    @Column(nullable = false, length = 20)
    private String status = STATUS_ACTIVE;

    @Column(name = "effective_from", nullable = false)
    private LocalDateTime effectiveFrom = LocalDateTime.now();

    @Column(name = "effective_to")
    private LocalDateTime effectiveTo;

    @Column(name = "hsn_sac_code", length = 10)
    private String hsnSacCode;

    @Column(name = "gst_rate_pct", nullable = false)
    private BigDecimal gstRatePct = new BigDecimal("18.00");

    @Column(name = "requested_by")
    private String requestedBy;

    @Column(name = "approved_by")
    private String approvedBy;

    @Column(name = "approved_at")
    private LocalDateTime approvedAt;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    /**
     * True when this add-on should count towards effective limits right now: approved,
     * started, and not yet ended.
     */
    @Transient
    public boolean isEffectiveNow() {
        if (!STATUS_ACTIVE.equalsIgnoreCase(status)) {
            return false;
        }
        LocalDateTime now = LocalDateTime.now();
        if (effectiveFrom != null && effectiveFrom.isAfter(now)) {
            return false;
        }
        return effectiveTo == null || effectiveTo.isAfter(now);
    }

    @Transient
    public boolean isAwaitingDecision() {
        return STATUS_PENDING_APPROVAL.equalsIgnoreCase(status)
                || STATUS_PENDING_QUOTE.equalsIgnoreCase(status);
    }

    /** Line total before tax. */
    @Transient
    public BigDecimal getLineTotal() {
        if (unitPrice == null) {
            return BigDecimal.ZERO;
        }
        int quantity = pricingModel != null && pricingModel.isQuantified() && qty != null ? qty : 1;
        return unitPrice.multiply(BigDecimal.valueOf(quantity));
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
        if (qty == null || qty < 1) qty = 1;
        if (pricingModel == null) pricingModel = AddonPricingModel.FLAT_ONCE;
        if (billingPeriod == null) billingPeriod = "MONTHLY";
        if (status == null || status.isBlank()) status = STATUS_ACTIVE;
        if (effectiveFrom == null) effectiveFrom = LocalDateTime.now();
        if (gstRatePct == null) gstRatePct = new BigDecimal("18.00");
    }
}
