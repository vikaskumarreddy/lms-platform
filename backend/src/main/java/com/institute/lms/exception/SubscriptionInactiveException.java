package com.institute.lms.exception;

import java.time.LocalDateTime;

/**
 * The tenant's subscription is not in a state that permits this request — it has
 * expired, been suspended, cancelled, or dropped to read-only after its grace period.
 *
 * <p>This replaces the previous behaviour where an inactive organization simply got
 * no tenant context, which made Hibernate's tenant discriminator match nothing and
 * left the administrator staring at an empty, apparently-broken portal with no
 * explanation. The endpoints needed to <em>recover</em> from this state (login,
 * reading the current organization, and the whole Account/billing surface) are
 * whitelisted, so the admin can always see the message and settle the invoice.
 */
public class SubscriptionInactiveException extends ApiException {

    public SubscriptionInactiveException(ErrorCode code, String message) {
        super(code, message);
    }

    /** No subscription has ever been assigned to this organization. */
    public static SubscriptionInactiveException missing(String orgName) {
        SubscriptionInactiveException ex = new SubscriptionInactiveException(
                ErrorCode.SUBSCRIPTION_MISSING,
                "No subscription plan is assigned to " + orgName + ". Contact your account manager to activate one.");
        ex.detail("organizationName", orgName);
        return ex;
    }

    /** The term ended and the grace period has elapsed. */
    public static SubscriptionInactiveException expired(String planName, LocalDateTime expiredOn) {
        SubscriptionInactiveException ex = new SubscriptionInactiveException(
                ErrorCode.SUBSCRIPTION_EXPIRED,
                "Your " + planName + " subscription expired. Renew it to restore full access.");
        ex.detail("planName", planName).detail("expiredOn", expiredOn);
        return ex;
    }

    /**
     * The term ended but data remains readable — writes are blocked, reads are not.
     * Used to reject non-GET requests while leaving the portal browsable.
     */
    public static SubscriptionInactiveException readOnly(String planName, LocalDateTime expiredOn) {
        SubscriptionInactiveException ex = new SubscriptionInactiveException(
                ErrorCode.SUBSCRIPTION_READ_ONLY,
                "Your " + planName + " subscription has expired, so the portal is read-only. "
                        + "Your data is safe — renew to resume making changes.");
        ex.detail("planName", planName).detail("expiredOn", expiredOn).detail("readOnly", true);
        return ex;
    }

    /** Suspended by the platform, typically for non-payment after dunning. */
    public static SubscriptionInactiveException suspended(String reason) {
        SubscriptionInactiveException ex = new SubscriptionInactiveException(
                ErrorCode.SUBSCRIPTION_SUSPENDED,
                "This organization has been suspended. Contact your account manager to restore access.");
        ex.detail("reason", reason);
        return ex;
    }

    public static SubscriptionInactiveException cancelled(String planName) {
        SubscriptionInactiveException ex = new SubscriptionInactiveException(
                ErrorCode.SUBSCRIPTION_CANCELLED,
                "Your " + planName + " subscription was cancelled. Reactivate it to continue.");
        ex.detail("planName", planName);
        return ex;
    }
}
