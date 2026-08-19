package com.institute.lms.exception;

import org.springframework.http.HttpStatus;

/**
 * Machine-readable error codes returned in the {@code code} field of every
 * {@link ErrorResponse}. The admin portal switches on these to decide what UI to
 * render — most importantly, the {@code QUOTA_*} and {@code ENTITLEMENT_REQUIRED}
 * codes drive an "upgrade your plan" call-to-action instead of a generic alert.
 *
 * <p>Codes are part of the public API contract: rename one and the frontend stops
 * recognising the condition. Add new constants rather than repurposing existing ones.
 *
 * <p>Status choices worth noting:
 * <ul>
 *   <li>Quota breaches are {@code 409 CONFLICT} — the request conflicts with the
 *       tenant's current state (all seats used), and retrying unchanged will fail again.</li>
 *   <li>Missing entitlements and inactive subscriptions are {@code 402 PAYMENT_REQUIRED} —
 *       the block is commercial, and paying/upgrading clears it.</li>
 * </ul>
 */
public enum ErrorCode {

    // ---- Generic ---------------------------------------------------------
    VALIDATION_FAILED(HttpStatus.BAD_REQUEST),
    BAD_REQUEST(HttpStatus.BAD_REQUEST),
    RESOURCE_NOT_FOUND(HttpStatus.NOT_FOUND),
    DUPLICATE_RESOURCE(HttpStatus.CONFLICT),
    UNAUTHORIZED(HttpStatus.UNAUTHORIZED),
    FORBIDDEN(HttpStatus.FORBIDDEN),
    INTERNAL_ERROR(HttpStatus.INTERNAL_SERVER_ERROR),

    // ---- Quota / limits (409: conflicts with current tenant state) -------
    QUOTA_ACTIVE_STUDENTS_EXCEEDED(HttpStatus.CONFLICT),
    QUOTA_FACULTY_ACCOUNTS_EXCEEDED(HttpStatus.CONFLICT),
    QUOTA_BRANCHES_EXCEEDED(HttpStatus.CONFLICT),
    QUOTA_ORGANIZATIONS_EXCEEDED(HttpStatus.CONFLICT),
    QUOTA_STORAGE_EXCEEDED(HttpStatus.CONFLICT),
    QUOTA_TRAINING_HOURS_EXCEEDED(HttpStatus.CONFLICT),
    QUOTA_CREDITS_EXHAUSTED(HttpStatus.CONFLICT),

    // ---- Entitlements / subscription state (402: pay to unlock) ---------
    ENTITLEMENT_REQUIRED(HttpStatus.PAYMENT_REQUIRED),
    SUBSCRIPTION_MISSING(HttpStatus.PAYMENT_REQUIRED),
    SUBSCRIPTION_EXPIRED(HttpStatus.PAYMENT_REQUIRED),
    SUBSCRIPTION_SUSPENDED(HttpStatus.PAYMENT_REQUIRED),
    SUBSCRIPTION_READ_ONLY(HttpStatus.PAYMENT_REQUIRED),
    SUBSCRIPTION_CANCELLED(HttpStatus.PAYMENT_REQUIRED),

    // ---- Plan / add-on changes ------------------------------------------
    PLAN_NOT_FOUND(HttpStatus.NOT_FOUND),
    PLAN_IN_USE(HttpStatus.CONFLICT),
    PLAN_CHANGE_NOT_ALLOWED(HttpStatus.CONFLICT),
    PLAN_REQUIRES_QUOTE(HttpStatus.CONFLICT),
    DOWNGRADE_BLOCKED_BY_USAGE(HttpStatus.CONFLICT),
    ADDON_NOT_FOUND(HttpStatus.NOT_FOUND),
    ADDON_NOT_APPLICABLE(HttpStatus.CONFLICT),
    ADDON_REQUIRES_QUOTE(HttpStatus.CONFLICT),
    ADDON_QUANTITY_INVALID(HttpStatus.BAD_REQUEST),
    OVERAGE_CAP_REACHED(HttpStatus.CONFLICT),

    // ---- Billing --------------------------------------------------------
    PAYMENT_FAILED(HttpStatus.PAYMENT_REQUIRED),
    PAYMENT_GATEWAY_UNAVAILABLE(HttpStatus.SERVICE_UNAVAILABLE),
    INVOICE_NOT_FOUND(HttpStatus.NOT_FOUND),
    INVOICE_NOT_PAYABLE(HttpStatus.CONFLICT),
    INVOICE_ALREADY_PAID(HttpStatus.CONFLICT),
    CREDIT_NOTE_EXCEEDS_INVOICE(HttpStatus.BAD_REQUEST),
    COUPON_INVALID(HttpStatus.BAD_REQUEST),
    COUPON_EXPIRED(HttpStatus.BAD_REQUEST),
    COUPON_EXHAUSTED(HttpStatus.CONFLICT),
    COUPON_NOT_APPLICABLE(HttpStatus.CONFLICT),
    GSTIN_INVALID(HttpStatus.BAD_REQUEST),

    // ---- Pilot / training ----------------------------------------------
    PILOT_ALREADY_ACTIVE(HttpStatus.CONFLICT),
    PILOT_NOT_CONVERTIBLE(HttpStatus.CONFLICT),
    TRAINING_AGREEMENT_INCOMPLETE(HttpStatus.BAD_REQUEST),
    REVENUE_SHARE_NOT_VERIFIABLE(HttpStatus.CONFLICT);

    private final HttpStatus status;

    ErrorCode(HttpStatus status) {
        this.status = status;
    }

    public HttpStatus getStatus() {
        return status;
    }
}
