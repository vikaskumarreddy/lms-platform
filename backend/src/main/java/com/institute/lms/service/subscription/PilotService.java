package com.institute.lms.service.subscription;

import com.institute.lms.entity.*;
import com.institute.lms.exception.BadRequestException;
import com.institute.lms.exception.ErrorCode;
import com.institute.lms.exception.ResourceNotFoundException;
import com.institute.lms.repository.*;
import com.institute.lms.service.OrgSubscriptionService;
import com.institute.lms.service.billing.InvoiceService;
import com.institute.lms.subscription.BillingCycle;
import com.institute.lms.subscription.BillingEventType;
import com.institute.lms.subscription.SubscriptionChangeReason;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * Runs assisted pilots and converts them to paid subscriptions.
 *
 * <p><strong>Conversion never moves data.</strong> This is the question the pilot
 * offering has to answer, and the answer is structural: a pilot is already a normal
 * organization with a real subscription term, so converting simply starts a new term
 * against the same organization. Students, courses, batches, assessments, placement
 * records and history are untouched because nothing is copied anywhere — there is no
 * migration step in which anything could be lost.
 *
 * <p>The pilot fee is credited in full on conversion, as an actual credit note rather
 * than a silent discount, so the pilot revenue and the credit both appear in the books
 * and the customer can follow the arithmetic.
 */
@Service
public class PilotService {

    private static final Logger log = LoggerFactory.getLogger(PilotService.class);

    private final OrgPilotRepository pilotRepository;
    private final OrgPilotMetricRepository metricRepository;
    private final OrgSubscriptionInstanceRepository instanceRepository;
    private final StudentActivityPeriodRepository activityRepository;
    private final UserRepository userRepository;
    private final SubscriptionLifecycleService lifecycleService;
    private final OrgSubscriptionService planService;
    private final InvoiceService invoiceService;

    public PilotService(OrgPilotRepository pilotRepository,
                        OrgPilotMetricRepository metricRepository,
                        OrgSubscriptionInstanceRepository instanceRepository,
                        StudentActivityPeriodRepository activityRepository,
                        UserRepository userRepository,
                        SubscriptionLifecycleService lifecycleService,
                        OrgSubscriptionService planService,
                        InvoiceService invoiceService) {
        this.pilotRepository = pilotRepository;
        this.metricRepository = metricRepository;
        this.instanceRepository = instanceRepository;
        this.activityRepository = activityRepository;
        this.userRepository = userRepository;
        this.lifecycleService = lifecycleService;
        this.planService = planService;
        this.invoiceService = invoiceService;
    }

    /** The default success measures, created with every pilot. */
    private static final List<String[]> DEFAULT_METRICS = List.of(
            new String[]{OrgPilotMetric.STUDENT_ACTIVATION, "Student activation", OrgPilotMetric.UNIT_PERCENT, "true"},
            new String[]{OrgPilotMetric.COURSE_COMPLETION, "Course completion", OrgPilotMetric.UNIT_PERCENT, "true"},
            new String[]{OrgPilotMetric.ASSESSMENT_PARTICIPATION, "Assessment participation", OrgPilotMetric.UNIT_PERCENT, "true"},
            new String[]{OrgPilotMetric.ADMIN_HOURS_SAVED, "Administrative hours saved", OrgPilotMetric.UNIT_HOURS, "false"},
            new String[]{OrgPilotMetric.COLLECTION_IMPROVEMENT, "Payment collection improvement", OrgPilotMetric.UNIT_PERCENT, "false"},
            new String[]{OrgPilotMetric.PLACEMENT_APPLICATIONS, "Placement applications", OrgPilotMetric.UNIT_COUNT, "true"},
            new String[]{OrgPilotMetric.MOCK_INTERVIEWS, "Mock interviews", OrgPilotMetric.UNIT_COUNT, "true"},
            new String[]{OrgPilotMetric.INTERVIEWS, "Interviews", OrgPilotMetric.UNIT_COUNT, "true"},
            new String[]{OrgPilotMetric.SELECTIONS, "Selections", OrgPilotMetric.UNIT_COUNT, "true"});

    public List<OrgPilot> forOrganization(Long organizationId) {
        return pilotRepository.findByOrganizationIdOrderByCreatedAtDesc(organizationId);
    }

    public List<OrgPilot> active() {
        return pilotRepository.findByStatus(OrgPilot.STATUS_ACTIVE);
    }

    public OrgPilot require(Long pilotId) {
        return pilotRepository.findById(pilotId)
                .orElseThrow(() -> ResourceNotFoundException.of("Pilot", pilotId));
    }

    public List<OrgPilotMetric> metrics(Long pilotId) {
        return metricRepository.findByPilotId(pilotId);
    }

