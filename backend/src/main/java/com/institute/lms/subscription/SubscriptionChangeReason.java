package com.institute.lms.subscription;

/** Why a new subscription term was created. Makes the instance chain auditable. */
public enum SubscriptionChangeReason {

    /** First subscription for this organization. */
    NEW("New subscription"),

    UPGRADE("Upgrade"),
    DOWNGRADE("Downgrade"),

    /** Same plan, new term. */
    RENEWAL("Renewal"),

    /** Restarted after expiry, suspension or cancellation. */
    REACTIVATION("Reactivation"),

    /** An assisted pilot converted to a paid plan, carrying its data forward. */
    PILOT_CONVERSION("Pilot conversion"),

    /** Same commercial terms, moved onto a different catalog plan row. */
    PLAN_MIGRATION("Plan migration"),

    /** Manual correction by the platform team; always paired with a note. */
    ADMIN_ADJUSTMENT("Administrative adjustment"),

    /** Only the billing cycle changed, e.g. monthly to annual. */
    CYCLE_CHANGE("Billing cycle change");

    private final String label;

    SubscriptionChangeReason(String label) {
        this.label = label;
    }

    public String getLabel() {
        return label;
    }

    public static SubscriptionChangeReason fromName(String raw) {
        if (raw == null) {
            return NEW;
        }
        for (SubscriptionChangeReason r : values()) {
            if (r.name().equalsIgnoreCase(raw.trim())) {
                return r;
            }
        }
        return ADMIN_ADJUSTMENT;
    }
}
