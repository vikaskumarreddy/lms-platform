package com.institute.lms.subscription;

/**
 * How an add-on is priced and when it hits an invoice.
 *
 * <p>The distinction between recurring and one-off matters at renewal: recurring
 * add-ons are carried onto the next subscription instance automatically, while
 * one-off ones are not.
 */
public enum AddonPricingModel {

    /** Recurring: quantity x unit price, every billing period. Extra seats, storage. */
    PER_UNIT_MONTH("Per unit, monthly", true, true),

    /** One-off: quantity x unit price, charged once. Credit packs, training hours. */
    PER_UNIT_ONCE("Per unit, one-time", false, true),

    /** Recurring flat fee, quantity ignored. API access, premium support. */
    FLAT_MONTH("Flat monthly fee", true, false),

    /** One-off flat fee. A custom report, advanced migration. */
    FLAT_ONCE("Flat one-time fee", false, false),

    /**
     * Billed in arrears from measured usage. Payment-gateway charges are the only
     * current example, and cannot actually be invoiced until a gateway is
     * integrated and collections are measurable.
     */
    METERED("Metered in arrears", true, true),

    /**
     * No list price — sales raises a quotation. Used for work the platform cannot
     * self-provision, such as SSO, dedicated infrastructure, white-labelled apps
     * and revenue-share training.
     */
    QUOTED("Quoted", false, false);

    private final String label;
    private final boolean recurring;
    private final boolean quantified;

    AddonPricingModel(String label, boolean recurring, boolean quantified) {
        this.label = label;
        this.recurring = recurring;
        this.quantified = quantified;
    }

    public String getLabel() {
        return label;
    }

    /** True when the charge repeats each billing period and survives renewal. */
    public boolean isRecurring() {
        return recurring;
    }

    /** True when quantity affects the price. */
    public boolean isQuantified() {
        return quantified;
    }
}
