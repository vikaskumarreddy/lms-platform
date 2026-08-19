package com.institute.lms.exception;

/**
 * A requested plan change cannot be applied.
 *
 * <p>The common cases are a downgrade the tenant's current usage does not fit into
 * (moving 400 students onto a 200-seat plan), a custom-priced plan that has to go
 * through sales, or a self-serve upgrade attempt while self-serve is disabled —
 * which is the default, because without a live payment gateway an instant upgrade
 * would grant entitlements for money that has not been collected.
 */
public class PlanChangeNotAllowedException extends ApiException {

    public PlanChangeNotAllowedException(ErrorCode code, String message) {
        super(code, message);
    }

    /**
     * The target plan's limit is below what the tenant is currently using. Names the
     * offending resource so the admin knows what to reduce first.
     */
    public static PlanChangeNotAllowedException downgradeBlocked(String targetPlanName,
                                                                 String unitLabel,
                                                                 long current,
                                                                 long targetLimit) {
        PlanChangeNotAllowedException ex = new PlanChangeNotAllowedException(
                ErrorCode.DOWNGRADE_BLOCKED_BY_USAGE,
                String.format("Cannot move to %s: you have %d %s but that plan allows %d. "
                                + "Reduce usage first, or ask us about a custom limit.",
                        targetPlanName, current, unitLabel, targetLimit));
        ex.detail("targetPlanName", targetPlanName)
          .detail("unitLabel", unitLabel)
          .detail("current", current)
          .detail("targetLimit", targetLimit);
        return ex;
    }

    /** The target plan is custom-priced (Enterprise) and must be quoted by sales. */
    public static PlanChangeNotAllowedException requiresQuote(String targetPlanName) {
        PlanChangeNotAllowedException ex = new PlanChangeNotAllowedException(
                ErrorCode.PLAN_REQUIRES_QUOTE,
                targetPlanName + " is priced per organization. We'll prepare a quotation for you.");
        ex.detail("targetPlanName", targetPlanName).detail("requiresQuote", true);
        return ex;
    }

    /**
     * Self-serve plan changes are disabled, so the request becomes an upgrade request
     * for the platform team to approve.
     */
    public static PlanChangeNotAllowedException requiresApproval(String targetPlanName) {
        PlanChangeNotAllowedException ex = new PlanChangeNotAllowedException(
                ErrorCode.PLAN_CHANGE_NOT_ALLOWED,
                "Your request to move to " + targetPlanName + " has to be confirmed by our team. "
                        + "We'll contact you to arrange billing.");
        ex.detail("targetPlanName", targetPlanName).detail("requiresApproval", true);
        return ex;
    }

    public static PlanChangeNotAllowedException samePlan(String planName) {
        return new PlanChangeNotAllowedException(ErrorCode.PLAN_CHANGE_NOT_ALLOWED,
                planName + " is already your current plan.");
    }
}
