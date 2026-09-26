package com.institute.lms.service.subscription;

import com.institute.lms.entity.OrgSubscription;
import com.institute.lms.entity.PlanAddon;
import com.institute.lms.exception.EntitlementRequiredException;
import com.institute.lms.exception.QuotaExceededException;
import com.institute.lms.exception.SubscriptionInactiveException;
import com.institute.lms.service.OrgSubscriptionService;
import com.institute.lms.service.PlanAddonService;
import com.institute.lms.subscription.Entitlement;
import com.institute.lms.subscription.LimitKey;
import com.institute.lms.subscription.SubscriptionStatus;
import com.institute.lms.util.OrganizationContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

/**
 * The single place plan limits and feature flags are enforced.
 *
 * <p><strong>Seat creation is blocked; student activity is not.</strong> That asymmetry
 * is deliberate and is the most important decision in this class. Creating a student,
 * faculty seat or branch is an administrator's action, taken at a keyboard, and
 * refusing it with a clear message costs nothing but a moment. A student <em>becoming
 * active</em> is a learner opening an app, possibly mid-exam — blocking that to enforce
 * a commercial limit turns a billing question into a support incident and a reputational
 * one. So over-cap activity is metered and billed as overage instead
 * ({@link #recordOverageIfNeeded}), never refused.
 *
 * <p>Errors carry the limit, the current usage, and a concrete resolution — the plan
 * that raises the limit, or the add-on that does — so the UI can offer an upgrade
 * button rather than a dead end.
 */
@Service
public class QuotaGuard {

    private static final Logger log = LoggerFactory.getLogger(QuotaGuard.class);

    private final EntitlementService entitlementService;
    private final UsageService usageService;
    private final OrgSubscriptionService planService;
    private final PlanAddonService addonService;
    private final OrganizationContext organizationContext;
    private final com.institute.lms.repository.OrganizationRepository organizationRepository;

    public QuotaGuard(EntitlementService entitlementService,
                      UsageService usageService,
                      OrgSubscriptionService planService,
                      PlanAddonService addonService,
                      OrganizationContext organizationContext,
                      com.institute.lms.repository.OrganizationRepository organizationRepository) {
        this.entitlementService = entitlementService;
        this.usageService = usageService;
        this.planService = planService;
        this.addonService = addonService;
        this.organizationContext = organizationContext;
        this.organizationRepository = organizationRepository;
    }

    // =====================================================================
    // Seat and capacity guards — these DO block
    // =====================================================================

    /** Asserts the current tenant can add one more of {@code key}. */
    public void requireCapacity(LimitKey key) {
        requireCapacity(key, 1);
    }

    /** Asserts the current tenant can add {@code requested} more of {@code key}. */
    public void requireCapacity(LimitKey key, int requested) {
        Long orgId = organizationContext.getCurrentOrgId();
        if (orgId == null) {
            // No tenant context means a platform-level action, which no tenant plan
            // governs. Tenant-scoped writes cannot reach here in the first place: the
            // sentinel tenant makes them fail closed at the ORM layer.
            return;
        }
        requireCapacity(orgId, key, requested);
    }

    public void requireCapacity(Long organizationId, LimitKey key, int requested) {
        ResolvedEntitlements resolved = entitlementService.resolve(organizationId);
        requireCapacity(organizationId, key, requested, resolved);
    }

    /** Overload for callers that already resolved entitlements, avoiding a repeat query. */
    public void requireCapacity(Long organizationId, LimitKey key, int requested,
                               ResolvedEntitlements resolved) {
        if (!resolved.hasSubscription()) {
            throw SubscriptionInactiveException.missing(describeOrg(organizationId));
        }
        if (resolved.isUnlimited(key)) {
            return;
        }

        long limit = resolved.limit(key);
        long current = usageService.usageOf(key, organizationId);
        if (current + requested <= limit) {
            return;
        }

        throw buildQuotaError(key, limit, current, requested, resolved);
    }

    /**
     * Non-throwing capacity check, for UI affordances that should be disabled rather
     * than failing when clicked.
     */
    public boolean hasCapacity(Long organizationId, LimitKey key, int requested) {
        ResolvedEntitlements resolved = entitlementService.resolve(organizationId);
        if (!resolved.hasSubscription()) {
            return false;
        }
        if (resolved.isUnlimited(key)) {
            return true;
        }
        return usageService.usageOf(key, organizationId) + requested <= resolved.limit(key);
    }

