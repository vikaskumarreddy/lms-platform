package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * A GST invoice raised against an organization.
 *
 * <p>Party details are <strong>snapshotted at issue</strong> rather than joined at read
 * time. An invoice has to reproduce exactly what was sent, so a customer changing their
 * registered address or GSTIN next quarter must not retroactively alter a document
 * already filed.
 *
 * <p>An issued invoice is never edited. A correction is a credit note against it
 * ({@link OrgCreditNote}) — both because that is the statutory expectation, and because
 * it is the only way the audit trail survives a mistake.
 */
@Entity
@Table(name = "org_invoices")
@Data
@NoArgsConstructor
public class OrgInvoice {

    public static final String STATUS_DRAFT = "DRAFT";
    public static final String STATUS_ISSUED = "ISSUED";
    public static final String STATUS_PARTIALLY_PAID = "PARTIALLY_PAID";
    public static final String STATUS_PAID = "PAID";
    public static final String STATUS_OVERDUE = "OVERDUE";
    public static final String STATUS_VOID = "VOID";
    public static final String STATUS_CREDITED = "CREDITED";

    public static final String TYPE_SUBSCRIPTION = "SUBSCRIPTION";
    public static final String TYPE_OVERAGE = "OVERAGE";
    public static final String TYPE_ADDON = "ADDON";
    public static final String TYPE_SERVICE = "SERVICE";
    public static final String TYPE_TRAINING = "TRAINING";
    public static final String TYPE_PILOT = "PILOT";
    public static final String TYPE_PRORATION = "PRORATION";
    public static final String TYPE_MANUAL = "MANUAL";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "organization_id", nullable = false)
    private Long organizationId;

    @Column(name = "subscription_instance_id")
    private Long subscriptionInstanceId;

    /** Statutory identifier, gapless per financial year. */
    @Column(name = "invoice_number", nullable = false, length = 40)
    private String invoiceNumber;

    @Column(name = "financial_year", nullable = false, length = 7)
    private String financialYear;

    @Column(nullable = false, length = 20)
    private String status = STATUS_DRAFT;

    @Column(name = "invoice_type", nullable = false, length = 20)
    private String invoiceType = TYPE_SUBSCRIPTION;

    @Column(name = "invoice_date", nullable = false)
    private LocalDate invoiceDate = LocalDate.now();

    @Column(name = "due_date")
    private LocalDate dueDate;

    @Column(name = "period_start")
    private LocalDate periodStart;

    @Column(name = "period_end")
    private LocalDate periodEnd;

    /** Billing month, for overage invoices. */
    @Column(name = "period_ym", length = 7)
    private String periodYm;

    @Column(nullable = false, length = 3)
    private String currency = "INR";

    @Column(nullable = false)
    private BigDecimal subtotal = BigDecimal.ZERO;

    @Column(name = "discount_total", nullable = false)
    private BigDecimal discountTotal = BigDecimal.ZERO;

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

    @Column(name = "amount_paid", nullable = false)
    private BigDecimal amountPaid = BigDecimal.ZERO;

    @Column(name = "balance_due", nullable = false)
    private BigDecimal balanceDue = BigDecimal.ZERO;

    // ---- Snapshotted party details -------------------------------------

    @Column(name = "seller_gstin", length = 15)
    private String sellerGstin;

    @Column(name = "seller_legal_name")
    private String sellerLegalName;

    @Column(name = "seller_address", columnDefinition = "TEXT")
    private String sellerAddress;

    @Column(name = "seller_state_code", length = 2)
    private String sellerStateCode;

    @Column(name = "customer_gstin", length = 15)
    private String customerGstin;

    @Column(name = "customer_legal_name")
    private String customerLegalName;

    @Column(name = "customer_address", columnDefinition = "TEXT")
    private String customerAddress;

    @Column(name = "customer_state_code", length = 2)
    private String customerStateCode;

    @Column(name = "place_of_supply", length = 120)
    private String placeOfSupply;

    @Column(name = "is_reverse_charge", nullable = false)
    private Boolean isReverseCharge = false;

    @Column(name = "po_number", length = 80)
    private String poNumber;

    @Column(name = "coupon_code", length = 60)
    private String couponCode;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "void_reason", columnDefinition = "TEXT")
    private String voidReason;

    @Column(name = "issued_at")
    private LocalDateTime issuedAt;

    @Column(name = "paid_at")
    private LocalDateTime paidAt;

    @Column(name = "voided_at")
    private LocalDateTime voidedAt;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @Column(name = "created_by")
    private String createdBy;

    /**
     * Lines, loaded eagerly and cascaded. An invoice without its lines is not an
     * invoice, and they are always read and written together.
     */
    @OneToMany(cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.EAGER)
    @JoinColumn(name = "invoice_id")
    @OrderBy("lineNo ASC")
    private List<OrgInvoiceLine> lines = new ArrayList<>();

    // ---- Derived state --------------------------------------------------

    @Transient
    public boolean isEditable() {
        return STATUS_DRAFT.equals(status);
    }

    @Transient
    public boolean isPayable() {
        return STATUS_ISSUED.equals(status)
                || STATUS_PARTIALLY_PAID.equals(status)
                || STATUS_OVERDUE.equals(status);
    }

    @Transient
    public boolean isOverdue() {
        return isPayable() && dueDate != null && dueDate.isBefore(LocalDate.now());
    }

    @Transient
    public BigDecimal totalTax() {
        return cgst.add(sgst).add(igst);
    }

    /**
     * Recomputes the header from the lines and recorded payments.
     *
     * <p>Always derived, never set directly: a header that can drift from its own lines
     * is the first thing a customer spots and the hardest thing to explain.
     */
    public void recalculate() {
        BigDecimal sub = BigDecimal.ZERO;
        BigDecimal discount = BigDecimal.ZERO;
        BigDecimal taxable = BigDecimal.ZERO;
        BigDecimal c = BigDecimal.ZERO;
        BigDecimal s = BigDecimal.ZERO;
        BigDecimal i = BigDecimal.ZERO;

        for (OrgInvoiceLine line : lines) {
            sub = sub.add(line.getUnitPrice().multiply(line.getQty()));
            discount = discount.add(line.getDiscount());
            taxable = taxable.add(line.getTaxableValue());
            c = c.add(line.getCgst());
            s = s.add(line.getSgst());
            i = i.add(line.getIgst());
        }

        this.subtotal = sub;
        this.discountTotal = discount;
        this.taxableValue = taxable;
        this.cgst = c;
        this.sgst = s;
        this.igst = i;
        this.total = taxable.add(c).add(s).add(i);
        this.balanceDue = this.total.subtract(this.amountPaid != null ? this.amountPaid : BigDecimal.ZERO);
    }

    /**
     * Advances the status after a payment is recorded.
     *
     * <p>Uses {@code compareTo} rather than {@code equals} throughout, because
     * {@code BigDecimal.equals} also compares scale — {@code 100.0} and {@code 100.00}
     * are not equal, which would leave a fully-settled invoice sitting as partially
     * paid purely because of how the amount was entered.
     */
    public void applyPaymentTotals(BigDecimal newAmountPaid) {
        this.amountPaid = newAmountPaid != null ? newAmountPaid : BigDecimal.ZERO;
        this.balanceDue = this.total.subtract(this.amountPaid);

        if (STATUS_VOID.equals(status) || STATUS_CREDITED.equals(status)) {
            return;
        }
        if (this.balanceDue.compareTo(BigDecimal.ZERO) <= 0 && this.total.compareTo(BigDecimal.ZERO) > 0) {
            this.status = STATUS_PAID;
            if (this.paidAt == null) {
                this.paidAt = LocalDateTime.now();
            }
        } else if (this.amountPaid.compareTo(BigDecimal.ZERO) > 0) {
            this.status = STATUS_PARTIALLY_PAID;
        } else if (isOverdue()) {
            this.status = STATUS_OVERDUE;
        } else {
            this.status = STATUS_ISSUED;
        }
    }

    public void addLine(OrgInvoiceLine line) {
        line.setLineNo(lines.size() + 1);
        lines.add(line);
    }

    @PrePersist
    public void prePersist() {
        if (createdAt == null) createdAt = LocalDateTime.now();
        if (updatedAt == null) updatedAt = LocalDateTime.now();
        if (invoiceDate == null) invoiceDate = LocalDate.now();
        applyDefaults();
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = LocalDateTime.now();
        applyDefaults();
    }

    private void applyDefaults() {
        if (status == null) status = STATUS_DRAFT;
        if (invoiceType == null) invoiceType = TYPE_SUBSCRIPTION;
        if (currency == null) currency = "INR";
        if (subtotal == null) subtotal = BigDecimal.ZERO;
        if (discountTotal == null) discountTotal = BigDecimal.ZERO;
        if (taxableValue == null) taxableValue = BigDecimal.ZERO;
        if (cgst == null) cgst = BigDecimal.ZERO;
        if (sgst == null) sgst = BigDecimal.ZERO;
        if (igst == null) igst = BigDecimal.ZERO;
        if (total == null) total = BigDecimal.ZERO;
        if (amountPaid == null) amountPaid = BigDecimal.ZERO;
        if (balanceDue == null) balanceDue = BigDecimal.ZERO;
        if (isReverseCharge == null) isReverseCharge = false;
    }
}
