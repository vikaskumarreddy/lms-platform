package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * A credit note against an invoice.
 *
 * <p>This is how an issued invoice is corrected, because an issued invoice is never
 * edited or deleted. Carries its own gapless number series, separate from invoices so
 * the two cannot be confused, and its own tax breakup — reversing tax requires stating
 * the reversal, not just netting off a total.
 */
@Entity
@Table(name = "org_credit_notes")
@Data
@NoArgsConstructor
public class OrgCreditNote {

    public static final String REASON_DOWNGRADE = "DOWNGRADE";
    public static final String REASON_CANCELLATION = "CANCELLATION";
    public static final String REASON_BILLING_ERROR = "BILLING_ERROR";
    public static final String REASON_GOODWILL = "GOODWILL";
    /** The assisted pilot fee, credited in full when the tenant converts. */
    public static final String REASON_PILOT_CREDIT = "PILOT_CREDIT";
    public static final String REASON_OTHER = "OTHER";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "organization_id", nullable = false)
    private Long organizationId;

    @Column(name = "invoice_id")
    private Long invoiceId;

    @Column(name = "credit_note_number", nullable = false, length = 40)
    private String creditNoteNumber;

    @Column(name = "financial_year", nullable = false, length = 7)
    private String financialYear;

    @Column(name = "issue_date", nullable = false)
    private LocalDate issueDate = LocalDate.now();

    @Column(name = "reason_code", nullable = false, length = 30)
    private String reasonCode = REASON_OTHER;

    @Column(columnDefinition = "TEXT")
    private String reason;

    @Column(nullable = false, length = 3)
    private String currency = "INR";

    @Column(name = "taxable_value", nullable = false)
    private BigDecimal taxableValue = BigDecimal.ZERO;

    @Column(nullable = false)
    private BigDecimal cgst = BigDecimal.ZERO;

    @Column(nullable = false)
    private BigDecimal sgst = BigDecimal.ZERO;

    @Column(nullable = false)
    private BigDecimal igst = BigDecimal.ZERO;

    @Column(nullable = false)
    private BigDecimal total = BigDecimal.ZERO;

    /** True once offset against an invoice or refunded. */
    @Column(name = "is_applied", nullable = false)
    private Boolean isApplied = false;

    @Column(name = "applied_at")
    private LocalDateTime appliedAt;

    @Column(name = "issued_by")
    private String issuedBy;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @PrePersist
    public void prePersist() {
        if (createdAt == null) createdAt = LocalDateTime.now();
        if (issueDate == null) issueDate = LocalDate.now();
        if (currency == null) currency = "INR";
        if (reasonCode == null) reasonCode = REASON_OTHER;
        if (taxableValue == null) taxableValue = BigDecimal.ZERO;
        if (cgst == null) cgst = BigDecimal.ZERO;
        if (sgst == null) sgst = BigDecimal.ZERO;
        if (igst == null) igst = BigDecimal.ZERO;
        if (total == null) total = BigDecimal.ZERO;
        if (isApplied == null) isApplied = false;
    }
}
