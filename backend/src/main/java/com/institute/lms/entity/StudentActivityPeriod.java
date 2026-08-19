package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * Evidence that one student was active in one billing month — the unit the
 * active-student metric is counted from.
 *
 * <p>One row per {@code (organization, student, period_ym)}, enforced by a unique
 * index, so a student's tenth login in a month increments {@link #activityCount}
 * rather than creating a second billable row.
 *
 * <p>Rows are only ever created and enriched, never deleted: an invoice raised for
 * July has to remain defensible in December. A student who does nothing in a month
 * simply has no row for it, which is what makes inactive and alumni accounts free
 * without any special-casing.
 *
 * <p>Not a {@link BaseEntity}. It carries a plain {@code organization_id} with no
 * {@code @TenantId} because the platform must aggregate these across tenants to bill —
 * something a tenant-scoped entity cannot do, since the super admin's session runs
 * under a sentinel tenant matching no row.
 */
@Entity
@Table(name = "student_activity_period")
@Data
@NoArgsConstructor
public class StudentActivityPeriod {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "organization_id", nullable = false)
    private Long organizationId;

    @Column(name = "student_id", nullable = false)
    private Long studentId;

    /** Billing month as {@code YYYY-MM}. */
    @Column(name = "period_ym", nullable = false, length = 7)
    private String periodYm;

    @Column(name = "first_activity_at", nullable = false)
    private LocalDateTime firstActivityAt = LocalDateTime.now();

    @Column(name = "last_activity_at", nullable = false)
    private LocalDateTime lastActivityAt = LocalDateTime.now();

    @Column(name = "activity_count", nullable = false)
    private Integer activityCount = 1;

    /** Which event first made this student billable this month. */
    @Column(name = "first_activity_type", nullable = false, length = 30)
    private String firstActivityType;

    /** JSON array of every distinct {@code ActivityType} seen this month. */
    @Column(name = "activity_types", columnDefinition = "TEXT", nullable = false)
    private String activityTypes = "[]";

    /**
     * True when this student was beyond the plan allowance at the moment they became
     * active. Recorded at the time rather than derived later, because the allowance in
     * force then is what the overage charge rests on and the plan may since have changed.
     */
    @Column(name = "was_overage", nullable = false)
    private Boolean wasOverage = false;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    public void prePersist() {
        if (createdAt == null) createdAt = LocalDateTime.now();
        if (updatedAt == null) updatedAt = LocalDateTime.now();
        if (firstActivityAt == null) firstActivityAt = LocalDateTime.now();
        if (lastActivityAt == null) lastActivityAt = firstActivityAt;
        if (activityCount == null || activityCount < 1) activityCount = 1;
        if (activityTypes == null || activityTypes.isBlank()) activityTypes = "[]";
        if (wasOverage == null) wasOverage = false;
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
