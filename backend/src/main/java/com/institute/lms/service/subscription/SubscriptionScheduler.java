package com.institute.lms.service.subscription;

import com.institute.lms.entity.OrgDunningEvent;
import com.institute.lms.entity.OrgInvoice;
import com.institute.lms.entity.OrgSubscriptionInstance;
import com.institute.lms.entity.OrgUsageSnapshot;
import com.institute.lms.entity.Organization;
import com.institute.lms.repository.OrgSubscriptionInstanceRepository;
import com.institute.lms.repository.OrgUsageSnapshotRepository;
import com.institute.lms.repository.OrganizationRepository;
import com.institute.lms.repository.StudentActivityPeriodRepository;
import com.institute.lms.service.OrgSubscriptionService;
import com.institute.lms.subscription.SubscriptionStatus;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.util.List;

/**
 * Moves subscriptions through their clock-driven transitions and captures monthly
 * usage.
 *
 * <p>Follows the {@code fixedDelay} pattern already used by
 * {@code ReminderSchedulerService}; {@code @EnableScheduling} is on the application
 * class.
 *
 * <p>Note this sweep is a convenience, not the source of truth.
 * {@link OrgSubscriptionInstance#getEffectiveStatus()} derives the correct status from
 * the clock on every read, so a tenant whose term ended is treated as expired the
 * moment it happens — even if this job has not run since. That matters: a sweep-only
 * design means a stopped scheduler silently hands every expired tenant continued full
 * access, and nobody notices until the invoices do not match.
 */
@Service
public class SubscriptionScheduler {

    private static final Logger log = LoggerFactory.getLogger(SubscriptionScheduler.class);

    private static final String ACTOR = "system:scheduler";

    /** Statuses a term can be in while still considered live and therefore expirable. */
    private static final List<SubscriptionStatus> LIVE_STATUSES = List.of(
            SubscriptionStatus.ACTIVE, SubscriptionStatus.TRIALING,
            SubscriptionStatus.PILOT, SubscriptionStatus.PAST_DUE);

    private final OrgSubscriptionInstanceRepository instanceRepository;
    private final OrgUsageSnapshotRepository usageSnapshotRepository;
    private final StudentActivityPeriodRepository activityRepository;
    private final OrganizationRepository organizationRepository;
    private final SubscriptionLifecycleService lifecycleService;
    private final EntitlementService entitlementService;
    private final UsageService usageService;
    private final OrgSubscriptionService planService;
    private final com.institute.lms.service.billing.InvoiceService invoiceService;
    private final com.institute.lms.repository.OrgInvoiceRepository invoiceRepository;
    private final com.institute.lms.repository.OrgDunningEventRepository dunningRepository;
    private final com.institute.lms.repository.SystemConfigRepository systemConfigRepository;

    public SubscriptionScheduler(OrgSubscriptionInstanceRepository instanceRepository,
                                 OrgUsageSnapshotRepository usageSnapshotRepository,
                                 StudentActivityPeriodRepository activityRepository,
                                 OrganizationRepository organizationRepository,
                                 SubscriptionLifecycleService lifecycleService,
                                 EntitlementService entitlementService,
                                 UsageService usageService,
                                 OrgSubscriptionService planService,
                                 com.institute.lms.service.billing.InvoiceService invoiceService,
                                 com.institute.lms.repository.OrgInvoiceRepository invoiceRepository,
                                 com.institute.lms.repository.OrgDunningEventRepository dunningRepository,
                                 com.institute.lms.repository.SystemConfigRepository systemConfigRepository) {
        this.instanceRepository = instanceRepository;
        this.usageSnapshotRepository = usageSnapshotRepository;
        this.activityRepository = activityRepository;
        this.organizationRepository = organizationRepository;
        this.lifecycleService = lifecycleService;
        this.entitlementService = entitlementService;
        this.usageService = usageService;
        this.planService = planService;
        this.invoiceService = invoiceService;
        this.invoiceRepository = invoiceRepository;
        this.dunningRepository = dunningRepository;
        this.systemConfigRepository = systemConfigRepository;
    }

    /**
     * Every 2 hours: flag overdue invoices and escalate dunning.
     *
     * <p>Dunning is off unless {@code billing.dunning.enabled} is set, because sending
     * automated payment chasers to real customers should be a deliberate switch, not
     * something that starts happening because a feature shipped.
     *
     * <p>Marking invoices overdue runs regardless — that is bookkeeping, not messaging,
     * and the platform team needs the ageing view whether or not reminders go out.
     */
    @Scheduled(fixedDelay = 2 * 60 * 60 * 1000, initialDelay = 3 * 60 * 1000)
    public void processDunning() {
        try {
            int flagged = invoiceService.markOverdue();
            if (flagged > 0) {
                log.info("Marked {} invoice(s) overdue.", flagged);
            }
        } catch (Exception e) {
            log.error("Failed to flag overdue invoices", e);
        }

        if (!"true".equalsIgnoreCase(config("billing.dunning.enabled", "false"))) {
            return;
        }

        try {
            for (OrgInvoice invoice : invoiceRepository.findOverdue(java.time.LocalDate.now())) {
                escalate(invoice);
            }
        } catch (Exception e) {
            log.error("Dunning sweep failed", e);
        }
    }