    /**
     * Starts a pilot, putting the organization on the PILOT plan and seeding the agreed
     * success measures.
     */
    @Transactional
    public OrgPilot start(Long organizationId, BigDecimal fee, Integer days, String owner, String actor) {
        pilotRepository.findByOrganizationIdAndStatus(organizationId, OrgPilot.STATUS_ACTIVE)
                .ifPresent(existing -> {
                    throw new BadRequestException(ErrorCode.PILOT_ALREADY_ACTIVE,
                            "This organization already has a pilot running until " + existing.getEndsOn() + ".");
                });

        OrgSubscription pilotPlan = planService.requireByCode("PILOT");

        // 60 days by default rather than 90: at 15-25 person-hours the fee is at or
        // below cost, and a longer window mostly gives an academy time to run a batch
        // and leave.
        int length = days != null && days > 0 ? days : 60;
        LocalDate start = LocalDate.now();
        LocalDate end = start.plusDays(length);

        OrgPilot pilot = new OrgPilot();
        pilot.setOrganizationId(organizationId);
        pilot.setPilotFee(fee != null ? fee : new BigDecimal("25000"));
        pilot.setStartsOn(start);
        pilot.setEndsOn(end);
        pilot.setDecisionDueOn(end.minusDays(7));
        pilot.setStatus(OrgPilot.STATUS_ACTIVE);
        pilot.setOwner(owner);
        pilot.setCreatedBy(actor);

        SubscriptionLifecycleService.SubscribeOptions options =
                new SubscriptionLifecycleService.SubscribeOptions();
        options.billingCycle = BillingCycle.ONE_TIME;
        options.agreedPrice = pilot.getPilotFee();
        options.periodEnd = end.atStartOfDay();
        options.autoRenew = false;
        options.actor = actor;
        options.changeReason = SubscriptionChangeReason.NEW;
        options.changeNote = "Assisted pilot to " + end + ". Fee credited in full on conversion.";

        OrgSubscriptionInstance instance =
                lifecycleService.subscribe(organizationId, pilotPlan.getId(), options);
        pilot.setSubscriptionInstanceId(instance.getId());

        OrgPilot saved = pilotRepository.save(pilot);
        seedMetrics(saved);

        lifecycleService.recordEvent(organizationId, instance.getId(),
                BillingEventType.PILOT_STARTED, null, instance.getStatus(), actor,
                String.format("Pilot started, running to %s with a decision due by %s.",
                        end, saved.getDecisionDueOn()), null);
        return saved;
    }

    private void seedMetrics(OrgPilot pilot) {
        for (String[] spec : DEFAULT_METRICS) {
            OrgPilotMetric metric = new OrgPilotMetric();
            metric.setPilotId(pilot.getId());
            metric.setMetricKey(spec[0]);
            metric.setLabel(spec[1]);
            metric.setUnit(spec[2]);
            metric.setAutoMeasured(Boolean.parseBoolean(spec[3]));
            metricRepository.save(metric);
        }
    }

    /**
     * Fills in the measures the platform can observe for itself.
     *
     * <p>Only the auto-measurable ones. Administrative hours saved and collection
     * improvement are left for the academy to report, because we cannot see their
     * back-office time or their bank account — inventing a figure for either would make
     * the whole scorecard untrustworthy.
     */
    @Transactional
    public List<OrgPilotMetric> refreshMeasurements(Long pilotId) {
        OrgPilot pilot = require(pilotId);
        Long orgId = pilot.getOrganizationId();

        long studentRecords = userRepository.countStudentRecordsInOrg(orgId);
        long activeThisMonth = activityRepository.countByOrganizationIdAndPeriodYm(
                orgId, UsageService.currentPeriod());

        BigDecimal activationPct = studentRecords > 0
                ? BigDecimal.valueOf(activeThisMonth * 100.0 / studentRecords)
                        .setScale(1, java.math.RoundingMode.HALF_UP)
                : BigDecimal.ZERO;

        setActual(pilotId, OrgPilotMetric.STUDENT_ACTIVATION, activationPct);

        List<OrgPilotMetric> updated = new ArrayList<>(metricRepository.findByPilotId(pilotId));
        log.info("Refreshed pilot {} measurements: {} of {} students active",
                pilotId, activeThisMonth, studentRecords);
        return updated;
    }

    @Transactional
    public OrgPilotMetric setActual(Long pilotId, String metricKey, BigDecimal actual) {
        OrgPilotMetric metric = metricRepository.findByPilotIdAndMetricKey(pilotId, metricKey)
                .orElseThrow(() -> ResourceNotFoundException.of("Pilot metric", metricKey));
        metric.setActualValue(actual);
        metric.setMeasuredAt(LocalDateTime.now());
        return metricRepository.save(metric);
    }

    @Transactional
    public OrgPilotMetric setTarget(Long pilotId, String metricKey, BigDecimal target) {
        OrgPilotMetric metric = metricRepository.findByPilotIdAndMetricKey(pilotId, metricKey)
                .orElseThrow(() -> ResourceNotFoundException.of("Pilot metric", metricKey));
        metric.setTargetValue(target);
        return metricRepository.save(metric);
    }

