package com.institute.lms.entity;

import com.institute.lms.subscription.CreditType;
import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serializable;
import java.time.LocalDateTime;
import java.util.Objects;

/**
 * A tenant's running balance of one prepaid credit pool (SMS, WhatsApp, email).
 *
 * <p>The balance is a cache over {@link OrgCreditTxn}, which is the authoritative
 * record. Keeping both means "you said we had 5,000 credits" can be answered from the
 * ledger, and a balance that has drifted can be recomputed rather than argued about.
 *
 * <p>Keyed by {@code (organization_id, credit_type)} so a tenant has exactly one
 * balance row per pool.
 */
@Entity
@Table(name = "org_credit_balance")
@IdClass(OrgCreditBalance.Key.class)
@Data
@NoArgsConstructor
public class OrgCreditBalance {

    @Id
    @Column(name = "organization_id", nullable = false)
    private Long organizationId;

    @Id
    @Enumerated(EnumType.STRING)
    @Column(name = "credit_type", nullable = false, length = 20)
    private CreditType creditType;

    @Column(nullable = false)
    private Long balance = 0L;

    @Column(name = "lifetime_granted", nullable = false)
    private Long lifetimeGranted = 0L;

    @Column(name = "lifetime_used", nullable = false)
    private Long lifetimeUsed = 0L;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt = LocalDateTime.now();

    @PrePersist
    @PreUpdate
    public void touch() {
        updatedAt = LocalDateTime.now();
        if (balance == null) balance = 0L;
        if (lifetimeGranted == null) lifetimeGranted = 0L;
        if (lifetimeUsed == null) lifetimeUsed = 0L;
    }

    /** Composite primary key. */
    @Data
    @NoArgsConstructor
    public static class Key implements Serializable {
        private Long organizationId;
        private CreditType creditType;

        public Key(Long organizationId, CreditType creditType) {
            this.organizationId = organizationId;
            this.creditType = creditType;
        }

        @Override
        public boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof Key key)) return false;
            return Objects.equals(organizationId, key.organizationId) && creditType == key.creditType;
        }

        @Override
        public int hashCode() {
            return Objects.hash(organizationId, creditType);
        }
    }
}