    /**
     * Advances one invoice to its next dunning step.
     *
     * <p>Steps are keyed by type and guarded by a unique index on
     * {@code (invoice_id, event_type)}, so a step fires exactly once per invoice however
     * often the sweep runs — nobody receives the same reminder twice.
     */
    private void escalate(OrgInvoice invoice) {
        long daysOverdue = java.time.temporal.ChronoUnit.DAYS.between(
                invoice.getDueDate(), java.time.LocalDate.now());

        String step;
        if (daysOverdue >= 30) {
            step = OrgDunningEvent.TYPE_SUSPENSION_WARNING;
        } else if (daysOverdue >= 14) {
            step = OrgDunningEvent.TYPE_ESCALATION;
        } else if (daysOverdue >= 1) {
            step = OrgDunningEvent.TYPE_REMINDER_OVERDUE;
        } else {
            return;
        }

        if (dunningRepository.existsByInvoiceIdAndEventType(invoice.getId(), step)) {
            return;
        }

        Organization org = organizationRepository.findById(invoice.getOrganizationId()).orElse(null);

        OrgDunningEvent event = new OrgDunningEvent();
        event.setOrganizationId(invoice.getOrganizationId());
        event.setInvoiceId(invoice.getId());
        event.setEventType(step);
        event.setChannel(OrgDunningEvent.CHANNEL_IN_APP);
        event.setAttemptNo((int) dunningRepository.countByInvoiceId(invoice.getId()) + 1);
        event.setRecipient(org != null ? org.getBillingEmail() : null);
        event.setSubject(String.format("Invoice %s is %d day%s overdue",
                invoice.getInvoiceNumber(), daysOverdue, daysOverdue == 1 ? "" : "s"));
        // Recorded as SENT for the in-app banner, which the tenant genuinely sees. An
        // email channel would need a mail transport that does not exist yet; claiming
        // to have emailed someone when nothing was sent would make the audit trail lie.
        event.setStatus(OrgDunningEvent.STATUS_SENT);
        dunningRepository.save(event);

        lifecycleService.recordEvent(invoice.getOrganizationId(), invoice.getSubscriptionInstanceId(),
                com.institute.lms.subscription.BillingEventType.DUNNING_SENT, null, null, ACTOR,
                event.getSubject(), null);

        log.info("Dunning {} recorded for invoice {} ({} days overdue)",
                step, invoice.getInvoiceNumber(), daysOverdue);
    }

    private String config(String key, String fallback) {
        return systemConfigRepository.findByConfigKey(key)
                .map(com.institute.lms.entity.SystemConfig::getConfigValue)
                .filter(v -> v != null && !v.isBlank())
                .orElse(fallback);
    }

    /**
     * Every 30 minutes: advance terms whose dates have passed.
     *
     * <p>Half-hourly rather than nightly so a tenant who renews shortly after expiring
     * is not left read-only until the next morning.
     */
    @Scheduled(fixedDelay = 30 * 60 * 1000, initialDelay = 60 * 1000)
    public void advanceSubscriptionStates() {
        LocalDateTime now = LocalDateTime.now();
        int changed = 0;

        try {
            // Terms whose paid period has elapsed move into the grace window.
            for (OrgSubscriptionInstance instance : instanceRepository.findDueForExpiry(now, LIVE_STATUSES)) {
                if (lifecycleService.refreshStatus(instance, ACTOR)) {
                    changed++;
                }
            }
            // Terms whose grace window has elapsed drop to read-only.
            for (OrgSubscriptionInstance instance :
                    instanceRepository.findGraceElapsed(now, SubscriptionStatus.GRACE)) {
                if (lifecycleService.refreshStatus(instance, ACTOR)) {
                    changed++;
                }
            }
            // Scheduled cancellations that have come due.
            for (OrgSubscriptionInstance instance : instanceRepository.findByIsCurrentTrue()) {
                if (instance.getCancelAt() != null
                        && instance.getCancelAt().isBefore(now)
                        && instance.getStatus() != SubscriptionStatus.CANCELLED
                        && lifecycleService.refreshStatus(instance, ACTOR)) {
                    changed++;
                }
            }
        } catch (Exception e) {
            // A failing sweep must not take the scheduler thread down permanently; the
            // effective-status fallback keeps enforcement correct meanwhile.
            log.error("Subscription state sweep failed", e);
        }

        if (changed > 0) {
            log.info("Subscription sweep updated {} organization(s).", changed);
        }
    }