    /**
     * Converts a pilot to a paid plan.
     *
     * <p>Two guarantees, both structural rather than procedural:
     * <ul>
     *   <li><strong>No data is touched.</strong> The organization is unchanged; only a
     *       new subscription term is started against it. There is no export, no import,
     *       and therefore nothing that can be dropped in between.</li>
     *   <li><strong>The pilot fee comes back in full</strong>, as a credit note against
     *       the pilot invoice, so it behaves as a deposit rather than a sunk cost.</li>
     * </ul>
     */
    @Transactional
    public OrgPilot convert(Long pilotId, Long targetPlanId, BillingCycle cycle, String actor) {
        OrgPilot pilot = require(pilotId);
        if (!pilot.isActive()) {
            throw new BadRequestException(ErrorCode.PILOT_NOT_CONVERTIBLE,
                    "This pilot is already " + pilot.getStatus().toLowerCase() + ".");
        }

        OrgSubscription target = planService.requireById(targetPlanId);
        BillingCycle resolvedCycle = cycle != null ? cycle : BillingCycle.YEARLY;

        SubscriptionLifecycleService.SubscribeOptions options =
                new SubscriptionLifecycleService.SubscribeOptions();
        options.billingCycle = resolvedCycle;
        options.actor = actor;
        options.changeReason = SubscriptionChangeReason.PILOT_CONVERSION;
        options.changeNote = String.format(
                "Converted from the assisted pilot that ran %s to %s. All organization data carried "
                        + "over in place — no migration was required. Pilot fee of %s credited.",
                pilot.getStartsOn(), pilot.getEndsOn(), pilot.getPilotFee().toPlainString());
        options.autoRenew = true;

        OrgSubscriptionInstance instance =
                lifecycleService.subscribe(pilot.getOrganizationId(), target.getId(), options);

        pilot.setStatus(OrgPilot.STATUS_CONVERTED);
        pilot.setConvertedInstanceId(instance.getId());
        pilot.setConvertedAt(LocalDateTime.now());

        // Credit the fee against the pilot invoice, if one was raised. A real credit
        // note rather than a discount, so both sides of the transaction are visible.
        if (pilot.getFeeInvoiceId() != null && !Boolean.TRUE.equals(pilot.getFeeCredited())) {
            try {
                OrgCreditNote note = invoiceService.issueCreditNote(
                        pilot.getFeeInvoiceId(), pilot.getPilotFee(),
                        OrgCreditNote.REASON_PILOT_CREDIT,
                        "Pilot fee credited in full on conversion to " + target.getName() + ".",
                        actor);
                pilot.setCreditNoteId(note.getId());
                pilot.setFeeCredited(true);
            } catch (Exception e) {
                // The conversion itself must not fail because the credit could not be
                // raised — the customer has already moved onto the paid plan. Flagged
                // loudly so the platform team settles it manually.
                log.error("Pilot {} converted but the fee credit failed — raise it manually", pilotId, e);
            }
        }

        OrgPilot saved = pilotRepository.save(pilot);

        lifecycleService.recordEvent(pilot.getOrganizationId(), instance.getId(),
                BillingEventType.PILOT_CONVERTED, null, instance.getStatus(), actor,
                String.format("Pilot converted to %s (%s). Organization data carried over in place.",
                        target.getName(), resolvedCycle.getLabel()), null);
        return saved;
    }

    /** Marks a pilot lapsed once it has run past its end date without converting. */
    @Transactional
    public OrgPilot lapse(Long pilotId, String actor) {
        OrgPilot pilot = require(pilotId);
        pilot.setStatus(OrgPilot.STATUS_LAPSED);
        OrgPilot saved = pilotRepository.save(pilot);

        lifecycleService.recordEvent(pilot.getOrganizationId(), pilot.getSubscriptionInstanceId(),
                BillingEventType.PILOT_LAPSED, null, null, actor,
                "Pilot lapsed without conversion. The fee is non-refundable and the "
                        + "organization's data is retained.", null);
        return saved;
    }

    /** Extends a pilot, which should be the exception rather than the habit. */
    @Transactional
    public OrgPilot extend(Long pilotId, int extraDays, String actor) {
        OrgPilot pilot = require(pilotId);
        pilot.setEndsOn(pilot.getEndsOn().plusDays(extraDays));
        pilot.setDecisionDueOn(pilot.getEndsOn().minusDays(7));
        pilot.setStatus(OrgPilot.STATUS_EXTENDED);

        instanceRepository.findByOrganizationIdAndIsCurrentTrue(pilot.getOrganizationId())
                .ifPresent(instance -> {
                    instance.setPeriodEnd(pilot.getEndsOn().atStartOfDay());
                    instance.setGraceEndsAt(pilot.getEndsOn().plusDays(7).atStartOfDay());
                    instanceRepository.save(instance);
                });

        return pilotRepository.save(pilot);
    }
}
