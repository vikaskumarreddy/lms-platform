package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;

/**
 * A promotional discount code.
 *
 * <p>{@link #maxDiscountAmount} exists because an uncapped percentage is dangerous on a
 * platform whose plans span ₹4,999 to ₹5,00,000: a "50% off" code intended for a
 * Platform trial would take ₹2,50,000 off a Managed Academy annual contract.
 *
 * <p>{@link #firstPeriodOnly} defaults to true, so a discount is an acquisition
 * incentive rather than a permanent reprice that quietly follows the customer through
 * every renewal.
 */
@Entity
@Table(name = "org_coupons")
@Data
@NoArgsConstructor
public class OrgCoupon {

    public static final String TYPE_PERCENT = "PERCENT";
    public static final String TYPE_AMOUNT = "AMOUNT";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 60)
    private String code;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "discount_type", nullable = false, length = 10)
    private String discountType = TYPE_PERCENT;

    /** A percentage when {@link #discountType} is PERCENT, otherwise an absolute amount. */
    @Column(nullable = false)
    private BigDecimal value;

    /** Ceiling on a percentage discount. Null means uncapped. */
    @Column(name = "max_discount_amount")
    private BigDecimal maxDiscountAmount;

    @Column(nullable = false, length = 3)
    private String currency = "INR";

    /** JSON array of plan codes; null or empty means any plan. */
    @Column(name = "applies_to_plan_codes", columnDefinition = "TEXT")
    private String appliesToPlanCodes;

    @Column(name = "first_period_only", nullable = false)
    private Boolean firstPeriodOnly = true;

    @Column(name = "max_redemptions")
    private Integer maxRedemptions;

    @Column(name = "redemptions_used", nullable = false)
    private Integer redemptionsUsed = 0;

    @Column(name = "max_per_organization", nullable = false)
    private Integer maxPerOrganization = 1;

    @Column(name = "valid_from")
    private LocalDateTime validFrom;

    @Column(name = "valid_to")
    private LocalDateTime validTo;

    @Column(name = "is_active", nullable = false)
    private Boolean isActive = true;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @Column(name = "created_by")
    private String createdBy;

    /** Whether the coupon is live right now, ignoring per-organization limits. */
    @Transient
    public boolean isRedeemableNow() {
        if (!Boolean.TRUE.equals(isActive)) {
            return false;
        }
        LocalDateTime now = LocalDateTime.now();
        if (validFrom != null && validFrom.isAfter(now)) {
            return false;
        }
        if (validTo != null && validTo.isBefore(now)) {
            return false;
        }
        return maxRedemptions == null || redemptionsUsed < maxRedemptions;
    }

    /** The discount this coupon yields on an amount, honouring the cap. */
    @Transient
    public BigDecimal discountOn(BigDecimal amount) {
        if (amount == null || amount.signum() <= 0 || value == null) {
            return BigDecimal.ZERO;
        }
        BigDecimal discount = TYPE_AMOUNT.equals(discountType)
                ? value
                : amount.multiply(value).divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);

        if (maxDiscountAmount != null && discount.compareTo(maxDiscountAmount) > 0) {
            discount = maxDiscountAmount;
        }
        // A discount can never exceed the amount itself, which would turn an invoice
        // into a credit by arithmetic accident.
        return discount.compareTo(amount) > 0 ? amount : discount;
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
        if (code != null) code = code.trim().toUpperCase();
        if (discountType == null) discountType = TYPE_PERCENT;
        if (currency == null) currency = "INR";
        if (firstPeriodOnly == null) firstPeriodOnly = true;
        if (redemptionsUsed == null) redemptionsUsed = 0;
        if (maxPerOrganization == null) maxPerOrganization = 1;
        if (isActive == null) isActive = true;
    }
}
