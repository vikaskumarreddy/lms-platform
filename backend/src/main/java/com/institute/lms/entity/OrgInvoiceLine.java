package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * One line on an invoice, carrying its own SAC code and tax.
 *
 * <p>Tax lives on the line rather than only on the header because different lines
 * attract different codes — the subscription is SAC 997331, trainer-delivered work is
 * 999293 — and a single header-level rate cannot represent a mixed invoice.
 */
@Entity
@Table(name = "org_invoice_lines")
@Data
@NoArgsConstructor
public class OrgInvoiceLine {

    public static final String TYPE_PLAN = "PLAN";
    public static final String TYPE_ADDON = "ADDON";
    public static final String TYPE_OVERAGE = "OVERAGE";
    public static final String TYPE_SERVICE = "SERVICE";
    public static final String TYPE_TRAINING = "TRAINING";
    public static final String TYPE_PRORATION = "PRORATION";
    public static final String TYPE_CREDIT = "CREDIT";
    public static final String TYPE_DISCOUNT = "DISCOUNT";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "line_no", nullable = false)
    private Integer lineNo = 1;

    @Column(name = "line_type", nullable = false, length = 20)
    private String lineType = TYPE_PLAN;

    @Column(nullable = false, length = 500)
    private String description;

    @Column(name = "hsn_sac_code", length = 10)
    private String hsnSacCode;

    @Column(nullable = false)
    private BigDecimal qty = BigDecimal.ONE;

    @Column(name = "unit_label", length = 60)
    private String unitLabel;

    @Column(name = "unit_price", nullable = false)
    private BigDecimal unitPrice = BigDecimal.ZERO;

    @Column(nullable = false)
    private BigDecimal discount = BigDecimal.ZERO;

    @Column(name = "taxable_value", nullable = false)
    private BigDecimal taxableValue = BigDecimal.ZERO;

    @Column(name = "tax_rate_pct", nullable = false)
    private BigDecimal taxRatePct = new BigDecimal("18.00");

    @Column(nullable = false)
    private BigDecimal cgst = BigDecimal.ZERO;

    @Column(nullable = false)
    private BigDecimal sgst = BigDecimal.ZERO;

    @Column(nullable = false)
    private BigDecimal igst = BigDecimal.ZERO;

    @Column(name = "line_total", nullable = false)
    private BigDecimal lineTotal = BigDecimal.ZERO;

    @Column(name = "addon_code", length = 60)
    private String addonCode;

    /**
     * How the amount was arrived at — most usefully, the proration derivation.
     * Persisted so a disputed figure can be explained months later without
     * recomputing it from dates that have since moved on.
     */
    @Column(columnDefinition = "TEXT")
    private String calculation;

    @PrePersist
    @PreUpdate
    public void applyDefaults() {
        if (lineNo == null) lineNo = 1;
        if (lineType == null) lineType = TYPE_PLAN;
        if (qty == null) qty = BigDecimal.ONE;
        if (unitPrice == null) unitPrice = BigDecimal.ZERO;
        if (discount == null) discount = BigDecimal.ZERO;
        if (taxableValue == null) taxableValue = BigDecimal.ZERO;
        if (taxRatePct == null) taxRatePct = new BigDecimal("18.00");
        if (cgst == null) cgst = BigDecimal.ZERO;
        if (sgst == null) sgst = BigDecimal.ZERO;
        if (igst == null) igst = BigDecimal.ZERO;
        if (lineTotal == null) lineTotal = BigDecimal.ZERO;
        if (description != null && description.length() > 500) {
            description = description.substring(0, 497) + "...";
        }
    }
}
