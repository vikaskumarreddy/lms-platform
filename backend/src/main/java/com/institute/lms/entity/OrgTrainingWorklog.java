package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * A record of trainer hours actually delivered.
 *
 * <p>This is what stops Managed Academy being billed twice for the same work. The plan
 * bundles 20 training hours a month and the contract also meters hours; without an
 * evidenced log there is no way to know which hours the base fee already covered. Hours
 * here draw down the included allowance first, and only the excess becomes billable.
 *
 * <p>{@link #invoicedInvoiceId} is set once an hour has been billed, so the same hour
 * cannot be invoiced twice.
 */
@Entity
@Table(name = "org_training_worklog")
@Data
@NoArgsConstructor
public class OrgTrainingWorklog {

    public static final String TYPE_CLASS = "CLASS";
    public static final String TYPE_PREPARATION = "PREPARATION";
    public static final String TYPE_ASSESSMENT = "ASSESSMENT";
    public static final String TYPE_MENTORING = "MENTORING";
    public static final String TYPE_MOCK_INTERVIEW = "MOCK_INTERVIEW";
    public static final String TYPE_ADMIN = "ADMIN";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "agreement_id", nullable = false)
    private Long agreementId;

    @Column(name = "organization_id", nullable = false)
    private Long organizationId;

    @Column(name = "work_date", nullable = false)
    private LocalDate workDate = LocalDate.now();

    /** Billing month, so drawdown against the monthly allowance is a simple sum. */
    @Column(name = "period_ym", nullable = false, length = 7)
    private String periodYm;

    @Column(name = "faculty_user_id")
    private Long facultyUserId;

    @Column(name = "faculty_name", length = 160)
    private String facultyName;

    @Column(name = "batch_id")
    private Long batchId;

    @Column(length = 200)
    private String subject;

    @Column(name = "session_type", nullable = false, length = 30)
    private String sessionType = TYPE_CLASS;

    @Column(nullable = false)
    private BigDecimal hours;

    @Column(name = "students_count")
    private Integer studentsCount;

    @Column(columnDefinition = "TEXT")
    private String notes;

    /** False for work covered by the plan's included hours or by a retainer. */
    @Column(nullable = false)
    private Boolean billable = true;

    @Column(name = "invoiced_invoice_id")
    private Long invoicedInvoiceId;

    @Column(name = "rate_applied")
    private BigDecimal rateApplied;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "created_by")
    private String createdBy;

    @Transient
    public boolean isInvoiced() {
        return invoicedInvoiceId != null;
    }

    @PrePersist
    public void prePersist() {
        if (createdAt == null) createdAt = LocalDateTime.now();
        if (workDate == null) workDate = LocalDate.now();
        if (periodYm == null) {
            periodYm = workDate.format(java.time.format.DateTimeFormatter.ofPattern("yyyy-MM"));
        }
        if (sessionType == null) sessionType = TYPE_CLASS;
        if (billable == null) billable = true;
    }
}
