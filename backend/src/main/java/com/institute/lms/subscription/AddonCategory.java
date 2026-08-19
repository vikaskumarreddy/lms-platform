package com.institute.lms.subscription;

/** Grouping used to lay out the add-on catalog in the UI. */
public enum AddonCategory {

    /** Raises a countable plan allowance — seats, branches, storage. */
    CAPACITY("Capacity"),

    /** Prepaid SMS, WhatsApp and email credit packs. */
    COMMUNICATION("Communication"),

    /** One-off or quoted work we deliver: reports, migration, content, websites, apps. */
    SERVICES("Services"),

    /** Technical capabilities: API access, video bandwidth, gateway pass-through, SSO. */
    INFRA("Platform and infrastructure"),

    /** Support tier upgrades. */
    SUPPORT("Support"),

    /**
     * Trainer-delivered work. Kept separate from SERVICES because it carries a
     * different SAC code (999293 rather than 998314) and always needs a signed
     * scope — subjects, batches, class sizes, sessions, faculty hours and the
     * replacement policy — before it can be delivered or billed.
     */
    TRAINING("Training and faculty");

    private final String label;

    AddonCategory(String label) {
        this.label = label;
    }

    public String getLabel() {
        return label;
    }
}
