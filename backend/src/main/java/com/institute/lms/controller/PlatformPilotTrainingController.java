package com.institute.lms.controller;

import com.institute.lms.entity.*;
import com.institute.lms.exception.BadRequestException;
import com.institute.lms.service.subscription.PilotService;
import com.institute.lms.service.subscription.TrainingBillingService;
import com.institute.lms.service.subscription.UsageService;
import com.institute.lms.subscription.BillingCycle;
import com.institute.lms.util.JsonUtils;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Platform management of assisted pilots and training agreements. Super-admin only.
 */
@RestController
@RequestMapping("/api/platform")
public class PlatformPilotTrainingController {

    private final PilotService pilotService;
    private final TrainingBillingService trainingService;
    private final UserContext userContext;

    public PlatformPilotTrainingController(PilotService pilotService,
                                           TrainingBillingService trainingService,
                                           UserContext userContext) {
        this.pilotService = pilotService;
        this.trainingService = trainingService;
        this.userContext = userContext;
    }

    // ================= Pilots =================

    @GetMapping("/pilots")
    public List<OrgPilot> activePilots() {
        userContext.requireSuperAdmin();
        return pilotService.active();
    }

    @GetMapping("/pilots/organization/{organizationId}")
    public List<OrgPilot> pilotsFor(@PathVariable Long organizationId) {
        userContext.requireSuperAdmin();
        return pilotService.forOrganization(organizationId);
    }

    /** A pilot with its scorecard, which is what the conversion conversation runs on. */
    @GetMapping("/pilots/{id}")
    public Map<String, Object> pilot(@PathVariable Long id) {
        userContext.requireSuperAdmin();
        OrgPilot pilot = pilotService.require(id);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("pilot", pilot);
        out.put("metrics", pilotService.metrics(id));
        out.put("daysRemaining", pilot.getDaysRemaining());
        out.put("decisionOverdue", pilot.isDecisionOverdue());
        return out;
    }

    @PostMapping("/pilots")
    public ResponseEntity<OrgPilot> startPilot(@RequestBody Map<String, Object> body) {
        userContext.requireSuperAdmin();
        Long organizationId = asLong(body.get("organizationId"));
        if (organizationId == null) {
            throw BadRequestException.field("organizationId", "is required");
        }
        return ResponseEntity.ok(pilotService.start(
                organizationId, decimal(body.get("pilotFee")),
                body.get("days") != null ? asLong(body.get("days")).intValue() : null,
                str(body.get("owner")), actor()));
    }

    /** Recomputes the measures the platform can observe for itself. */
    @PostMapping("/pilots/{id}/refresh-metrics")
    public List<OrgPilotMetric> refreshMetrics(@PathVariable Long id) {
        userContext.requireSuperAdmin();
        return pilotService.refreshMeasurements(id);
    }

    @PutMapping("/pilots/{id}/metrics/{metricKey}")
    public OrgPilotMetric updateMetric(@PathVariable Long id, @PathVariable String metricKey,
                                       @RequestBody Map<String, Object> body) {
        userContext.requireSuperAdmin();
        if (body.containsKey("targetValue")) {
            pilotService.setTarget(id, metricKey, decimal(body.get("targetValue")));
        }
        if (body.containsKey("actualValue")) {
            return pilotService.setActual(id, metricKey, decimal(body.get("actualValue")));
        }
        return pilotService.metrics(id).stream()
                .filter(m -> m.getMetricKey().equals(metricKey))
                .findFirst()
                .orElseThrow(() -> BadRequestException.field("metricKey", "is not on this pilot"));
    }

    /**
     * Converts a pilot to a paid plan.
     *
     * <p>No data moves: the organization already exists with all its students, courses
     * and history, so conversion only starts a new subscription term against it. The
     * pilot fee is credited in full.
     */
    @PostMapping("/pilots/{id}/convert")
    public ResponseEntity<Map<String, Object>> convert(@PathVariable Long id,
                                                       @RequestBody Map<String, Object> body) {
        userContext.requireSuperAdmin();
        Long planId = asLong(body.get("planId"));
        if (planId == null) {
            throw BadRequestException.field("planId", "is required");
        }
        BillingCycle cycle = body.get("billingCycle") != null
                ? BillingCycle.fromName(body.get("billingCycle").toString()) : BillingCycle.YEARLY;

        OrgPilot pilot = pilotService.convert(id, planId, cycle, actor());
        return ResponseEntity.ok(Map.of(
                "pilot", pilot,
                "feeCredited", pilot.getFeeCredited(),
                "message", "Converted. All organization data carried over in place — nothing was migrated."));
    }