    /**
     * Guards the creation of new student records.
     *
     * <p>This is deliberately <em>not</em> a check against the active-student limit.
     * Alumni and dormant accounts are explicitly meant to stay on the platform without
     * consuming the allowance, so an academy with 200 active students and 2,000
     * graduates must still be able to enrol student 2,201. Capping records against the
     * active limit would make that impossible and push customers into deleting their
     * own history to stay under a number.
     *
     * <p>What it does block is intake by a tenant who has already exhausted both their
     * allowance <em>and</em> the overage headroom their plan permits. At that point they
     * are not slightly over — they are running an academy the plan was never sold to
     * support, and the honest answer is to upgrade. Blocking here is safe because it
     * stops an administrator adding people, never a student using the platform.
     */
    public void requireStudentIntake(Long organizationId, int requested) {
        ResolvedEntitlements resolved = entitlementService.resolve(organizationId);
        if (!resolved.hasSubscription()) {
            throw SubscriptionInactiveException.missing(describeOrg(organizationId));
        }
        if (resolved.isUnlimited(LimitKey.MAX_ACTIVE_STUDENTS)) {
            return;
        }

        long limit = resolved.limit(LimitKey.MAX_ACTIVE_STUDENTS);
        long overageHeadroom = planService.getByCode(resolved.getPlanCode())
                .map(plan -> plan.getOverageStudentsAllowed() != null
                        ? plan.getOverageStudentsAllowed().longValue() : 0L)
                .orElse(0L);
        long ceiling = limit + overageHeadroom;

        long active = usageService.activeStudents(organizationId);
        if (active < ceiling) {
            return;
        }

        QuotaExceededException error = QuotaExceededException.of(
                LimitKey.MAX_ACTIVE_STUDENTS.getErrorCode(),
                LimitKey.MAX_ACTIVE_STUDENTS.name(),
                LimitKey.MAX_ACTIVE_STUDENTS.getPluralLabel(),
                limit, active, requested, resolved.getPlanName());
        error.detail("overageSeatsAllowed", overageHeadroom)
             .detail("ceiling", ceiling)
             .detail("studentRecords", usageService.studentRecords(organizationId))
             .detail("blockedAction", "STUDENT_INTAKE");

        planService.getByCode(resolved.getPlanCode())
                .flatMap(planService::findUpgradeCandidate)
                .ifPresent(next -> error.withResolution(next.getCode(), next.getName(),
                        next.getMaxActiveStudents() != null ? next.getMaxActiveStudents().longValue() : null,
                        null, null));

        throw error;
    }

    /**
     * Guards storage consumption against the tenant's STORAGE_GB limit.
     */
    public void requireStorage(Long organizationId, long additionalBytes) {
        if (organizationId == null) {
            return;
        }
        ResolvedEntitlements resolved = entitlementService.resolve(organizationId);
        if (!resolved.hasSubscription()) {
            throw SubscriptionInactiveException.missing(describeOrg(organizationId));
        }
        if (resolved.isUnlimited(LimitKey.STORAGE_GB)) {
            return;
        }

        long limitGb = resolved.limit(LimitKey.STORAGE_GB);
        long limitBytes = limitGb * 1024L * 1024L * 1024L;
        long currentBytes = usageService.storageBytes(organizationId);
        if (currentBytes + additionalBytes <= limitBytes) {
            return;
        }

        long currentGb = usageService.storageGb(organizationId);
        throw buildQuotaError(LimitKey.STORAGE_GB, limitGb, currentGb, (int) Math.max(1, (additionalBytes + 1024L * 1024L * 1024L - 1) / (1024L * 1024L * 1024L)), resolved);
    }

    // =====================================================================
    // Feature guards
    // =====================================================================

    /** Asserts the current tenant's plan includes a feature. */
    public void requireEntitlement(Entitlement entitlement) {
        Long orgId = organizationContext.getCurrentOrgId();
        if (orgId == null) {
            return;
        }
        requireEntitlement(orgId, entitlement);
    }

