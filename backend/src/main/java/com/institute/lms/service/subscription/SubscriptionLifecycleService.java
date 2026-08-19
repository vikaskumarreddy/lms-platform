package com.institute.lms.service.subscription;

import com.institute.lms.entity.*;
import com.institute.lms.exception.BadRequestException;
import com.institute.lms.exception.ErrorCode;
import com.institute.lms.exception.PlanChangeNotAllowedException;
import com.institute.lms.exception.ResourceNotFoundException;
import com.institute.lms.repository.*;
import com.institute.lms.service.OrgSubscriptionService;
import com.institute.lms.subscription.*;
import com.institute.lms.util.JsonUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Owns every transition a tenant's subscription can make: first purchase, upgrade,
 * downgrade, renewal, cancellation, reactivation, suspension, expiry, and negotiated
 * limit overrides.
 *
 * <p>Two invariants are maintained here rather than left to callers:
 *
 * <p><strong>1. Snapshots are frozen at purchase.</strong> Starting or renewing a term
 * copies the plan's limits, entitlements, price and tax treatment onto the instance.
 * Nothing afterwards re-reads the catalog, which is what allows a plan's price to be
 * changed for new business without touching existing customers.
 *
 * <p><strong>2. The organization row is kept in sync.</strong>
 * {@code organizations.org_subscription_id / purchase_date / expiry_date / status} are a
 * denormalised cache of the current instance. Keeping them current means the existing
 * readers — the organizations list, platform revenue stats, the renewal action — keep
 * working unchanged rather than needing to learn about instances.
 */
@Service
public class SubscriptionLifecycleService {

    private static final Logger log = LoggerFactory.getLogger(SubscriptionLifecycleService.class);

    private final OrgSubscriptionInstanceRepository instanceRepository;
    private final OrgSubscriptionAddonRepository addonRepository;
    private final OrgBillingEventRepository eventRepository;
    private final OrgPlanChangeRequestRepository changeRequestRepository;
    private final OrganizationRepository organizationRepository;
    private final OrgSubscriptionService planService;
    private final EntitlementService entitlementService;
    private final UsageService usageService;
    private final ProrationCalculator prorationCalculator;

    public SubscriptionLifecycleService(OrgSubscriptionInstanceRepository instanceRepository,
                                        OrgSubscriptionAddonRepository addonRepository,
                                        OrgBillingEventRepository eventRepository,
                                        OrgPlanChangeRequestRepository changeRequestRepository,
                                        OrganizationRepository organizationRepository,
                                        OrgSubscriptionService planService,
                                        EntitlementService entitlementService,
                                        UsageService usageService,
                                        ProrationCalculator prorationCalculator) {
        this.instanceRepository = instanceRepository;
        this.addonRepository = addonRepository;
        this.eventRepository = eventRepository;
        this.changeRequestRepository = changeRequestRepository;
        this.organizationRepository = organizationRepository;
        this.planService = planService;
        this.entitlementService = entitlementService;
        this.usageService = usageService;
        this.prorationCalculator = prorationCalculator;
    }

    /** Options for starting a term, so the signature does not grow to a dozen parameters. */
    public static class SubscribeOptions {
        public BillingCycle billingCycle = BillingCycle.MONTHLY;
        /** Negotiated price. When null, the plan's list price for the cycle is used. */
        public BigDecimal agreedPrice;
        /** Explicit term end, required for CUSTOM and ONE_TIME cycles. */
        public LocalDateTime periodEnd;
        public boolean startTrial;
        public boolean autoRenew = true;
        public String poNumber;
        public String quotationRef;
        public String salesOwner;
        public String couponCode;
        public BigDecimal discountAmount;
        public String notes;
        public String actor;
        public SubscriptionChangeReason changeReason = SubscriptionChangeReason.NEW;
        public String changeNote;
        /** Negotiated limit overrides, only honoured when the plan allows it. */
        public Map<LimitKey, Long> limitOverrides;
    }

    public Optional<OrgSubscriptionInstance> findCurrent(Long organizationId) {
        return organizationId == null
                ? Optional.empty()
                : instanceRepository.findByOrganizationIdAndIsCurrentTrue(organizationId);
    }

    public List<OrgSubscriptionInstance> history(Long organizationId) {
        return instanceRepository.findByOrganizationIdOrderByCreatedAtDesc(organizationId);
    }

    // =====================================================================
    // Starting a term
    // =====================================================================