    @PostMapping("/pilots/{id}/extend")
    public ResponseEntity<OrgPilot> extend(@PathVariable Long id, @RequestBody Map<String, Object> body) {
        userContext.requireSuperAdmin();
        Long days = asLong(body.get("days"));
        if (days == null || days <= 0) {
            throw BadRequestException.field("days", "must be a positive number");
        }
        return ResponseEntity.ok(pilotService.extend(id, days.intValue(), actor()));
    }

    @PostMapping("/pilots/{id}/lapse")
    public ResponseEntity<OrgPilot> lapse(@PathVariable Long id) {
        userContext.requireSuperAdmin();
        return ResponseEntity.ok(pilotService.lapse(id, actor()));
    }

    // ================= Training agreements =================

    @GetMapping("/training/organization/{organizationId}")
    public List<OrgTrainingAgreement> agreements(@PathVariable Long organizationId) {
        userContext.requireSuperAdmin();
        return trainingService.forOrganization(organizationId);
    }

    @GetMapping("/training/{id}")
    public Map<String, Object> agreement(@PathVariable Long id) {
        userContext.requireSuperAdmin();
        OrgTrainingAgreement agreement = trainingService.require(id);
        String period = UsageService.currentPeriod();

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("agreement", agreement);
        // Surfaced so the UI can explain what is missing instead of the user discovering
        // it when activation fails.
        out.put("activationBlocker", agreement.activationBlocker());
        out.put("worklog", trainingService.worklog(agreement.getOrganizationId(), period));
        out.put("unbilled", trainingService.unbilled(agreement.getOrganizationId(), period));
        return out;
    }

    @PostMapping("/training")
    public ResponseEntity<OrgTrainingAgreement> createAgreement(@RequestBody Map<String, Object> body) {
        userContext.requireSuperAdmin();
        OrgTrainingAgreement agreement = new OrgTrainingAgreement();
        agreement.setCreatedBy(actor());
        applyAgreement(agreement, body);

        if (agreement.getOrganizationId() == null) {
            throw BadRequestException.field("organizationId", "is required");
        }
        if (agreement.getBillingModel() == null) {
            throw BadRequestException.field("billingModel", "is required");
        }
        return ResponseEntity.ok(trainingService.save(agreement));
    }

    @PutMapping("/training/{id}")
    public ResponseEntity<OrgTrainingAgreement> updateAgreement(@PathVariable Long id,
                                                                @RequestBody Map<String, Object> body) {
        userContext.requireSuperAdmin();
        OrgTrainingAgreement agreement = trainingService.require(id);
        applyAgreement(agreement, body);
        return ResponseEntity.ok(trainingService.save(agreement));
    }

    /** Activates an agreement, refusing while its terms are incomplete. */
    @PostMapping("/training/{id}/activate")
    public ResponseEntity<OrgTrainingAgreement> activate(@PathVariable Long id) {
        userContext.requireSuperAdmin();
        return ResponseEntity.ok(trainingService.activate(id));
    }

    /** Logs delivered hours, which draw down the plan's included allowance first. */
    @PostMapping("/training/{id}/worklog")
    public ResponseEntity<OrgTrainingWorklog> logWork(@PathVariable Long id,
                                                      @RequestBody Map<String, Object> body) {
        userContext.requireSuperAdmin();
        OrgTrainingWorklog entry = new OrgTrainingWorklog();
        entry.setAgreementId(id);
        entry.setHours(decimal(body.get("hours")));
        entry.setFacultyUserId(asLong(body.get("facultyUserId")));
        entry.setFacultyName(str(body.get("facultyName")));
        entry.setBatchId(asLong(body.get("batchId")));
        entry.setSubject(str(body.get("subject")));
        entry.setNotes(str(body.get("notes")));
        entry.setCreatedBy(actor());
        if (body.get("sessionType") != null) {
            entry.setSessionType(body.get("sessionType").toString());
        }
        if (body.get("workDate") != null) {
            entry.setWorkDate(LocalDate.parse(body.get("workDate").toString()));
        }
        if (body.get("studentsCount") != null) {
            entry.setStudentsCount(asLong(body.get("studentsCount")).intValue());
        }
        return ResponseEntity.ok(trainingService.logWork(entry));
    }

