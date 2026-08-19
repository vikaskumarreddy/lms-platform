package com.institute.lms.subscription;

/**
 * Lifecycle state of a tenant's subscription term.
 *
 * <p>The important thing each state carries is its {@link AccessLevel}, which
 * collapses nine states into the three answers enforcement actually needs: can this
 * tenant write, only read, or nothing at all.
 *
 * <p>The intended progression after a term ends is
 * {@code ACTIVE -> GRACE -> EXPIRED -> SUSPENDED}:
 * <ul>
 *   <li>{@code GRACE} keeps the academy fully working for the plan's grace days,
 *       because cutting off a live class the day an invoice slips is
 *       disproportionate and generates support load rather than payment.</li>
 *   <li>{@code EXPIRED} drops to read-only. The tenant can still see their students,
 *       courses and reports — nothing is deleted — but cannot change anything.</li>
 *   <li>{@code SUSPENDED} is a deliberate platform action, normally the end of
 *       dunning, and is the only non-cancelled state that blocks reads.</li>
 * </ul>
 */
public enum SubscriptionStatus {

    /** Free trial in progress. Full access. */
    TRIALING("Trial", AccessLevel.FULL),

    /** Paid assisted pilot in progress. Full access within the pilot's limits. */
    PILOT("Pilot", AccessLevel.FULL),

    /** Paid and current. */
    ACTIVE("Active", AccessLevel.FULL),

    /**
     * An invoice is overdue and dunning is running, but the term has not ended.
     * Access stays full: chasing payment should not break a running academy.
     */
    PAST_DUE("Payment overdue", AccessLevel.FULL),

    /**
     * The term ended and renewal has not been recorded yet. Still fully usable for
     * the plan's grace days.
     */
    GRACE("In grace period", AccessLevel.FULL),

    /** Grace elapsed. Data is intact and readable, but writes are refused. */
    EXPIRED("Expired", AccessLevel.READ_ONLY),

    /**
     * Explicit read-only hold. Behaves identically to {@link #EXPIRED} and exists so
     * the platform can park a tenant read-only for a reason other than expiry.
     */
    READ_ONLY("Read-only", AccessLevel.READ_ONLY),

    /** Suspended by the platform, normally at the end of dunning. No access. */
    SUSPENDED("Suspended", AccessLevel.NONE),

    /** Terminated, whether by the customer or by us. No access. */
    CANCELLED("Cancelled", AccessLevel.NONE);

    public enum AccessLevel {
        /** Reads and writes permitted. */
        FULL,
        /** Reads permitted, writes refused with a 402 naming the renewal path. */
        READ_ONLY,
        /** No tenant access beyond login and the Account/billing surface. */
        NONE
    }

    private final String label;
    private final AccessLevel accessLevel;

    SubscriptionStatus(String label, AccessLevel accessLevel) {
        this.label = label;
        this.accessLevel = accessLevel;
    }

    public String getLabel() {
        return label;
    }

    public AccessLevel getAccessLevel() {
        return accessLevel;
    }

    public boolean allowsWrites() {
        return accessLevel == AccessLevel.FULL;
    }

    public boolean allowsReads() {
        return accessLevel != AccessLevel.NONE;
    }

    /** True while the tenant is paying or is expected to. Drives active-tenant counts. */
    public boolean isLive() {
        return this == ACTIVE || this == TRIALING || this == PILOT
                || this == PAST_DUE || this == GRACE;
    }

    /** True when the state warrants a banner in the portal explaining what to do. */
    public boolean needsAttention() {
        return this != ACTIVE && this != TRIALING;
    }

    public static SubscriptionStatus fromName(String raw) {
        if (raw == null) {
            return null;
        }
        for (SubscriptionStatus s : values()) {
            if (s.name().equalsIgnoreCase(raw.trim())) {
                return s;
            }
        }
        return null;
    }
}