    /**
     * Starts a subscription for an organization, superseding any current term.
     *
     * <p>This is the single entry point for a first purchase, a plan change and a
     * renewal, because all three do the same thing: freeze a snapshot and mark the
     * previous term historic.
     */
    @Transactional
    public OrgSubscriptionInstance subscribe(Long organizationId, Long planId, SubscribeOptions options) {
        Organization org = organizationRepository.findById(organizationId)
                .orElseThrow(() -> ResourceNotFoundException.of("Organization", organizationId));
        OrgSubscription plan = planService.requireById(planId);
        SubscribeOptions opts = options != null ? options : new SubscribeOptions();

        if (!Boolean.TRUE.equals(plan.getIsActive())) {
            throw new BadRequestException(ErrorCode.PLAN_NOT_FOUND,
                    "'" + plan.getName() + "' is no longer offered, so a new subscription cannot start on it.");
        }

        OrgSubscriptionInstance previous = findCurrent(organizationId).orElse(null);

        BillingCycle cycle = opts.billingCycle != null ? opts.billingCycle : BillingCycle.MONTHLY;
        BigDecimal price = resolvePrice(plan, cycle, opts.agreedPrice);

        LocalDateTime start = LocalDateTime.now();
        LocalDateTime end = resolvePeriodEnd(cycle, start, opts.periodEnd, plan);

        OrgSubscriptionInstance instance = new OrgSubscriptionInstance();
        instance.setOrganizationId(organizationId);
        instance.setPlanId(plan.getId());
        instance.setPlanCode(plan.getCode());
        instance.setPlanName(plan.getName());

        // Freeze everything commercial. Nothing below is ever re-read from the catalog.
        instance.setUnitPrice(price);
        instance.setCurrency(plan.getCurrency());
        instance.setTaxInclusive(plan.getTaxInclusive());
        instance.setGstRatePct(plan.getGstRatePct());
        instance.setHsnSacCode(plan.getHsnSacCode());
        instance.setLimitsSnapshot(entitlementService.snapshotLimits(plan));
        instance.setEntitlementsSnapshot(entitlementService.snapshotEntitlements(plan));

        if (opts.limitOverrides != null && !opts.limitOverrides.isEmpty()) {
            requireConfigurableLimits(plan);
            instance.setLimitsOverride(entitlementService.buildLimitsOverride(opts.limitOverrides));
        }

        instance.setBillingCycle(cycle);
        instance.setPeriodStart(start);
        instance.setPeriodEnd(end);
        instance.setGraceEndsAt(end != null ? end.plusDays(plan.getGraceDays()) : null);
        instance.setAutoRenew(opts.autoRenew);

        if (opts.startTrial && plan.getTrialDays() != null && plan.getTrialDays() > 0) {
            instance.setStatus(SubscriptionStatus.TRIALING);
            instance.setTrialEndsAt(start.plusDays(plan.getTrialDays()));
        } else if ("PILOT".equals(plan.getCode())) {
            instance.setStatus(SubscriptionStatus.PILOT);
        } else {
            instance.setStatus(SubscriptionStatus.ACTIVE);
        }
        instance.setActivatedAt(start);

        instance.setPoNumber(opts.poNumber);
        instance.setQuotationRef(opts.quotationRef);
        instance.setSalesOwner(opts.salesOwner);
        instance.setCouponCode(opts.couponCode);
        instance.setDiscountAmount(opts.discountAmount != null ? opts.discountAmount : BigDecimal.ZERO);
        instance.setNotes(opts.notes);
        instance.setChangeReason(opts.changeReason != null ? opts.changeReason : SubscriptionChangeReason.NEW);
        instance.setChangeNote(opts.changeNote);
        instance.setPreviousInstanceId(previous != null ? previous.getId() : null);
        instance.setCreatedBy(opts.actor);
        instance.setIsCurrent(true);

        // Retire the old term BEFORE inserting the new one. The partial unique index
        // (uk_osi_current_per_org) permits only one current row per organization, and a
        // flush must never see two.
        if (previous != null) {
            instanceRepository.clearCurrentFlag(organizationId);
            instanceRepository.flush();
        }

        OrgSubscriptionInstance saved = instanceRepository.save(instance);

        // Recurring add-ons follow the customer across terms; one-off purchases do not.
        if (previous != null) {
            carryOverRecurringAddons(previous, saved, opts.actor);
        }

        syncOrganizationCache(org, saved);

        recordEvent(organizationId, saved.getId(),
                eventTypeFor(saved.getChangeReason()),
                previous != null ? previous.getStatus() : null, saved.getStatus(),
                opts.actor,
                String.format("%s on %s (%s)%s",
                        saved.getChangeReason().getLabel(), plan.getName(), cycle.getLabel(),
                        price != null ? " at " + price.toPlainString() + " " + saved.getCurrency() : ""),
                detailOf(saved));

        return saved;
    }

    // =====================================================================
    // Plan changes
    // =====================================================================

