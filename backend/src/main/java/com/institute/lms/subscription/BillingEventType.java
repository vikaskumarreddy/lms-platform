package com.institute.lms.subscription;

/**
 * Auditable billing actions appended to {@code org_billing_events}.
 *
 * <p>That table is append-only by convention: billing disputes are argued from it,
 * so nothing here should ever be updated or deleted after the fact.
 */
public enum BillingEventType {

    SUBSCRIBED,
    UPGRADED,
    DOWNGRADED,
    RENEWED,
    CYCLE_CHANGED,
    CANCELLED,
    REACTIVATED,

    TRIAL_STARTED,
    TRIAL_ENDED,

    GRACE_STARTED,
    EXPIRED,
    READ_ONLY,
    SUSPENDED,
    RESUMED,

    ADDON_REQUESTED,
    ADDON_ADDED,
    ADDON_REMOVED,

    LIMITS_OVERRIDDEN,
    PLAN_CHANGE_REQUESTED,
    PLAN_CHANGE_APPROVED,
    PLAN_CHANGE_REJECTED,

    /** Recorded when usage passes a plan allowance that is metered rather than blocked. */
    OVERAGE_RECORDED,

    INVOICE_ISSUED,
    INVOICE_VOIDED,
    PAYMENT_RECORDED,
    CREDIT_NOTE_ISSUED,
    DUNNING_SENT,
    COUPON_APPLIED,

    PILOT_STARTED,
    PILOT_CONVERTED,
    PILOT_LAPSED
}
