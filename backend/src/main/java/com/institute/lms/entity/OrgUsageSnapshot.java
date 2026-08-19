package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * A tenant's measured usage for one billing month — the figures an invoice is raised
 * from.
 *
 * <p>Deliberately separate from {@link StudentActivityPeriod}: an invoice needs one
 * agreed number, frozen when the period closes ({@link #isFinal}). Recomputing from
 * the ledger at invoice time would let a late-arriving activity row change a figure
 * that has already been billed and paid.
 *
 * <p>Both a peak and an end-of-period student count are kept. Peak is the honest basis
 * for a metric sold as "active students" — a tenant running 400 students for three
 * weeks and 150 on the closing day did not use a 150-student plan — while the
 * end-of-period figure is what a tenant sees on their own dashboard, so keeping both
 * avoids an argument about which one the invoice used.
 */
@Entity
@Table(name = "org_usage_snapshot")
@Data
@NoArgsConstructor
public class OrgUsageSnapshot {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "organization_id", nullable = false)
    private Long organizationId;

    /** Billing month as {@code YYYY-MM}. */
    @Column(name = "period_ym", nullable = false, length = 7)
    private String periodYm;

    @Column(name = "captured_at", nullable = false)
    private LocalDateTime capturedAt = LocalDateTime.now();

    /** True once the period has closed and these figures are final for billing. */
    @Column(name = "is_final", nullable = false)
    private Boolean isFinal = false;

    @Column(name = "active_students_peak", nullable = false)
    private Integer activeStudentsPeak = 0;

    @Column(name = "active_students_end", nullable = false)
    private Integer activeStudentsEnd = 0;

    @Column(name = "faculty_accounts", nullable = false)
    private Integer facultyAccounts = 0;

    @Column(nullable = false)
    private Integer branches = 0;

    @Column(name = "storage_bytes", nullable = false)
    private Long storageBytes = 0L;

    @Column(name = "sms_used", nullable = false)
    private Integer smsUsed = 0;

    @Column(name = "whatsapp_used", nullable = false)
    private Integer whatsappUsed = 0;

    @Column(name = "email_used", nullable = false)
    private Integer emailUsed = 0;

    @Column(name = "training_hours_used", nullable = false)
    private BigDecimal trainingHoursUsed = BigDecimal.ZERO;

    /**
     * The student allowance in force during the period, copied here so an overage
     * charge can still be explained after the tenant changes plan.
     */
    @Column(name = "students_allowance")
    private Integer studentsAllowance;

    @Column(name = "overage_students", nullable = false)
    private Integer overageStudents = 0;

    @Column(name = "overage_student_price")
    private BigDecimal overageStudentPrice;

    @Column(name = "overage_amount", nullable = false)
    private BigDecimal overageAmount = BigDecimal.ZERO;

    @Column(name = "plan_code", length = 40)
    private String planCode;

    /** Any further measured detail, as JSON. */
    @Column(name = "snapshot_json", columnDefinition = "TEXT")
    private String snapshotJson;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    /**
     * Recomputes the overage figures from the peak count against the recorded
     * allowance. Called before finalising so the billed amount always agrees with the
     * measured usage rather than depending on when it was last set.
     */
    public void recomputeOverage() {
        if (studentsAllowance == null || studentsAllowance <= 0) {
            // No allowance recorded means unlimited, so nothing is over.
            overageStudents = 0;
            overageAmount = BigDecimal.ZERO;
            return;
        }
        int peak = activeStudentsPeak != null ? activeStudentsPeak : 0;
        overageStudents = Math.max(0, peak - studentsAllowance);
        overageAmount = overageStudentPrice != null
                ? overageStudentPrice.multiply(BigDecimal.valueOf(overageStudents))
                : BigDecimal.ZERO;
    }

    @PrePersist
    public void prePersist() {
        if (createdAt == null) createdAt = LocalDateTime.now();
        if (updatedAt == null) updatedAt = LocalDateTime.now();
        if (capturedAt == null) capturedAt = LocalDateTime.now();
        applyDefaults();
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = LocalDateTime.now();
        applyDefaults();
    }

    private void applyDefaults() {
        if (isFinal == null) isFinal = false;
        if (activeStudentsPeak == null) activeStudentsPeak = 0;
        if (activeStudentsEnd == null) activeStudentsEnd = 0;
        if (facultyAccounts == null) facultyAccounts = 0;
        if (branches == null) branches = 0;
        if (storageBytes == null) storageBytes = 0L;
        if (smsUsed == null) smsUsed = 0;
        if (whatsappUsed == null) whatsappUsed = 0;
        if (emailUsed == null) emailUsed = 0;
        if (trainingHoursUsed == null) trainingHoursUsed = BigDecimal.ZERO;
        if (overageStudents == null) overageStudents = 0;
        if (overageAmount == null) overageAmount = BigDecimal.ZERO;
    }
}