    public void requireEntitlement(Long organizationId, Entitlement entitlement) {
        ResolvedEntitlements resolved = entitlementService.resolve(organizationId);
        if (!resolved.hasSubscription()) {
            throw SubscriptionInactiveException.missing(describeOrg(organizationId));
        }
        if (resolved.has(entitlement)) {
            return;
        }
        throw buildEntitlementError(entitlement, resolved);
    }

    public boolean hasEntitlement(Long organizationId, Entitlement entitlement) {
        return entitlementService.resolve(organizationId).has(entitlement);
    }

    // =====================================================================
    // Overage — metered, never blocked
    // =====================================================================

    /**
     * Reports whether a student becoming active right now would exceed the plan
     * allowance, so the meter can flag the row as overage.
     *
     * <p>Returns a boolean rather than throwing, on purpose. This is called from the
     * login and content paths, where refusing the request would lock a paying learner
     * out of their own course to make a commercial point.
     */
    public boolean recordOverageIfNeeded(Long organizationId, ResolvedEntitlements resolved) {
        if (resolved == null || !resolved.hasSubscription()) {
            return false;
        }
        if (resolved.isUnlimited(LimitKey.MAX_ACTIVE_STUDENTS)) {
            return false;
        }
        long limit = resolved.limit(LimitKey.MAX_ACTIVE_STUDENTS);
        long current = usageService.activeStudents(organizationId);
        boolean over = current >= limit;
        if (over) {
            log.info("Organization {} is at {} of {} active students; further activity is billed as overage.",
                    organizationId, current, limit);
        }
        return over;
    }

    // =====================================================================
    // Error construction
    // =====================================================================

    /**
     * Builds a quota error that names a way out. Prefers the upgrade path when the next
     * tier genuinely raises this limit, and falls back to the add-on that does.
     */
    private QuotaExceededException buildQuotaError(LimitKey key, long limit, long current,
                                                  int requested, ResolvedEntitlements resolved) {
        QuotaExceededException error = QuotaExceededException.of(
                key.getErrorCode(), key.name(), key.getPluralLabel(),
                limit, current, requested, resolved.getPlanName());

        String upgradeCode = null;
        String upgradeName = null;
        Long upgradeLimit = null;

        Optional<OrgSubscription> currentPlan = planService.getByCode(resolved.getPlanCode());
        if (currentPlan.isPresent()) {
            Optional<OrgSubscription> candidate = planService.findUpgradeCandidate(currentPlan.get());
            if (candidate.isPresent()) {
                OrgSubscription next = candidate.get();
                Long nextLimit = limitOf(next, key);
                // Only offer an upgrade that actually helps. Suggesting a more expensive
                // plan with the same ceiling would be worse than saying nothing.
                if (nextLimit == null || nextLimit > limit) {
                    upgradeCode = next.getCode();
                    upgradeName = next.getName();
                    upgradeLimit = nextLimit;
                }
            }
        }

        String addonCode = null;
        String addonName = null;
        List<PlanAddon> raising = addonService.findRaising(key);
        for (PlanAddon addon : raising) {
            // Respect the add-on's plan restrictions, so a branch add-on is not offered
            // to a tenant whose plan has no multi-branch feature to use it with.
            if (com.institute.lms.util.JsonUtils.listContains(
                    addon.getAppliesToPlanCodes(), resolved.getPlanCode())) {
                addonCode = addon.getCode();
                addonName = addon.getName();
                break;
            }
        }

        // Overage seats are capped so growth eventually moves a tenant up a tier rather
        // than letting them run indefinitely on stacked add-ons. Once the cap is
        // reached, stop offering the add-on.
        if (key == LimitKey.MAX_ACTIVE_STUDENTS && currentPlan.isPresent()) {
            long alreadyBought = resolved.addonContribution(key);
            Integer allowed = currentPlan.get().getOverageStudentsAllowed();
            if (allowed != null && alreadyBought >= allowed) {
                addonCode = null;
                addonName = null;
                error.detail("overageCapReached", true)
                     .detail("overageSeatsPurchased", alreadyBought)
                     .detail("overageSeatsAllowed", allowed);
            }
        }

        return error.withResolution(upgradeCode, upgradeName, upgradeLimit, addonCode, addonName);
    }

