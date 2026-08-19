package com.institute.lms.exception;

/**
 * A plan limit would be breached by this request — the tenant has used every
 * student seat, faculty seat, branch slot or storage byte their plan allows.
 *
 * <p>Thrown only for <em>creation</em> actions an administrator initiates. A student
 * merely <em>becoming active</em> over the cap is never blocked with this exception:
 * denying a learner access mid-course is a support and reputation problem, so that
 * case is metered and billed as overage instead.
 *
 * <p>The details map is the contract the Account page relies on to render an upgrade
 * call-to-action rather than a bare message, so populate {@code upgradeToPlanCode}
 * or {@code addonCode} whenever a resolution path exists.
 */
public class QuotaExceededException extends ApiException {

    public QuotaExceededException(ErrorCode code, String message) {
        super(code, message);
    }

    /**
     * Builds the standard "you've used all N of your M seats" error.
     *
     * @param code         the limit-specific code, e.g. {@code QUOTA_FACULTY_ACCOUNTS_EXCEEDED}
     * @param limitKey     the machine name of the limit, e.g. {@code MAX_FACULTY_ACCOUNTS}
     * @param unitLabel    human plural noun, e.g. "faculty seats"
     * @param limit        the plan's allowance
     * @param current      how many are in use now
     * @param requested    how many this request would add
     * @param planName     display name of the current plan, e.g. "Platform"
     */
    public static QuotaExceededException of(ErrorCode code,
                                            String limitKey,
                                            String unitLabel,
                                            long limit,
                                            long current,
                                            long requested,
                                            String planName) {
        String message = requested > 1
                ? String.format("Adding %d more %s would exceed your %s plan limit of %d (%d already in use).",
                        requested, unitLabel, planName, limit, current)
                : String.format("You have used all %d %s included in your %s plan.",
                        limit, unitLabel, planName);

        QuotaExceededException ex = new QuotaExceededException(code, message);
        ex.detail("limitKey", limitKey)
          .detail("unitLabel", unitLabel)
          .detail("limit", limit)
          .detail("current", current)
          .detail("requested", requested)
          .detail("planName", planName);
        return ex;
    }

    /**
     * Appends the cheaper of the two resolution paths to the message and details, so
     * the UI can offer a concrete next step. Either argument may be null.
     *
     * @param upgradeToPlanCode plan code that raises this limit, or null if none does
     * @param upgradeToPlanName display name of that plan
     * @param upgradeToLimit    the limit on that plan
     * @param addonCode         add-on that raises this limit, or null
     * @param addonName         display name of that add-on
     */
    public QuotaExceededException withResolution(String upgradeToPlanCode,
                                                 String upgradeToPlanName,
                                                 Long upgradeToLimit,
                                                 String addonCode,
                                                 String addonName) {
        detail("upgradeToPlanCode", upgradeToPlanCode)
                .detail("upgradeToPlanName", upgradeToPlanName)
                .detail("upgradeToLimit", upgradeToLimit)
                .detail("addonCode", addonCode)
                .detail("addonName", addonName);
        return this;
    }
}
