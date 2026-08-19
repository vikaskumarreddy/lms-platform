package com.institute.lms.exception;

/**
 * The tenant's plan does not include the feature being used — a custom domain,
 * advanced analytics, API access, and so on.
 *
 * <p>Maps to {@code 402 PAYMENT_REQUIRED}: the block is commercial rather than a
 * permission problem, and upgrading or buying the relevant add-on clears it. Using
 * 403 here would be misleading, since the caller's role is not the issue.
 */
public class EntitlementRequiredException extends ApiException {

    public EntitlementRequiredException(String message) {
        super(ErrorCode.ENTITLEMENT_REQUIRED, message);
    }

    /**
     * @param featureKey  machine name, e.g. {@code CUSTOM_DOMAIN}
     * @param featureName human name, e.g. "Custom domain"
     * @param planName    the tenant's current plan
     */
    public static EntitlementRequiredException of(String featureKey, String featureName, String planName) {
        EntitlementRequiredException ex = new EntitlementRequiredException(
                featureName + " is not included in your " + planName + " plan.");
        ex.detail("featureKey", featureKey)
          .detail("featureName", featureName)
          .detail("planName", planName);
        return ex;
    }

    /**
     * Names the cheapest plan that includes the feature, or the add-on that grants it.
     * Either argument may be null when the feature is sales-qualified only (for example
     * SSO or dedicated infrastructure, which cannot be self-provisioned).
     */
    public EntitlementRequiredException withResolution(String requiredPlanCode,
                                                       String requiredPlanName,
                                                       String addonCode,
                                                       String addonName,
                                                       boolean requiresQuote) {
        detail("requiredPlanCode", requiredPlanCode)
                .detail("requiredPlanName", requiredPlanName)
                .detail("addonCode", addonCode)
                .detail("addonName", addonName)
                .detail("requiresQuote", requiresQuote);
        return this;
    }
}