    private EntitlementRequiredException buildEntitlementError(Entitlement entitlement,
                                                              ResolvedEntitlements resolved) {
        EntitlementRequiredException error = EntitlementRequiredException.of(
                entitlement.name(), entitlement.getLabel(), resolved.getPlanName());

        // Name the cheapest plan that includes the feature, so the tenant is told what
        // to buy rather than only what they lack.
        String requiredPlanCode = null;
        String requiredPlanName = null;
        for (OrgSubscription plan : planService.getPublicPlans()) {
            if (grants(plan, entitlement)) {
                requiredPlanCode = plan.getCode();
                requiredPlanName = plan.getName();
                break;
            }
        }

        String addonCode = null;
        String addonName = null;
        boolean requiresQuote = entitlement.isSalesQualified();
        List<PlanAddon> granting = addonService.findGranting(entitlement);
        if (!granting.isEmpty()) {
            PlanAddon addon = granting.get(0);
            addonCode = addon.getCode();
            addonName = addon.getName();
            requiresQuote = requiresQuote || Boolean.TRUE.equals(addon.getRequiresQuote());
        }

        return error.withResolution(requiredPlanCode, requiredPlanName, addonCode, addonName, requiresQuote);
    }

    /** Whether a catalog plan grants an entitlement, read from its stored JSON. */
    private boolean grants(OrgSubscription plan, Entitlement entitlement) {
        return com.institute.lms.util.JsonUtils.getBoolean(
                com.institute.lms.util.JsonUtils.readMap(plan.getEntitlements()), entitlement.name());
    }

    private Long limitOf(OrgSubscription plan, LimitKey key) {
        return switch (key) {
            case MAX_ACTIVE_STUDENTS -> toLong(plan.getMaxActiveStudents());
            case MAX_FACULTY_ACCOUNTS -> toLong(plan.getMaxFacultyAccounts());
            case MAX_BRANCHES -> toLong(plan.getMaxBranches());
            case MAX_ORGANIZATIONS -> toLong(plan.getMaxOrganizations());
            case STORAGE_GB -> toLong(plan.getStorageGb());
            case INCLUDED_TRAINING_HOURS -> plan.getIncludedTrainingHours() != null
                    ? plan.getIncludedTrainingHours().longValue() : null;
        };
    }

    private Long toLong(Integer value) {
        return value != null ? value.longValue() : null;
    }

    /** The organization's display name for error messages, falling back to a neutral phrase. */
    private String describeOrg(Long organizationId) {
        if (organizationId == null) {
            return "this organization";
        }
        return organizationRepository.findById(organizationId)
                .map(com.institute.lms.entity.Organization::getName)
                .filter(name -> name != null && !name.isBlank())
                .orElse("this organization");
    }

    /**
     * Asserts the tenant's subscription permits a write, used by the request
     * interceptor. Reads are permitted in more states than writes, so read paths must
     * not call this.
     */
    public void requireWriteAccess(Long organizationId) {
        ResolvedEntitlements resolved = entitlementService.resolve(organizationId);
        if (!resolved.hasSubscription()) {
            throw SubscriptionInactiveException.missing(describeOrg(organizationId));
        }
        SubscriptionStatus status = resolved.getStatus();
        if (status == null || status.allowsWrites()) {
            return;
        }
        throw toInactiveException(resolved);
    }

    /** Maps a non-writable status onto the matching typed exception. */
    public SubscriptionInactiveException toInactiveException(ResolvedEntitlements resolved) {
        SubscriptionStatus status = resolved.getStatus();
        String planName = resolved.getPlanName();
        var instance = resolved.getInstance();
        return switch (status) {
            case SUSPENDED -> SubscriptionInactiveException.suspended(
                    instance != null ? instance.getSuspensionReason() : null);
            case CANCELLED -> SubscriptionInactiveException.cancelled(planName);
            case READ_ONLY, EXPIRED -> SubscriptionInactiveException.readOnly(
                    planName, instance != null ? instance.getPeriodEnd() : null);
            default -> SubscriptionInactiveException.expired(
                    planName, instance != null ? instance.getPeriodEnd() : null);
        };
    }
}