    /**
     * Hourly: capture the running usage figure for the current month.
     *
     * <p>Tracks the <em>peak</em> as well as the latest count, because a metric sold as
     * "active students" should bill what the academy actually ran. A tenant who has 400
     * students active for three weeks and 150 on the day the month closes did not use a
     * 150-student plan, and billing the closing figure would undercharge every seasonal
     * customer.
     */
    @Scheduled(fixedDelay = 60 * 60 * 1000, initialDelay = 5 * 60 * 1000)
    public void captureUsage() {
        String period = UsageService.currentPeriod();
        try {
            for (Organization org : organizationRepository.findAll()) {
                captureFor(org, period, false);
            }
        } catch (Exception e) {
            log.error("Usage capture failed for period {}", period, e);
        }
    }

    /**
     * Every 6 hours: close out the previous month once it has ended.
     *
     * <p>Finalising freezes the figures an invoice is raised from. Recomputing at
     * invoice time instead would let a late activity row change an amount that has
     * already been billed.
     */
    @Scheduled(fixedDelay = 6 * 60 * 60 * 1000, initialDelay = 10 * 60 * 1000)
    public void finalisePreviousPeriod() {
        String previous = YearMonth.now().minusMonths(1).format(UsageService.PERIOD_FORMAT);
        try {
            for (Organization org : organizationRepository.findAll()) {
                OrgUsageSnapshot snapshot = usageSnapshotRepository
                        .findByOrganizationIdAndPeriodYm(org.getId(), previous)
                        .orElse(null);
                if (snapshot != null && Boolean.TRUE.equals(snapshot.getIsFinal())) {
                    continue;
                }
                captureFor(org, previous, true);
            }
        } catch (Exception e) {
            log.error("Failed to finalise usage for period {}", previous, e);
        }
    }

    /**
     * Writes or updates one organization's usage rollup for a period.
     *
     * @param finalise when true the figures are frozen for billing
     */
    private void captureFor(Organization org, String period, boolean finalise) {
        long activeStudents = activityRepository.countByOrganizationIdAndPeriodYm(org.getId(), period);

        OrgUsageSnapshot snapshot = usageSnapshotRepository
                .findByOrganizationIdAndPeriodYm(org.getId(), period)
                .orElseGet(() -> {
                    OrgUsageSnapshot fresh = new OrgUsageSnapshot();
                    fresh.setOrganizationId(org.getId());
                    fresh.setPeriodYm(period);
                    return fresh;
                });

        if (Boolean.TRUE.equals(snapshot.getIsFinal())) {
            return; // already closed; never rewrite a billed figure
        }

        int current = (int) activeStudents;
        snapshot.setActiveStudentsEnd(current);
        snapshot.setActiveStudentsPeak(Math.max(
                snapshot.getActiveStudentsPeak() != null ? snapshot.getActiveStudentsPeak() : 0, current));
        snapshot.setFacultyAccounts((int) usageService.facultySeats(org.getId()));
        snapshot.setBranches((int) usageService.branches(org.getId()));
        snapshot.setStorageBytes(org.getStorageBytesUsed() != null ? org.getStorageBytesUsed() : 0L);
        snapshot.setTrainingHoursUsed(usageService.trainingHoursUsed(org.getId(), period));
        snapshot.setCapturedAt(LocalDateTime.now());

        // Record the allowance and overage price in force now, so the charge can still
        // be explained after the tenant changes plan.
        ResolvedEntitlements resolved = entitlementService.resolve(org.getId());
        if (resolved.hasSubscription()) {
            snapshot.setPlanCode(resolved.getPlanCode());
            Long allowance = resolved.limit(com.institute.lms.subscription.LimitKey.MAX_ACTIVE_STUDENTS);
            snapshot.setStudentsAllowance(allowance != null ? allowance.intValue() : null);
            planService.getByCode(resolved.getPlanCode()).ifPresent(plan ->
                    snapshot.setOverageStudentPrice(plan.getOverageStudentPrice()));
        }
        snapshot.recomputeOverage();

        if (finalise) {
            snapshot.setIsFinal(true);
        }
        usageSnapshotRepository.save(snapshot);

        if (finalise && snapshot.getOverageStudents() != null && snapshot.getOverageStudents() > 0) {
            lifecycleService.recordEvent(org.getId(), null,
                    com.institute.lms.subscription.BillingEventType.OVERAGE_RECORDED,
                    null, null, ACTOR,
                    String.format("%s: %d active students over the allowance of %d, %s %s to bill.",
                            period, snapshot.getOverageStudents(), snapshot.getStudentsAllowance(),
                            snapshot.getOverageAmount() != null
                                    ? snapshot.getOverageAmount().toPlainString() : BigDecimal.ZERO.toPlainString(),
                            "INR"),
                    null);
        }
    }
}
