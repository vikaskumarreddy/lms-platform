package com.institute.lms.service.subscription;

import com.institute.lms.entity.OrgSubscriptionInstance;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Duration;
import java.time.LocalDateTime;

/**
 * Works out what a tenant owes when they change plan part-way through a paid term.
 *
 * <p>The rule is day-based and symmetric: the unused portion of the current term is
 * credited, the same portion of the new plan is charged, and the difference is
 * settled. A tenant who upgrades on day 20 of a 30-day month is charged a third of the
 * difference, not a whole extra month — and a tenant who downgrades gets a credit
 * rather than silently losing what they already paid for.
 *
 * <p>Day granularity is chosen over per-second precision deliberately: invoices are
 * argued over by humans, and "18 of 30 days remaining" is checkable by the customer
 * in a way that a fractional-second computation is not.
 */
@Component
public class ProrationCalculator {

    private static final int SCALE = 2;

    /**
     * The outcome of a mid-term plan change.
     *
     * @param daysInPeriod   length of the current term in days
     * @param daysRemaining  unused days left in the current term
     * @param unusedCredit   value of the unused portion of the current plan
     * @param newCharge      cost of the same portion on the new plan
     * @param netAmount      {@code newCharge - unusedCredit}; negative means we owe the customer
     * @param explanation    human-readable derivation, stored on the invoice line and
     *                       the billing event so the figure can be defended later
     */
    public record ProrationResult(
            int daysInPeriod,
            int daysRemaining,
            BigDecimal unusedCredit,
            BigDecimal newCharge,
            BigDecimal netAmount,
            String explanation
    ) {
        /** True when the change results in a refund or credit rather than a charge. */
        public boolean isCredit() {
            return netAmount.signum() < 0;
        }

        /** True when nothing needs to be billed or credited. */
        public boolean isZero() {
            return netAmount.signum() == 0;
        }

        /** The amount to charge, floored at zero — a credit is handled as a credit note. */
        public BigDecimal chargeable() {
            return netAmount.signum() > 0 ? netAmount : BigDecimal.ZERO;
        }

        /** The amount to credit as a positive number, or zero. */
        public BigDecimal creditable() {
            return netAmount.signum() < 0 ? netAmount.negate() : BigDecimal.ZERO;
        }
    }

    /**
     * Prorates a plan change against the tenant's current term.
     *
     * @param current  the term being replaced; may be null for a brand-new subscription
     * @param newPrice the new plan's price for the same billing cycle; null when the new
     *                 plan is custom-priced, in which case nothing is computed because
     *                 sales will quote the figure
     * @param at       the moment of the change, normally now
     */
    public ProrationResult prorate(OrgSubscriptionInstance current, BigDecimal newPrice, LocalDateTime at) {
        LocalDateTime now = at != null ? at : LocalDateTime.now();

        if (current == null) {
            return none("New subscription — nothing to prorate.");
        }
        if (current.getPeriodEnd() == null) {
            // A negotiated or perpetual term has no computable remaining fraction.
            // Inventing one here would put a number on an invoice that no agreement
            // supports, so this is left for sales to quote.
            return none("The current term has no fixed end date, so it cannot be prorated automatically. "
                    + "The adjustment needs to be agreed and entered manually.");
        }

        int daysInPeriod = wholeDays(current.getPeriodStart(), current.getPeriodEnd());
        if (daysInPeriod <= 0) {
            return none("The current term is shorter than a day, so no proration applies.");
        }

        int daysRemaining = Math.max(0, wholeDays(now, current.getPeriodEnd()));
        if (daysRemaining == 0) {
            return new ProrationResult(daysInPeriod, 0, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO,
                    "The current term has already ended, so the new plan is charged in full from today.");
        }

        BigDecimal remainingFraction = BigDecimal.valueOf(daysRemaining)
                .divide(BigDecimal.valueOf(daysInPeriod), 10, RoundingMode.HALF_UP);

        BigDecimal currentPrice = current.getUnitPrice() != null ? current.getUnitPrice() : BigDecimal.ZERO;
        BigDecimal unusedCredit = scale(currentPrice.multiply(remainingFraction));

        if (newPrice == null) {
            // Custom-priced target: credit the unused portion, but leave the charge to
            // the quotation rather than guessing at a price nobody has agreed.
            return new ProrationResult(daysInPeriod, daysRemaining, unusedCredit, BigDecimal.ZERO,
                    unusedCredit.negate(),
                    String.format("%d of %d days unused on the current plan, credited as %s. "
                                    + "The new plan is custom priced, so its charge comes from the quotation.",
                            daysRemaining, daysInPeriod, unusedCredit.toPlainString()));
        }

        BigDecimal newCharge = scale(newPrice.multiply(remainingFraction));
        BigDecimal net = scale(newCharge.subtract(unusedCredit));

        String explanation = String.format(
                "%d of %d days remain in the current term. Unused credit %s, new plan charge for the same "
                        + "period %s, net %s%s.",
                daysRemaining, daysInPeriod,
                unusedCredit.toPlainString(), newCharge.toPlainString(),
                net.abs().toPlainString(),
                net.signum() < 0 ? " to credit" : " to charge");

        return new ProrationResult(daysInPeriod, daysRemaining, unusedCredit, newCharge, net, explanation);
    }

    /**
     * Value of the unused remainder of a term, used when cancelling mid-term to size a
     * credit note.
     */
    public BigDecimal unusedValue(OrgSubscriptionInstance instance, LocalDateTime at) {
        ProrationResult result = prorate(instance, BigDecimal.ZERO, at);
        return result.unusedCredit();
    }

    private ProrationResult none(String explanation) {
        return new ProrationResult(0, 0, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, explanation);
    }

    /**
     * Whole days between two instants, rounding up any partial day so a customer is
     * never charged for a day they have already largely used.
     */
    private int wholeDays(LocalDateTime from, LocalDateTime to) {
        if (from == null || to == null) {
            return 0;
        }
        Duration duration = Duration.between(from, to);
        if (duration.isNegative()) {
            return (int) duration.toDays();
        }
        long days = duration.toDays();
        if (duration.minusDays(days).toHours() > 0) {
            days += 1;
        }
        return (int) days;
    }

    private BigDecimal scale(BigDecimal value) {
        return value.setScale(SCALE, RoundingMode.HALF_UP);
    }
}