    /**
     * Moves a tenant to another plan immediately, prorating the change.
     *
     * <p>Refuses a downgrade the tenant's current usage does not fit into: silently
     * moving 400 students onto a 200-seat plan would either break enforcement or
     * retroactively put the customer in breach.
     */
    @Transactional
    public OrgSubscriptionInstance changePlan(Long organizationId, Long targetPlanId,
                                              BillingCycle cycle, String actor, String note) {
        OrgSubscriptionInstance current = findCurrent(organizationId).orElse(null);
        OrgSubscription target = planService.requireById(targetPlanId);

        if (current != null && current.getPlanId().equals(targetPlanId)
                && (cycle == null || cycle == current.getBillingCycle())) {
            throw PlanChangeNotAllowedException.samePlan(target.getName());
        }

        SubscriptionChangeReason reason = classifyChange(current, target, cycle);
        if (reason == SubscriptionChangeReason.DOWNGRADE) {
            assertDowngradeFits(organizationId, target);
        }

        BillingCycle resolvedCycle = cycle != null
                ? cycle
                : (current != null ? current.getBillingCycle() : BillingCycle.MONTHLY);

        // Computed before the switch, while the outgoing term is still readable.
        ProrationCalculator.ProrationResult proration = prorationCalculator.prorate(
                current, target.priceFor(resolvedCycle.name()), LocalDateTime.now());

        SubscribeOptions options = new SubscribeOptions();
        options.billingCycle = resolvedCycle;
        options.actor = actor;
        options.changeReason = reason;
        options.changeNote = combineNotes(note, proration.explanation());
        options.autoRenew = current == null || Boolean.TRUE.equals(current.getAutoRenew());
        options.poNumber = current != null ? current.getPoNumber() : null;
        options.salesOwner = current != null ? current.getSalesOwner() : null;

        OrgSubscriptionInstance saved = subscribe(organizationId, targetPlanId, options);

        // The proration figure is recorded as its own event so the amount can be found
        // later without recomputing it from dates that have since moved on.
        Map<String, Object> detail = new LinkedHashMap<>();
        detail.put("daysInPeriod", proration.daysInPeriod());
        detail.put("daysRemaining", proration.daysRemaining());
        detail.put("unusedCredit", proration.unusedCredit());
        detail.put("newCharge", proration.newCharge());
        detail.put("netAmount", proration.netAmount());
        detail.put("fromPlanCode", current != null ? current.getPlanCode() : null);
        detail.put("toPlanCode", target.getCode());

        OrgBillingEvent event = OrgBillingEvent.of(organizationId, saved.getId(),
                reason == SubscriptionChangeReason.DOWNGRADE
                        ? BillingEventType.DOWNGRADED : BillingEventType.UPGRADED,
                actor, proration.explanation());
        event.setDetail(JsonUtils.write(detail));
        eventRepository.save(event);

        return saved;
    }

    /**
     * Renews the current term for another period on the same plan.
     *
     * <p>The snapshot is retaken from the plan as it now stands, because renewal is a
     * new agreement — this is the moment a price change legitimately reaches an existing
     * customer, which is exactly why it must not happen at any other time.
     */
    @Transactional
    public OrgSubscriptionInstance renew(Long organizationId, String actor) {
        OrgSubscriptionInstance current = findCurrent(organizationId)
                .orElseThrow(() -> new BadRequestException(ErrorCode.SUBSCRIPTION_MISSING,
                        "There is no subscription to renew for this organization."));

        SubscribeOptions options = new SubscribeOptions();
        options.billingCycle = current.getBillingCycle();
        options.actor = actor;
        options.changeReason = SubscriptionChangeReason.RENEWAL;
        options.autoRenew = current.getAutoRenew();
        options.poNumber = current.getPoNumber();
        options.salesOwner = current.getSalesOwner();
        // A negotiated price is honoured across renewal; only a list-priced customer
        // moves to the current list price.
        if (isNegotiatedPrice(current)) {
            options.agreedPrice = current.getUnitPrice();
            options.changeNote = "Renewed at the previously agreed price of "
                    + current.getUnitPrice().toPlainString() + " " + current.getCurrency() + ".";
        }
        // Negotiated limits survive renewal too.
        if (current.getLimitsOverride() != null && !current.getLimitsOverride().isBlank()) {
            options.limitOverrides = parseOverrides(current.getLimitsOverride());
        }
        if (current.getBillingCycle() == BillingCycle.CUSTOM && current.getPeriodEnd() != null) {
            // Preserve the negotiated term length rather than guessing a new one.
            long days = java.time.Duration.between(current.getPeriodStart(), current.getPeriodEnd()).toDays();
            options.periodEnd = LocalDateTime.now().plusDays(Math.max(1, days));
        }

        return subscribe(organizationId, current.getPlanId(), options);
    }

    // =====================================================================
    // Cancellation, suspension, reactivation
    // =====================================================================

