package com.institute.lms.subscription;

import java.time.LocalDateTime;

/** How often a subscription term renews, and how long one term lasts. */
public enum BillingCycle {

    MONTHLY("Monthly", 1),
    YEARLY("Annual", 12),

    /**
     * A negotiated term whose length comes from the agreement rather than the cycle.
     * Enterprise and Managed Academy contracts use this; callers must supply an
     * explicit period end.
     */
    CUSTOM("Custom term", 0),

    /** A single charge with no renewal — the assisted pilot. */
    ONE_TIME("One-time", 0);

    private final String label;
    private final int months;

    BillingCycle(String label, int months) {
        this.label = label;
        this.months = months;
    }

    public String getLabel() {
        return label;
    }

    /** Term length in months, or 0 when the term length is not implied by the cycle. */
    public int getMonths() {
        return months;
    }

    public boolean isRecurring() {
        return this == MONTHLY || this == YEARLY;
    }

    /**
     * Advances {@code from} by one term.
     *
     * <p>Returns null for {@link #CUSTOM} and {@link #ONE_TIME}, where the caller must
     * supply the end date explicitly — guessing a term length for a negotiated
     * contract would silently invent a renewal date nobody agreed to.
     */
    public LocalDateTime advance(LocalDateTime from) {
        if (from == null || months <= 0) {
            return null;
        }
        return from.plusMonths(months);
    }

    public static BillingCycle fromName(String raw) {
        if (raw == null) {
            return MONTHLY;
        }
        for (BillingCycle c : values()) {
            if (c.name().equalsIgnoreCase(raw.trim())) {
                return c;
            }
        }
        // The legacy plan catalog stores 'monthly' | 'yearly' | 'custom' | 'weekly'.
        String lower = raw.trim().toLowerCase();
        if (lower.startsWith("year") || lower.startsWith("annual")) {
            return YEARLY;
        }
        if (lower.startsWith("custom")) {
            return CUSTOM;
        }
        return MONTHLY;
    }
}
