package com.institute.lms.service.subscription;

import com.institute.lms.repository.StudentActivityPeriodRepository;
import com.institute.lms.subscription.ActivityType;
import com.institute.lms.util.OrganizationContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Records that a student was active, which is what the billable active-student count is
 * derived from.
 *
 * <p>Two properties matter more than anything else here:
 *
 * <p><strong>It never blocks and never fails the caller.</strong> Every method swallows
 * its own exceptions. This is called from the login path and from content, attendance,
 * submission and placement handlers — if the meter throws, a student cannot sign in or
 * submit an exam. A missed metering row costs us a fraction of a rupee; a failed login
 * during an exam costs the customer relationship. The trade is not close.
 *
 * <p><strong>It is idempotent per student per month.</strong> The write is a single
 * {@code INSERT ... ON CONFLICT} upsert against a unique index, not a read-then-write,
 * so simultaneous requests from the same student cannot both insert. Without that, a
 * burst of concurrent logins would create duplicate billable rows and inflate an
 * invoice the customer would be right to dispute.
 *
 * <p>Runs in its own transaction ({@code REQUIRES_NEW}) so a metering failure cannot
 * mark the caller's transaction for rollback — otherwise a broken meter would roll back
 * the very login or submission it was only observing.
 */
@Service
public class ActivityMeterService {

    private static final Logger log = LoggerFactory.getLogger(ActivityMeterService.class);

    private final StudentActivityPeriodRepository activityRepository;
    private final EntitlementService entitlementService;
    private final QuotaGuard quotaGuard;
    private final OrganizationContext organizationContext;

    public ActivityMeterService(StudentActivityPeriodRepository activityRepository,
                                EntitlementService entitlementService,
                                QuotaGuard quotaGuard,
                                OrganizationContext organizationContext) {
        this.activityRepository = activityRepository;
        this.entitlementService = entitlementService;
        this.quotaGuard = quotaGuard;
        this.organizationContext = organizationContext;
    }

    /**
     * Records activity for a student in the current tenant.
     *
     * <p>Annotated in its own right rather than relying on the two-argument overload's
     * annotation: a call from inside this class goes straight to the target and never
     * touches the proxy, so the transaction would not start and the {@code @Modifying}
     * upsert would fail with "Executing an update/delete query". Every public entry
     * point therefore carries the annotation itself.
     *
     * @param studentId the student; ignored when null
     * @param type      what they did
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void record(Long studentId, ActivityType type) {
        record(organizationContext.getCurrentOrgId(), studentId, type);
    }

    /**
     * Records activity for a student in a named organization. Used from the
     * authentication path, where the tenant context is resolved from the account rather
     * than the request.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void record(Long organizationId, Long studentId, ActivityType type) {
        if (organizationId == null || studentId == null || type == null) {
            return;
        }
        try {
            String period = UsageService.currentPeriod();

            // Whether this student is beyond the allowance is recorded on the row at the
            // time, because the allowance in force now is what any overage charge rests
            // on and the tenant may change plan before the month closes. Note this only
            // FLAGS the row — activity is never refused for being over the cap.
            boolean overage = false;
            try {
                ResolvedEntitlements resolved = entitlementService.resolve(organizationId);
                overage = quotaGuard.recordOverageIfNeeded(organizationId, resolved);
            } catch (Exception e) {
                // An entitlement lookup problem must not lose the activity record —
                // an unflagged row is recoverable, a missing one is not.
                log.warn("Could not evaluate overage for organization {}; recording activity unflagged.",
                        organizationId, e);
            }

            activityRepository.recordActivity(organizationId, studentId, period, type.name(), overage);
        } catch (Exception e) {
            // Deliberately swallowed. See the class comment: metering must never be able
            // to break a login, a submission or a class join.
            log.error("Failed to record {} activity for student {} in organization {}",
                    type, studentId, organizationId, e);
        }
    }

    // Each convenience method carries its own @Transactional for the self-invocation
    // reason above — without it, calling recordLogin() from AuthService would enter an
    // untransacted context and silently lose every login.

    /** Convenience for the login path. */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordLogin(Long organizationId, Long studentId) {
        record(organizationId, studentId, ActivityType.LOGIN);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordContentAccess(Long studentId) {
        record(studentId, ActivityType.CONTENT_ACCESS);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordClassAttendance(Long studentId) {
        record(studentId, ActivityType.CLASS_ATTENDANCE);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordAssessmentSubmission(Long studentId) {
        record(studentId, ActivityType.ASSESSMENT_SUBMISSION);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordPlacementApplication(Long studentId) {
        record(studentId, ActivityType.PLACEMENT_APPLICATION);
    }
}