    /**
     * Cancels the subscription.
     *
     * @param atPeriodEnd when true the tenant keeps full access until the paid term
     *                    ends, which is the fair default — they have paid for it
     */
    @Transactional
    public OrgSubscriptionInstance cancel(Long organizationId, boolean atPeriodEnd,
                                          String reason, String actor) {
        OrgSubscriptionInstance current = requireCurrent(organizationId);
        SubscriptionStatus from = current.getStatus();

        current.setAutoRenew(false);
        current.setChangeNote(combineNotes(current.getChangeNote(), reason));

        if (atPeriodEnd && current.getPeriodEnd() != null
                && current.getPeriodEnd().isAfter(LocalDateTime.now())) {
            // Access continues to term end; the scheduled sweep expires it then.
            current.setCancelAt(current.getPeriodEnd());
        } else {
            current.setStatus(SubscriptionStatus.CANCELLED);
            current.setCancelledAt(LocalDateTime.now());
            current.setCancelAt(LocalDateTime.now());
        }

        OrgSubscriptionInstance saved = instanceRepository.save(current);
        organizationRepository.findById(organizationId)
                .ifPresent(org -> syncOrganizationCache(org, saved));

        recordEvent(organizationId, saved.getId(), BillingEventType.CANCELLED,
                from, saved.getStatus(), actor,
                atPeriodEnd
                        ? "Cancellation scheduled for the end of the paid term on "
                            + saved.getPeriodEnd() + ". " + orEmpty(reason)
                        : "Cancelled with immediate effect. " + orEmpty(reason),
                null);
        return saved;
    }

    /** Suspends a tenant entirely — normally the end of dunning. Blocks reads as well as writes. */
    @Transactional
    public OrgSubscriptionInstance suspend(Long organizationId, String reason, String actor) {
        OrgSubscriptionInstance current = requireCurrent(organizationId);
        SubscriptionStatus from = current.getStatus();

        current.setStatus(SubscriptionStatus.SUSPENDED);
        current.setSuspendedAt(LocalDateTime.now());
        current.setSuspensionReason(reason);

        OrgSubscriptionInstance saved = instanceRepository.save(current);
        Organization org = organizationRepository.findById(organizationId).orElse(null);
        if (org != null) {
            org.setIsActive(false);
            syncOrganizationCache(org, saved);
        }

        recordEvent(organizationId, saved.getId(), BillingEventType.SUSPENDED,
                from, SubscriptionStatus.SUSPENDED, actor,
                "Suspended. " + orEmpty(reason), null);
        return saved;
    }

    /** Lifts a suspension, returning the tenant to the state the clock implies. */
    @Transactional
    public OrgSubscriptionInstance resume(Long organizationId, String actor) {
        OrgSubscriptionInstance current = requireCurrent(organizationId);
        SubscriptionStatus from = current.getStatus();

        current.setSuspendedAt(null);
        current.setSuspensionReason(null);
        // Do not blindly restore ACTIVE: if the term expired while suspended, the tenant
        // should come back read-only, not with full access they have not paid for.
        current.setStatus(current.isPastGrace()
                ? SubscriptionStatus.EXPIRED
                : (current.isPastPeriodEnd() ? SubscriptionStatus.GRACE : SubscriptionStatus.ACTIVE));

        OrgSubscriptionInstance saved = instanceRepository.save(current);
        Organization org = organizationRepository.findById(organizationId).orElse(null);
        if (org != null) {
            org.setIsActive(true);
            syncOrganizationCache(org, saved);
        }

        recordEvent(organizationId, saved.getId(), BillingEventType.RESUMED,
                from, saved.getStatus(), actor, "Suspension lifted.", null);
        return saved;
    }

    /** Restarts a lapsed, expired or cancelled subscription as a fresh term. */
    @Transactional
    public OrgSubscriptionInstance reactivate(Long organizationId, Long planId, String actor) {
        OrgSubscriptionInstance current = findCurrent(organizationId).orElse(null);
        Long targetPlan = planId != null ? planId
                : (current != null ? current.getPlanId() : null);
        if (targetPlan == null) {
            throw new BadRequestException(ErrorCode.SUBSCRIPTION_MISSING,
                    "Choose a plan to reactivate this organization on.");
        }

        SubscribeOptions options = new SubscribeOptions();
        options.billingCycle = current != null ? current.getBillingCycle() : BillingCycle.MONTHLY;
        options.actor = actor;
        options.changeReason = SubscriptionChangeReason.REACTIVATION;
        options.changeNote = "Reactivated"
                + (current != null ? " after " + current.getStatus().getLabel().toLowerCase() : "") + ".";

        Organization org = organizationRepository.findById(organizationId).orElse(null);
        if (org != null) {
            org.setIsActive(true);
            org.setStatus("ACTIVE");
            org.setRenewalCount((org.getRenewalCount() == null ? 0 : org.getRenewalCount()) + 1);
            organizationRepository.save(org);
        }
        return subscribe(organizationId, targetPlan, options);
    }

