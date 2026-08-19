package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * A trainer-delivery agreement with an academy.
 *
 * <p>Four charging models are supported, and each fails differently without a written
 * scope — so subjects, batches, class size, sessions, preparation time, assessments,
 * faculty hours and the replacement policy are fields here rather than prose in a
 * document nobody can query.
 *
 * <p>Revenue share carries extra guards, enforced both here and by database check
 * constraints. A share of the academy's fee income cannot be computed unless their
 * collections run through this platform — and no payment gateway is integrated at all
 * today — so the model requires an explicit revenue base definition, confirmation that
 * collections flow through us, and a minimum guarantee so trainers are not funded for a
 * programme that fails to enrol.
 */
@Entity
@Table(name = "org_training_agreements")
@Data
@NoArgsConstructor
public class OrgTrainingAgreement {

    public static final String MODEL_PER_STUDENT_PROGRAM = "PER_STUDENT_PROGRAM";
    public static final String MODEL_PER_FACULTY_HOUR = "PER_FACULTY_HOUR";
    public static final String MODEL_MONTHLY_RETAINER = "MONTHLY_RETAINER";
    public static final String MODEL_REVENUE_SHARE = "REVENUE_SHARE";

    public static final String STATUS_DRAFT = "DRAFT";
    public static final String STATUS_ACTIVE = "ACTIVE";
    public static final String STATUS_COMPLETED = "COMPLETED";
    public static final String STATUS_TERMINATED = "TERMINATED";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "organization_id", nullable = false)
    private Long organizationId;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(name = "billing_model", nullable = false, length = 30)
    private String billingModel;

    @Column(nullable = false, length = 3)
    private String currency = "INR";

    /** PER_STUDENT_PROGRAM: 1,500–4,000 per student per programme. */
    @Column(name = "rate_per_student")
    private BigDecimal ratePerStudent;

    /** PER_FACULTY_HOUR: 1,500–4,000 per hour. */
    @Column(name = "rate_per_hour")
    private BigDecimal ratePerHour;

    /** MONTHLY_RETAINER: 75,000–2,00,000. */
    @Column(name = "retainer_amount")
    private BigDecimal retainerAmount;

    /**
     * Hours the retainer covers. A retainer without a stated hour count cannot be
     * billed or defended, so both are required before the agreement leaves draft.
     */
    @Column(name = "retainer_included_hours")
    private BigDecimal retainerIncludedHours;

    /** REVENUE_SHARE: 15–30%. */
    @Column(name = "revenue_share_pct")
    private BigDecimal revenueSharePct;

    /**
     * Exactly what the percentage applies to, e.g. "gross programme fees collected, net
     * of taxes and refunds". Mandatory for revenue share — without it the share is
     * unarguable in either direction.
     */
    @Column(name = "revenue_base_definition", columnDefinition = "TEXT")
    private String revenueBaseDefinition;

    /**
     * Whether the academy's fee collection actually runs through this platform. Revenue
     * share is unverifiable otherwise, and there is no gateway integrated today.
     */
    @Column(name = "collections_through_platform", nullable = false)
    private Boolean collectionsThroughPlatform = false;

    /** Floor payable regardless of enrolment. */
    @Column(name = "minimum_guarantee")
    private BigDecimal minimumGuarantee;

    // ---- Scope. Each field exists because its absence causes a dispute. ----

    /** JSON array of subject names. */
    @Column(columnDefinition = "TEXT")
    private String subjects;

    /** JSON array of batch names or ids. */
    @Column(columnDefinition = "TEXT")
    private String batches;

    @Column(name = "class_size")
    private Integer classSize;

    @Column(name = "sessions_count")
    private Integer sessionsCount;

    @Column(name = "session_duration_minutes")
    private Integer sessionDurationMinutes;

    @Column(name = "prep_time_hours")
    private BigDecimal prepTimeHours;

    @Column(name = "assessments_count")
    private Integer assessmentsCount;

    @Column(name = "faculty_hours_committed")
    private BigDecimal facultyHoursCommitted;

    /** How quickly a trainer is replaced, and at whose cost. */
    @Column(name = "replacement_policy", columnDefinition = "TEXT", nullable = false)
    private String replacementPolicy = "";

    @Column(name = "starts_on")
    private LocalDate startsOn;

    @Column(name = "ends_on")
    private LocalDate endsOn;

    @Column(nullable = false, length = 20)
    private String status = STATUS_DRAFT;

    /** SAC 999293 — commercial training and coaching, distinct from the SaaS code. */
    @Column(name = "hsn_sac_code", length = 10)
    private String hsnSacCode = "999293";

    @Column(name = "gst_rate_pct", nullable = false)
    private BigDecimal gstRatePct = new BigDecimal("18.00");

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @Column(name = "created_by")
    private String createdBy;

    /**
     * Why this agreement cannot go live yet, or null when it is ready.
     *
     * <p>Mirrors the database check constraints, so the UI can explain the problem
     * instead of surfacing a constraint violation.
     */
    @Transient
    public String activationBlocker() {
        if (replacementPolicy == null || replacementPolicy.isBlank()) {
            return "State the faculty replacement policy — what happens when a trainer "
                    + "is unavailable, and at whose cost.";
        }
        if (MODEL_REVENUE_SHARE.equals(billingModel)) {
            if (revenueSharePct == null) {
                return "Set the revenue share percentage.";
            }
            if (revenueBaseDefinition == null || revenueBaseDefinition.isBlank()) {
                return "Define the revenue base precisely — what the percentage applies to, "
                        + "and what is excluded.";
            }
            if (!Boolean.TRUE.equals(collectionsThroughPlatform)) {
                return "Revenue share can only be offered when the academy's fee collection runs "
                        + "through the platform. Otherwise there is nothing to measure the share against.";
            }
        }
        if (MODEL_MONTHLY_RETAINER.equals(billingModel)
                && (retainerAmount == null || retainerIncludedHours == null)) {
            return "A retainer needs both an amount and the number of hours it covers.";
        }
        if (MODEL_PER_FACULTY_HOUR.equals(billingModel) && ratePerHour == null) {
            return "Set the hourly rate.";
        }
        if (MODEL_PER_STUDENT_PROGRAM.equals(billingModel) && ratePerStudent == null) {
            return "Set the per-student rate.";
        }
        return null;
    }

    @PrePersist
    public void prePersist() {
        if (createdAt == null) createdAt = LocalDateTime.now();
        if (updatedAt == null) updatedAt = LocalDateTime.now();
        applyDefaults();
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = LocalDateTime.now();
        applyDefaults();
    }

    private void applyDefaults() {
        if (currency == null) currency = "INR";
        if (status == null) status = STATUS_DRAFT;
        if (replacementPolicy == null) replacementPolicy = "";
        if (hsnSacCode == null) hsnSacCode = "999293";
        if (gstRatePct == null) gstRatePct = new BigDecimal("18.00");
        if (collectionsThroughPlatform == null) collectionsThroughPlatform = false;
    }
}