    /**
     * How a month's hours split between the plan's included allowance and what is
     * chargeable — the figure that stops the base fee and the hourly rate billing for
     * the same work.
     */
    @GetMapping("/training/{id}/billable")
    public Map<String, Object> billable(@PathVariable Long id,
                                        @RequestParam(required = false) String period,
                                        @RequestParam(required = false) BigDecimal includedAllowance) {
        userContext.requireSuperAdmin();
        OrgTrainingAgreement agreement = trainingService.require(id);
        String periodYm = period != null ? period : UsageService.currentPeriod();
        BigDecimal allowance = includedAllowance != null ? includedAllowance : BigDecimal.ZERO;

        TrainingBillingService.HourSplit split =
                trainingService.billableHours(agreement.getOrganizationId(), periodYm, allowance);

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("period", periodYm);
        out.put("deliveredHours", split.delivered());
        out.put("includedHoursUsed", split.included());
        out.put("chargeableHours", split.chargeable());
        out.put("chargeableAmount", trainingService.chargeableAmount(agreement, periodYm, allowance));
        return out;
    }

    // ================= Helpers =================

    private void applyAgreement(OrgTrainingAgreement a, Map<String, Object> body) {
        if (body.containsKey("organizationId")) a.setOrganizationId(asLong(body.get("organizationId")));
        if (body.containsKey("title")) a.setTitle(str(body.get("title")));
        if (body.containsKey("billingModel")) a.setBillingModel(str(body.get("billingModel")));
        if (body.containsKey("ratePerStudent")) a.setRatePerStudent(decimal(body.get("ratePerStudent")));
        if (body.containsKey("ratePerHour")) a.setRatePerHour(decimal(body.get("ratePerHour")));
        if (body.containsKey("retainerAmount")) a.setRetainerAmount(decimal(body.get("retainerAmount")));
        if (body.containsKey("retainerIncludedHours")) {
            a.setRetainerIncludedHours(decimal(body.get("retainerIncludedHours")));
        }
        if (body.containsKey("revenueSharePct")) a.setRevenueSharePct(decimal(body.get("revenueSharePct")));
        if (body.containsKey("revenueBaseDefinition")) {
            a.setRevenueBaseDefinition(str(body.get("revenueBaseDefinition")));
        }
        if (body.containsKey("collectionsThroughPlatform")) {
            a.setCollectionsThroughPlatform(
                    Boolean.parseBoolean(String.valueOf(body.get("collectionsThroughPlatform"))));
        }
        if (body.containsKey("minimumGuarantee")) a.setMinimumGuarantee(decimal(body.get("minimumGuarantee")));

        if (body.containsKey("subjects")) a.setSubjects(jsonArray(body.get("subjects")));
        if (body.containsKey("batches")) a.setBatches(jsonArray(body.get("batches")));
        if (body.containsKey("classSize")) a.setClassSize(intOf(body.get("classSize")));
        if (body.containsKey("sessionsCount")) a.setSessionsCount(intOf(body.get("sessionsCount")));
        if (body.containsKey("sessionDurationMinutes")) {
            a.setSessionDurationMinutes(intOf(body.get("sessionDurationMinutes")));
        }
        if (body.containsKey("prepTimeHours")) a.setPrepTimeHours(decimal(body.get("prepTimeHours")));
        if (body.containsKey("assessmentsCount")) a.setAssessmentsCount(intOf(body.get("assessmentsCount")));
        if (body.containsKey("facultyHoursCommitted")) {
            a.setFacultyHoursCommitted(decimal(body.get("facultyHoursCommitted")));
        }
        if (body.containsKey("replacementPolicy")) a.setReplacementPolicy(str(body.get("replacementPolicy")));
        if (body.get("startsOn") != null) a.setStartsOn(LocalDate.parse(body.get("startsOn").toString()));
        if (body.get("endsOn") != null) a.setEndsOn(LocalDate.parse(body.get("endsOn").toString()));
        if (body.containsKey("notes")) a.setNotes(str(body.get("notes")));
    }

    private String jsonArray(Object value) {
        if (value == null) {
            return null;
        }
        return value instanceof List<?> ? JsonUtils.write(value) : value.toString();
    }

    private String actor() {
        User user = userContext.currentUser();
        return user != null ? user.getEmail() : "platform-admin";
    }

    private String str(Object value) {
        return value != null ? value.toString() : null;
    }

    private Long asLong(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Number n) {
            return n.longValue();
        }
        try {
            return Long.parseLong(value.toString().trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private Integer intOf(Object value) {
        Long parsed = asLong(value);
        return parsed != null ? parsed.intValue() : null;
    }

    private BigDecimal decimal(Object value) {
        if (value == null) {
            return null;
        }
        try {
            return new BigDecimal(value.toString().trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
