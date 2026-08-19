package com.institute.lms.service.billing;

import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.math.RoundingMode;

/**
 * Splits Indian GST across CGST, SGST and IGST.
 *
 * <p>The rule: an intra-state supply (the customer's place of supply is in the same
 * state as ours) splits the rate evenly into CGST and SGST; an inter-state supply
 * charges the whole rate as IGST. Get this wrong and the invoice is not filable —
 * the customer cannot claim input credit on a wrongly-headed tax, and the return
 * will not reconcile.
 *
 * <p>Comparison is on the two-digit GST state code, not the state name, because
 * "Telangana", "TELANGANA" and "TS" are the same state and "36" is unambiguous.
 *
 * <p>Rounding is applied once per line at two decimal places. Rounding an
 * invoice-level total instead would let the lines fail to sum to it, which is the
 * first thing a reviewer notices.
 */
@Component
public class GstCalculator {

    private static final int SCALE = 2;
    private static final BigDecimal HUNDRED = BigDecimal.valueOf(100);
    private static final BigDecimal TWO = BigDecimal.valueOf(2);

    /**
     * The tax on one line.
     *
     * @param taxableValue value the tax is charged on, after discount
     * @param cgst         central GST — zero for inter-state
     * @param sgst         state GST — zero for inter-state
     * @param igst         integrated GST — zero for intra-state
     * @param total        {@code taxableValue + cgst + sgst + igst}
     * @param interState   true when charged as IGST
     */
    public record GstBreakup(
            BigDecimal taxableValue,
            BigDecimal cgst,
            BigDecimal sgst,
            BigDecimal igst,
            BigDecimal total,
            boolean interState
    ) {
        public BigDecimal totalTax() {
            return cgst.add(sgst).add(igst);
        }
    }

    /**
     * Calculates tax on an amount.
     *
     * @param amount            the line amount
     * @param ratePct           GST rate, e.g. 18
     * @param sellerStateCode   our GST state code
     * @param customerStateCode the customer's place-of-supply state code
     * @param taxInclusive      when true, {@code amount} already contains the tax and
     *                          the taxable value is derived back out of it
     */
    public GstBreakup calculate(BigDecimal amount, BigDecimal ratePct,
                                String sellerStateCode, String customerStateCode,
                                boolean taxInclusive) {
        if (amount == null) {
            return zero();
        }
        BigDecimal rate = ratePct != null ? ratePct : BigDecimal.valueOf(18);

        BigDecimal taxable;
        if (taxInclusive && rate.signum() > 0) {
            // Back out the tax: taxable = gross / (1 + rate/100)
            BigDecimal divisor = BigDecimal.ONE.add(rate.divide(HUNDRED, 10, RoundingMode.HALF_UP));
            taxable = amount.divide(divisor, SCALE, RoundingMode.HALF_UP);
        } else {
            taxable = scale(amount);
        }

        BigDecimal totalTax = scale(taxable.multiply(rate).divide(HUNDRED, 10, RoundingMode.HALF_UP));
        boolean interState = isInterState(sellerStateCode, customerStateCode);

        BigDecimal cgst = BigDecimal.ZERO.setScale(SCALE, RoundingMode.HALF_UP);
        BigDecimal sgst = cgst;
        BigDecimal igst = cgst;

        if (interState) {
            igst = totalTax;
        } else {
            // Halve, then derive the second half by subtraction so the two always sum
            // back to the total. Halving twice can lose a paisa on an odd amount.
            cgst = scale(totalTax.divide(TWO, 10, RoundingMode.HALF_UP));
            sgst = totalTax.subtract(cgst);
        }

        return new GstBreakup(taxable, cgst, sgst, igst, taxable.add(totalTax), interState);
    }

    /**
     * Whether a supply is inter-state.
     *
     * <p>Defaults to <em>intra</em>-state when either code is missing. Both charges are
     * wrong in that situation, but an unregistered local customer is the more common
     * case, and CGST+SGST at least matches how most domestic sales are raised — the
     * real fix is refusing to issue an invoice without a place of supply, which
     * {@code InvoiceService} does.
     */
    public boolean isInterState(String sellerStateCode, String customerStateCode) {
        if (sellerStateCode == null || sellerStateCode.isBlank()
                || customerStateCode == null || customerStateCode.isBlank()) {
            return false;
        }
        return !normalise(sellerStateCode).equals(normalise(customerStateCode));
    }

    /** Adds the tax onto an exclusive amount. Convenience for display, not invoicing. */
    public BigDecimal grossOf(BigDecimal netAmount, BigDecimal ratePct) {
        if (netAmount == null) {
            return null;
        }
        BigDecimal rate = ratePct != null ? ratePct : BigDecimal.valueOf(18);
        return scale(netAmount.multiply(BigDecimal.ONE.add(rate.divide(HUNDRED, 10, RoundingMode.HALF_UP))));
    }

    private GstBreakup zero() {
        BigDecimal z = BigDecimal.ZERO.setScale(SCALE, RoundingMode.HALF_UP);
        return new GstBreakup(z, z, z, z, z, false);
    }

    /** GST state codes are two digits; pad a single digit so "9" matches "09". */
    private String normalise(String stateCode) {
        String trimmed = stateCode.trim();
        return trimmed.length() == 1 ? "0" + trimmed : trimmed;
    }

    private BigDecimal scale(BigDecimal value) {
        return value.setScale(SCALE, RoundingMode.HALF_UP);
    }
}