    // =====================================================================
    // Negotiated limits
    // =====================================================================

    /**
     * Applies per-tenant limit overrides, for the plans that permit it. A null value for
     * a key means unlimited.
     */
    @Transactional
    public OrgSubscriptionInstance overrideLimits(Long organizationId,
                                                  Map<LimitKey, Long> overrides,
                                                  String actor) {
        OrgSubscriptionInstance current = requireCurrent(organizationId);
        OrgSubscription plan = planService.requireById(current.getPlanId());
        requireConfigurableLimits(plan);

        current.setLimitsOverride(entitlementService.buildLimitsOverride(overrides));
        OrgSubscriptionInstance saved = instanceRepository.save(current);

        recordEvent(organizationId, saved.getId(), BillingEventType.LIMITS_OVERRIDDEN,
                saved.getStatus(), saved.getStatus(), actor,
                "Custom limits applied for this organization.",
                saved.getLimitsOverride());
        return saved;
    }

    // =====================================================================
    // Clock-driven transitions
    // =====================================================================

    /**
     * Persists the status the clock implies for one term, if it differs from what is
     * stored. Idempotent, so it is safe to call from both the scheduled sweep and a
     * request path.
     *
     * @return true when the status changed
     */
    @Transactional
    public boolean refreshStatus(OrgSubscriptionInstance instance, String actor) {
        SubscriptionStatus stored = instance.getStatus();
        SubscriptionStatus effective = instance.getEffectiveStatus();

        // A cancellation scheduled for term end takes effect once that moment passes.
        if (instance.getCancelAt() != null && instance.getCancelAt().isBefore(LocalDateTime.now())
                && stored != SubscriptionStatus.CANCELLED) {
            effective = SubscriptionStatus.CANCELLED;
            instance.setCancelledAt(LocalDateTime.now());
        }

        if (effective == stored) {
            return false;
        }

        instance.setStatus(effective);
        if (effective == SubscriptionStatus.EXPIRED && instance.getExpiredAt() == null) {
            instance.setExpiredAt(LocalDateTime.now());
        }
        instanceRepository.save(instance);

        organizationRepository.findById(instance.getOrganizationId())
                .ifPresent(org -> syncOrganizationCache(org, instance));

        BillingEventType type = switch (effective) {
            case GRACE -> BillingEventType.GRACE_STARTED;
            case EXPIRED -> BillingEventType.EXPIRED;
            case READ_ONLY -> BillingEventType.READ_ONLY;
            case CANCELLED -> BillingEventType.CANCELLED;
            default -> BillingEventType.SUBSCRIBED;
        };
        recordEvent(instance.getOrganizationId(), instance.getId(), type, stored, effective, actor,
                String.format("Status moved from %s to %s.", stored.getLabel(), effective.getLabel()), null);

        log.info("Organization {} subscription moved {} -> {}", instance.getOrganizationId(), stored, effective);
        return true;
    }

    // =====================================================================
    // Tenant-raised plan change requests
    // =====================================================================

    /**
     * Records a tenant's request to change plan, or applies it immediately when the
     * target plan permits self-serve changes.
     *
     * <p>The default is to request rather than apply. Without a payment gateway
     * collecting money at the moment of the click, applying an upgrade straight away
     * would hand over a more expensive plan's entitlements on trust.
     */
    @Transactional
    public OrgPlanChangeRequest requestPlanChange(Long organizationId, Long targetPlanId,
                                                  BillingCycle cycle, Long userId,
                                                  String userEmail, String note) {
        OrgSubscription target = planService.requireById(targetPlanId);
        OrgSubscriptionInstance current = findCurrent(organizationId).orElse(null);

        if (current != null && current.getPlanId().equals(targetPlanId)
                && (cycle == null || cycle == current.getBillingCycle())) {
            throw PlanChangeNotAllowedException.samePlan(target.getName());
        }

        SubscriptionChangeReason reason = classifyChange(current, target, cycle);
        if (reason == SubscriptionChangeReason.DOWNGRADE) {
            // Checked at request time so the tenant is told immediately, rather than
            // waiting for a rejection they could have predicted.
            assertDowngradeFits(organizationId, target);
        }

        // Reuse the open request instead of inserting a second one; a partial unique
        // index permits only one PENDING row per organization.
        OrgPlanChangeRequest request = changeRequestRepository
                .findByOrganizationIdAndStatus(organizationId, OrgPlanChangeRequest.STATUS_PENDING)
                .orElseGet(OrgPlanChangeRequest::new);

        request.setOrganizationId(organizationId);
        request.setCurrentInstanceId(current != null ? current.getId() : null);
        request.setRequestedPlanId(target.getId());
        request.setRequestedPlanCode(target.getCode());
        request.setRequestedBillingCycle(cycle != null ? cycle : BillingCycle.MONTHLY);
        request.setRequestKind(switch (reason) {
            case DOWNGRADE -> OrgPlanChangeRequest.KIND_DOWNGRADE;
            case CYCLE_CHANGE -> OrgPlanChangeRequest.KIND_CYCLE_CHANGE;
            default -> OrgPlanChangeRequest.KIND_UPGRADE;
        });
        request.setStatus(OrgPlanChangeRequest.STATUS_PENDING);
        request.setRequestedByUserId(userId);
        request.setRequestedByEmail(userEmail);
        request.setRequestedNote(note);

        OrgPlanChangeRequest saved = changeRequestRepository.save(request);

        recordEvent(organizationId, current != null ? current.getId() : null,
                BillingEventType.PLAN_CHANGE_REQUESTED, null, null, userEmail,
                String.format("%s to %s requested.", request.getRequestKind(), target.getName()), null);

        // A custom-priced plan always goes to sales, whatever the self-serve flag says.
        if (Boolean.TRUE.equals(target.getSelfServeUpgradeEnabled())
                && !Boolean.TRUE.equals(target.getIsCustomPriced())) {
            approvePlanChange(saved.getId(), userEmail,
                    "Applied automatically: this plan allows self-serve changes.");
        }
        return changeRequestRepository.findById(saved.getId()).orElse(saved);
    }

