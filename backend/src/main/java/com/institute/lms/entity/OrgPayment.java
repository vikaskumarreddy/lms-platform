package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * Money received against an invoice.
 *
 * <p>Recorded by the platform team, because there is no payment gateway: bank
 * transfers, UPI, cheques and purchase orders are how this platform actually gets
 * paid today. {@link #gatewayPaymentId} exists so a gateway can later post rows here
 * without any of the surrounding billing logic changing.
 *
 * <p>Note this replaces the {@code Payment} entity that was only ever an empty file —
 * there was no working payment persistence before this.
 */
@Entity
@Table(name = "org_payments")
@Data
@NoArgsConstructor
public class OrgPayment {

    public static final String METHOD_BANK_TRANSFER = "BANK_TRANSFER";
    public static final String METHOD_UPI = "UPI";
    public static final String METHOD_CHEQUE = "CHEQUE";
    public static final String METHOD_CASH = "CASH";
    public static final String METHOD_CARD = "CARD";
    public static final String METHOD_GATEWAY = "GATEWAY";
    /** A book entry rather than money moving — used when applying a credit note. */
    public static final String METHOD_ADJUSTMENT = "ADJUSTMENT";

    public static final String STATUS_RECORDED = "RECORDED";
    public static final String STATUS_CLEARED = "CLEARED";
    public static final String STATUS_BOUNCED = "BOUNCED";
    public static final String STATUS_REFUNDED = "REFUNDED";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "organization_id", nullable = false)
    private Long organizationId;

    @Column(name = "invoice_id")
    private Long invoiceId;

    @Column(nullable = false)
    private BigDecimal amount;

    @Column(nullable = false, length = 3)
    private String currency = "INR";

    @Column(nullable = false, length = 20)
    private String method = METHOD_BANK_TRANSFER;

    /**
     * A cheque is recorded when received but only counts once it clears, so the
     * status matters: only CLEARED payments reduce an invoice's balance.
     */
    @Column(nullable = false, length = 20)
    private String status = STATUS_CLEARED;

    /** UTR, cheque number or receipt reference. */
    @Column(length = 160)
    private String reference;

    @Column(name = "gateway_payment_id", length = 120)
    private String gatewayPaymentId;

    @Column(name = "paid_at", nullable = false)
    private LocalDateTime paidAt = LocalDateTime.now();

    @Column(name = "recorded_by")
    private String recordedBy;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    /** True when this payment should count against an invoice balance. */
    @Transient
    public boolean countsTowardsBalance() {
        return STATUS_CLEARED.equals(status) || STATUS_RECORDED.equals(status);
    }

    @PrePersist
    public void prePersist() {
        if (createdAt == null) createdAt = LocalDateTime.now();
        if (paidAt == null) paidAt = LocalDateTime.now();
        if (currency == null) currency = "INR";
        if (method == null) method = METHOD_BANK_TRANSFER;
        if (status == null) status = STATUS_CLEARED;
    }
}
