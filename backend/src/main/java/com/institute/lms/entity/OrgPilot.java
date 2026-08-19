package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * A paid, assisted pilot.
 *
 * <p>The commercial shape matters more than the fields. At 15,000–30,000 for setup,
 * faculty onboarding, data import, configuration, support and a usage review — 15–25
 * person-hours of real work — the pilot is at or below cost. It only makes sense as
 * customer acquisition if it converts, so two things are modelled explicitly: a
 * {@link #decisionDueOn} the academy has agreed to, and the fee credited in full
 * against the first annual invoice on conversion.
 *
 * <p>The credit is a real {@link OrgCreditNote}, not a silent discount, so both the
 * pilot revenue and the credit appear in the books and the customer can see the
 * arithmetic.
 *
 * <p>Conversion never touches tenant data. The organization, its students, courses and
 * history all already exist — converting only starts a new subscription term against
 * the same organization, so nothing is migrated and nothing can be lost.
 */
@Entity
@Table(name = "org_pilots")
@Data
@NoArgsConstructor
public class OrgPilot {

    public static final String STATUS_ACTIVE = "ACTIVE";
    public static final String STATUS_CONVERTED = "CONVERTED";
    public static final String STATUS_LAPSED = "LAPSED";
    public static final String STATUS_EXTENDED = "EXTENDED";
    public static final String STATUS_CANCELLED = "CANCELLED";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "organization_id", nullable = false)
    private Long organizationId;

    @Column(name = "subscription_instance_id")
    private Long subscriptionInstanceId;

    @Column(name = "pilot_fee", nullable = false)
    private BigDecimal pilotFee = new BigDecimal("25000");

    @Column(nullable = false, length = 3)
    private String currency = "INR";

    @Column(name = "starts_on", nullable = false)
    private LocalDate startsOn = LocalDate.now();

    @Column(name = "ends_on", nullable = false)
    private LocalDate endsOn;

    /**
     * The date the academy must decide by. Without one a pilot drifts, and 90 days is
     * long enough to run a full batch and leave.
     */
    @Column(name = "decision_due_on")
    private LocalDate decisionDueOn;

    @Column(nullable = false, length = 20)
    private String status = STATUS_ACTIVE;

    @Column(name = "fee_invoice_id")
    private Long feeInvoiceId;

    /** True once the fee has been credited against the converted subscription. */
    @Column(name = "fee_credited", nullable = false)
    private Boolean feeCredited = false;

    @Column(name = "credit_note_id")
    private Long creditNoteId;

    @Column(name = "converted_instance_id")
    private Long convertedInstanceId;

    @Column(name = "converted_at")
    private LocalDateTime convertedAt;

    // ---- Agreed scope of the pilot -------------------------------------

    @Column(name = "scope_notes", columnDefinition = "TEXT")
    private String scopeNotes;

    @Column(name = "students_to_import")
    private Integer studentsToImport;

    @Column(name = "courses_to_import")
    private Integer coursesToImport;

    @Column(name = "faculty_to_onboard")
    private Integer facultyToOnboard;

    @Column(name = "support_terms", columnDefinition = "TEXT")
    private String supportTerms;

    @Column(length = 160)
    private String owner;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @Column(name = "created_by")
    private String createdBy;

    @Transient
    public boolean isActive() {
        return STATUS_ACTIVE.equals(status) || STATUS_EXTENDED.equals(status);
    }

    /** Days until the pilot ends; negative once past. */
    @Transient
    public long getDaysRemaining() {
        return java.time.temporal.ChronoUnit.DAYS.between(LocalDate.now(), endsOn);
    }

    @Transient
    public boolean isDecisionOverdue() {
        return isActive() && decisionDueOn != null && decisionDueOn.isBefore(LocalDate.now());
    }

    @PrePersist
    public void prePersist() {
        if (createdAt == null) createdAt = LocalDateTime.now();
        if (updatedAt == null) updatedAt = LocalDateTime.now();
        if (startsOn == null) startsOn = LocalDate.now();
        // Default to 60 days rather than 90: the shorter window is what keeps a
        // below-cost pilot commercially viable.
        if (endsOn == null) endsOn = startsOn.plusDays(60);
        // Decide a week before the pilot ends, so conversion is arranged before access
        // lapses rather than after.
        if (decisionDueOn == null) decisionDueOn = endsOn.minusDays(7);
        applyDefaults();
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = LocalDateTime.now();
        applyDefaults();
    }

    private void applyDefaults() {
        if (currency == null) currency = "INR";
        if (status == null) status = STATUS_ACTIVE;
        if (pilotFee == null) pilotFee = new BigDecimal("25000");
        if (feeCredited == null) feeCredited = false;
    }
}
