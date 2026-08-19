package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/** A record that a coupon was used, so per-organization limits can be enforced. */
@Entity
@Table(name = "org_coupon_redemptions")
@Data
@NoArgsConstructor
public class OrgCouponRedemption {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "coupon_id", nullable = false)
    private Long couponId;

    /** Denormalised so history survives the coupon being deleted. */
    @Column(name = "coupon_code", nullable = false, length = 60)
    private String couponCode;

    @Column(name = "organization_id", nullable = false)
    private Long organizationId;

    @Column(name = "subscription_instance_id")
    private Long subscriptionInstanceId;

    @Column(name = "invoice_id")
    private Long invoiceId;

    @Column(name = "discount_applied", nullable = false)
    private BigDecimal discountApplied = BigDecimal.ZERO;

    @Column(name = "redeemed_at", nullable = false)
    private LocalDateTime redeemedAt = LocalDateTime.now();

    @Column(name = "redeemed_by")
    private String redeemedBy;

    @PrePersist
    public void prePersist() {
        if (redeemedAt == null) redeemedAt = LocalDateTime.now();
        if (discountApplied == null) discountApplied = BigDecimal.ZERO;
    }
}