    @Transactional
    public OrgPlanChangeRequest approvePlanChange(Long requestId, String actor, String decisionNote) {
        OrgPlanChangeRequest request = changeRequestRepository.findById(requestId)
                .orElseThrow(() -> ResourceNotFoundException.of("Plan change request", requestId));
        if (!request.isPending()) {
            throw new BadRequestException("This request has already been " + request.getStatus().toLowerCase() + ".");
        }

        OrgSubscriptionInstance instance = changePlan(request.getOrganizationId(),
                request.getRequestedPlanId(), request.getRequestedBillingCycle(), actor, decisionNote);

        request.setStatus(OrgPlanChangeRequest.STATUS_APPROVED);
        request.setDecidedBy(actor);
        request.setDecidedAt(LocalDateTime.now());
        request.setDecisionNote(decisionNote);
        request.setResultingInstanceId(instance.getId());
        OrgPlanChangeRequest saved = changeRequestRepository.save(request);

        recordEvent(request.getOrganizationId(), instance.getId(),
                BillingEventType.PLAN_CHANGE_APPROVED, null, instance.getStatus(), actor,
                "Plan change approved: now on " + instance.getPlanName() + ".", null);
        return saved;
    }

    @Transactional
    public OrgPlanChangeRequest rejectPlanChange(Long requestId, String actor, String decisionNote) {
        OrgPlanChangeRequest request = changeRequestRepository.findById(requestId)
                .orElseThrow(() -> ResourceNotFoundException.of("Plan change request", requestId));
        if (!request.isPending()) {
            throw new BadRequestException("This request has already been " + request.getStatus().toLowerCase() + ".");
        }
        request.setStatus(OrgPlanChangeRequest.STATUS_REJECTED);
        request.setDecidedBy(actor);
        request.setDecidedAt(LocalDateTime.now());
        request.setDecisionNote(decisionNote);
        OrgPlanChangeRequest saved = changeRequestRepository.save(request);

        recordEvent(request.getOrganizationId(), request.getCurrentInstanceId(),
                BillingEventType.PLAN_CHANGE_REJECTED, null, null, actor,
                "Plan change declined. " + orEmpty(decisionNote), null);
        return saved;
    }

    // =====================================================================
    // Internals
    // =====================================================================

    /**
     * Mirrors the current instance onto the organization row.
     *
     * <p>These columns predate subscription instances and are still read by the
     * organizations list, the platform revenue stats and the existing renew action.
     * Keeping them in sync means none of that code had to change — but it also means
     * every write path here must call this, or the two will disagree.
     */
    public void syncOrganizationCache(Organization org, OrgSubscriptionInstance instance) {
        if (org == null || instance == null) {
            return;
        }
        org.setOrgSubscriptionId(instance.getPlanId());
        org.setPurchaseDate(instance.getPeriodStart());
        org.setExpiryDate(instance.getPeriodEnd());
        SubscriptionStatus status = instance.getEffectiveStatus();
        org.setStatus(status != null && status.isLive() ? "ACTIVE" : "EXPIRED");
        if (status == SubscriptionStatus.SUSPENDED || status == SubscriptionStatus.CANCELLED) {
            org.setIsActive(false);
        }
        organizationRepository.save(org);
    }

