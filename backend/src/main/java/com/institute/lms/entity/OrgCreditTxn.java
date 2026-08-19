package com.institute.lms.entity;

import com.institute.lms.subscription.CreditType;
import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * An immutable movement in a prepaid credit pool. This is the authoritative record;
 * {@link OrgCreditBalance} is a cache derived from it.
 *
 * <p>Append-only: a correction is a new {@code ADJUSTMENT} row, never an edit. That is
 * what makes a disputed balance reconstructable.
 */
@Entity
@Table(name = "org_credit_txn")
@Data
@NoArgsConstructor
public class OrgCreditTxn {

    public static final String TYPE_PURCHASE = "PURCHASE";
    public static final String TYPE_CONSUMPTION = "CONSUMPTION";
    public static final String TYPE_ADJUSTMENT = "ADJUSTMENT";
    public static final String TYPE_EXPIRY = "EXPIRY";
    public static final String TYPE_REFUND = "REFUND";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "organization_id", nullable = false)
    private Long organizationId;

    @Enumerated(EnumType.STRING)
    @Column(name = "credit_type", nullable = false, length = 20)
    private CreditType creditType;

    @Column(name = "txn_type", nullable = false, length = 20)
    private String txnType;

    /** Positive to grant credits, negative to consume them. */
    @Column(nullable = false)
    private Long amount;

    /** The resulting balance, stored so the ledger can be read without re-summing. */
    @Column(name = "balance_after", nullable = false)
    private Long balanceAfter;

    @Column(length = 160)
    private String reference;

    @Column(name = "addon_code", length = 60)
    private String addonCode;

    @Column
    private String actor;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    @PrePersist
    public void prePersist() {
        if (createdAt == null) createdAt = LocalDateTime.now();
    }
}