    /**
     * Refuses a downgrade the tenant does not fit into, naming the resource that blocks
     * it so the admin knows what to reduce.
     */
    private void assertDowngradeFits(Long organizationId, OrgSubscription target) {
        checkFits(organizationId, target, LimitKey.MAX_ACTIVE_STUDENTS, target.getMaxActiveStudents());
        checkFits(organizationId, target, LimitKey.MAX_FACULTY_ACCOUNTS, target.getMaxFacultyAccounts());
        checkFits(organizationId, target, LimitKey.MAX_BRANCHES, target.getMaxBranches());
        checkFits(organizationId, target, LimitKey.STORAGE_GB, target.getStorageGb());
    }

    private void checkFits(Long organizationId, OrgSubscription target, LimitKey key, Integer targetLimit) {
        if (targetLimit == null) {
            return; // unlimited on the target plan
        }
        long current = usageService.usageOf(key, organizationId);
        if (current > targetLimit) {
            throw PlanChangeNotAllowedException.downgradeBlocked(
                    target.getName(), key.getPluralLabel(), current, targetLimit);
        }
    }

    /** Compares tier ranks to decide whether a change is up, down, or cycle-only. */
    private SubscriptionChangeReason classifyChange(OrgSubscriptionInstance current,
                                                    OrgSubscription target, BillingCycle cycle) {
        if (current == null) {
            return SubscriptionChangeReason.NEW;
        }
        if (current.getPlanId().equals(target.getId())) {
            return SubscriptionChangeReason.CYCLE_CHANGE;
        }
        Optional<OrgSubscription> currentPlan = planService.getByCode(current.getPlanCode());
        int currentRank = currentPlan.map(p -> p.getTierRank() != null ? p.getTierRank() : 0).orElse(0);
        int targetRank = target.getTierRank() != null ? target.getTierRank() : 0;
        if (targetRank > currentRank) {
            return SubscriptionChangeReason.UPGRADE;
        }
        if (targetRank < currentRank) {
            return SubscriptionChangeReason.DOWNGRADE;
        }
        return SubscriptionChangeReason.PLAN_MIGRATION;
    }

    private void requireConfigurableLimits(OrgSubscription plan) {
        if (!Boolean.TRUE.equals(plan.getLimitsConfigurable())) {
            throw new BadRequestException(String.format(
                    "'%s' has fixed limits. Custom limits are only available on plans marked configurable "
                            + "(Managed Academy and Enterprise) — move the organization to one of those first.",
                    plan.getName()));
        }
    }

    /**
     * Resolves the price for a term. A custom-priced plan requires an explicitly agreed
     * figure: defaulting it to zero would silently create a free subscription.
     */
    private BigDecimal resolvePrice(OrgSubscription plan, BillingCycle cycle, BigDecimal agreed) {
        if (agreed != null) {
            return agreed;
        }
        if (Boolean.TRUE.equals(plan.getIsCustomPriced())) {
            throw new BadRequestException(ErrorCode.PLAN_REQUIRES_QUOTE, String.format(
                    "'%s' is priced per organization, so an agreed price has to be entered "
                            + "when starting the subscription.", plan.getName()));
        }
        BigDecimal price = plan.priceFor(cycle.name());
        if (price == null) {
            throw new BadRequestException(String.format(
                    "'%s' has no %s price configured. Set one on the plan, or enter an agreed price.",
                    plan.getName(), cycle.getLabel().toLowerCase()));
        }
        return price;
    }

    /** Derives the term end from the cycle, requiring an explicit date where the cycle cannot imply one. */
    private LocalDateTime resolvePeriodEnd(BillingCycle cycle, LocalDateTime start,
                                           LocalDateTime explicitEnd, OrgSubscription plan) {
        if (explicitEnd != null) {
            return explicitEnd;
        }
        LocalDateTime derived = cycle.advance(start);
        if (derived != null) {
            return derived;
        }
        if (cycle == BillingCycle.ONE_TIME && plan.getTrialDays() != null && plan.getTrialDays() > 0) {
            // The pilot is one-time but genuinely time-boxed, so its trial length is the term.
            return start.plusDays(plan.getTrialDays());
        }
        throw new BadRequestException(String.format(
                "A %s term needs an explicit end date — it cannot be derived from the billing cycle.",
                cycle.getLabel().toLowerCase()));
    }

    /**
     * Copies recurring add-ons onto a new term. One-off purchases are not carried over:
     * a credit pack or a single custom report was bought once, and re-billing it every
     * renewal would be wrong.
     */
    private void carryOverRecurringAddons(OrgSubscriptionInstance from,
                                          OrgSubscriptionInstance to, String actor) {
        List<OrgSubscriptionAddon> existing = addonRepository
                .findBySubscriptionInstanceIdAndStatus(from.getId(), OrgSubscriptionAddon.STATUS_ACTIVE);
        for (OrgSubscriptionAddon addon : existing) {
            if (addon.getPricingModel() == null || !addon.getPricingModel().isRecurring()) {
                continue;
            }
            OrgSubscriptionAddon copy = new OrgSubscriptionAddon();
            copy.setOrganizationId(addon.getOrganizationId());
            copy.setSubscriptionInstanceId(to.getId());
            copy.setAddonId(addon.getAddonId());
            copy.setAddonCode(addon.getAddonCode());
            copy.setAddonName(addon.getAddonName());
            copy.setQty(addon.getQty());
            // The agreed unit price carries across, so a renewal cannot quietly reprice
            // an add-on the customer already negotiated.
            copy.setUnitPrice(addon.getUnitPrice());
            copy.setUnitLabel(addon.getUnitLabel());
            copy.setPricingModel(addon.getPricingModel());
            copy.setIncrementsLimitKey(addon.getIncrementsLimitKey());
            copy.setGrantsEntitlementKey(addon.getGrantsEntitlementKey());
            copy.setBillingPeriod(addon.getBillingPeriod());
            copy.setStatus(OrgSubscriptionAddon.STATUS_ACTIVE);
            copy.setEffectiveFrom(to.getPeriodStart());
            copy.setHsnSacCode(addon.getHsnSacCode());
            copy.setGstRatePct(addon.getGstRatePct());
            copy.setApprovedBy(actor);
            copy.setApprovedAt(LocalDateTime.now());
            copy.setNotes("Carried over from the previous term.");
            addonRepository.save(copy);

            addon.setStatus(OrgSubscriptionAddon.STATUS_CANCELLED);
            addon.setEffectiveTo(from.getPeriodEnd() != null ? from.getPeriodEnd() : LocalDateTime.now());
            addonRepository.save(addon);
        }
    }

    private Map<LimitKey, Long> parseOverrides(String json) {
        Map<String, Object> raw = JsonUtils.readMap(json);
        Map<LimitKey, Long> out = new LinkedHashMap<>();
        raw.forEach((key, value) -> {
            LimitKey limitKey = LimitKey.fromKey(key);
            if (limitKey != null) {
                Long parsed = JsonUtils.getLong(raw, key, null);
                out.put(limitKey, parsed != null && parsed < 0 ? null : parsed);
            }
        });
        return out;
    }

    /** True when the agreed price differs from the plan's current list price. */
    private boolean isNegotiatedPrice(OrgSubscriptionInstance instance) {
        if (instance.getUnitPrice() == null) {
            return false;
        }
        return planService.getByCode(instance.getPlanCode())
                .map(plan -> {
                    BigDecimal list = plan.priceFor(instance.getBillingCycle().name());
                    return list == null || list.compareTo(instance.getUnitPrice()) != 0;
                })
                .orElse(true);
    }

    private OrgSubscriptionInstance requireCurrent(Long organizationId) {
        return findCurrent(organizationId)
                .orElseThrow(() -> new BadRequestException(ErrorCode.SUBSCRIPTION_MISSING,
                        "This organization has no active subscription."));
    }

    private BillingEventType eventTypeFor(SubscriptionChangeReason reason) {
        return switch (reason) {
            case UPGRADE -> BillingEventType.UPGRADED;
            case DOWNGRADE -> BillingEventType.DOWNGRADED;
            case RENEWAL -> BillingEventType.RENEWED;
            case REACTIVATION -> BillingEventType.REACTIVATED;
            case CYCLE_CHANGE -> BillingEventType.CYCLE_CHANGED;
            case PILOT_CONVERSION -> BillingEventType.PILOT_CONVERTED;
            default -> BillingEventType.SUBSCRIBED;
        };
    }

    private String detailOf(OrgSubscriptionInstance instance) {
        Map<String, Object> detail = new LinkedHashMap<>();
        detail.put("planCode", instance.getPlanCode());
        detail.put("billingCycle", instance.getBillingCycle().name());
        detail.put("unitPrice", instance.getUnitPrice());
        detail.put("periodStart", String.valueOf(instance.getPeriodStart()));
        detail.put("periodEnd", String.valueOf(instance.getPeriodEnd()));
        detail.put("limits", JsonUtils.readMap(instance.getLimitsSnapshot()));
        return JsonUtils.write(detail);
    }

    public void recordEvent(Long organizationId, Long instanceId, BillingEventType type,
                            SubscriptionStatus from, SubscriptionStatus to,
                            String actor, String summary, String detail) {
        OrgBillingEvent event = OrgBillingEvent.of(organizationId, instanceId, type, actor, summary);
        event.setFromStatus(from);
        event.setToStatus(to);
        event.setDetail(detail);
        eventRepository.save(event);
    }

    private String combineNotes(String a, String b) {
        if (a == null || a.isBlank()) {
            return b;
        }
        if (b == null || b.isBlank()) {
            return a;
        }
        return a + " " + b;
    }

    private String orEmpty(String s) {
        return s != null ? s : "";
    }
}
