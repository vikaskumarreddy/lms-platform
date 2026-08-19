package com.institute.lms.service.billing;

import com.institute.lms.entity.OrgCoupon;
import com.institute.lms.entity.OrgCouponRedemption;
import com.institute.lms.exception.BadRequestException;
import com.institute.lms.exception.ErrorCode;
import com.institute.lms.exception.ResourceNotFoundException;
import com.institute.lms.repository.OrgCouponRepository;
import com.institute.lms.repository.OrgCouponRedemptionRepository;
import com.institute.lms.util.JsonUtils;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

/**
 * Validates and redeems promotional codes.
 *
 * <p>{@link #quote} is deliberately non-throwing: it answers "would this code work, and
 * for how much" so the UI can show the effect of a code as it is typed. Redemption is a
 * separate, transactional step, because a quote that silently consumed a
 * limited-use coupon would burn it on every keystroke.
 */
@Service
public class CouponService {

    private final OrgCouponRepository couponRepository;
    private final OrgCouponRedemptionRepository redemptionRepository;

    public CouponService(OrgCouponRepository couponRepository,
                         OrgCouponRedemptionRepository redemptionRepository) {
        this.couponRepository = couponRepository;
        this.redemptionRepository = redemptionRepository;
    }

    /**
     * The outcome of checking a code.
     *
     * @param message plain-language reason, shown directly to the user whether the code
     *                worked or not
     */
    public record CouponQuote(
            boolean valid,
            OrgCoupon coupon,
            BigDecimal discount,
            BigDecimal finalAmount,
            String message
    ) { }

    public List<OrgCoupon> all() {
        return couponRepository.findAllByOrderByCreatedAtDesc();
    }

    /** Checks a code without consuming it. */
    public CouponQuote quote(String code, Long organizationId, String planCode, BigDecimal amount) {
        BigDecimal base = amount != null ? amount : BigDecimal.ZERO;

        if (code == null || code.isBlank()) {
            return new CouponQuote(false, null, BigDecimal.ZERO, base, "Enter a code.");
        }

        OrgCoupon coupon = couponRepository.findByCodeIgnoreCase(code.trim()).orElse(null);
        if (coupon == null) {
            return new CouponQuote(false, null, BigDecimal.ZERO, base,
                    "We don't recognise that code.");
        }
        if (!Boolean.TRUE.equals(coupon.getIsActive())) {
            return new CouponQuote(false, coupon, BigDecimal.ZERO, base,
                    "That code is no longer active.");
        }

        LocalDateTime now = LocalDateTime.now();
        if (coupon.getValidFrom() != null && coupon.getValidFrom().isAfter(now)) {
            return new CouponQuote(false, coupon, BigDecimal.ZERO, base,
                    "That code isn't valid yet.");
        }
        if (coupon.getValidTo() != null && coupon.getValidTo().isBefore(now)) {
            return new CouponQuote(false, coupon, BigDecimal.ZERO, base, "That code has expired.");
        }
        if (coupon.getMaxRedemptions() != null
                && coupon.getRedemptionsUsed() >= coupon.getMaxRedemptions()) {
            return new CouponQuote(false, coupon, BigDecimal.ZERO, base,
                    "That code has been fully redeemed.");
        }
        if (planCode != null && !JsonUtils.listContains(coupon.getAppliesToPlanCodes(), planCode)) {
            return new CouponQuote(false, coupon, BigDecimal.ZERO, base,
                    "That code doesn't apply to this plan.");
        }
        if (organizationId != null) {
            long used = redemptionRepository.countByCouponIdAndOrganizationId(coupon.getId(), organizationId);
            if (used >= coupon.getMaxPerOrganization()) {
                return new CouponQuote(false, coupon, BigDecimal.ZERO, base,
                        "You've already used that code.");
            }
        }

        BigDecimal discount = coupon.discountOn(base);
        return new CouponQuote(true, coupon, discount, base.subtract(discount),
                String.format("%s applied — %s off.", coupon.getCode(), discount.toPlainString()));
    }

    /**
     * Redeems a code, recording the use so per-organization and total limits hold.
     *
     * <p>Re-validates rather than trusting an earlier quote: between the customer seeing
     * the discount and confirming it, a limited-use coupon may have been exhausted by
     * someone else.
     */
    @Transactional
    public OrgCouponRedemption redeem(String code, Long organizationId, Long subscriptionInstanceId,
                                      Long invoiceId, BigDecimal amount, String actor) {
        CouponQuote quote = quote(code, organizationId, null, amount);
        if (!quote.valid()) {
            throw new BadRequestException(ErrorCode.COUPON_INVALID, quote.message());
        }

        OrgCoupon coupon = quote.coupon();
        coupon.setRedemptionsUsed(coupon.getRedemptionsUsed() + 1);
        couponRepository.save(coupon);

        OrgCouponRedemption redemption = new OrgCouponRedemption();
        redemption.setCouponId(coupon.getId());
        redemption.setCouponCode(coupon.getCode());
        redemption.setOrganizationId(organizationId);
        redemption.setSubscriptionInstanceId(subscriptionInstanceId);
        redemption.setInvoiceId(invoiceId);
        redemption.setDiscountApplied(quote.discount());
        redemption.setRedeemedBy(actor);
        return redemptionRepository.save(redemption);
    }

    @Transactional
    public OrgCoupon create(Map<String, Object> body, String actor) {
        String code = str(body.get("code"));
        if (code == null || code.isBlank()) {
            throw BadRequestException.field("code", "is required");
        }
        if (couponRepository.findByCodeIgnoreCase(code.trim()).isPresent()) {
            throw new BadRequestException("A coupon with that code already exists.");
        }

        OrgCoupon coupon = new OrgCoupon();
        coupon.setCode(code);
        coupon.setCreatedBy(actor);
        apply(coupon, body);
        validate(coupon);
        return couponRepository.save(coupon);
    }

    @Transactional
    public OrgCoupon update(Long id, Map<String, Object> body) {
        OrgCoupon coupon = couponRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Coupon", id));
        apply(coupon, body);
        validate(coupon);
        return couponRepository.save(coupon);
    }

    /** Deactivates rather than deletes, so redemption history stays explicable. */
    @Transactional
    public void deactivate(Long id) {
        OrgCoupon coupon = couponRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Coupon", id));
        coupon.setIsActive(false);
        couponRepository.save(coupon);
    }

    private void apply(OrgCoupon coupon, Map<String, Object> body) {
        if (body.containsKey("description")) coupon.setDescription(str(body.get("description")));
        if (body.containsKey("discountType")) coupon.setDiscountType(str(body.get("discountType")));
        if (body.containsKey("value")) coupon.setValue(decimal(body.get("value")));
        if (body.containsKey("maxDiscountAmount")) coupon.setMaxDiscountAmount(decimal(body.get("maxDiscountAmount")));
        if (body.containsKey("firstPeriodOnly")) {
            coupon.setFirstPeriodOnly(Boolean.parseBoolean(String.valueOf(body.get("firstPeriodOnly"))));
        }
        if (body.containsKey("maxRedemptions")) coupon.setMaxRedemptions(integer(body.get("maxRedemptions")));
        if (body.containsKey("maxPerOrganization")) {
            Integer perOrg = integer(body.get("maxPerOrganization"));
            coupon.setMaxPerOrganization(perOrg != null ? perOrg : 1);
        }
        if (body.containsKey("isActive")) {
            coupon.setIsActive(Boolean.parseBoolean(String.valueOf(body.get("isActive"))));
        }
        if (body.get("validFrom") != null) {
            coupon.setValidFrom(LocalDateTime.parse(body.get("validFrom").toString()));
        }
        if (body.get("validTo") != null) {
            coupon.setValidTo(LocalDateTime.parse(body.get("validTo").toString()));
        }
        if (body.containsKey("appliesToPlanCodes")) {
            Object raw = body.get("appliesToPlanCodes");
            coupon.setAppliesToPlanCodes(raw instanceof List<?> ? JsonUtils.write(raw) : str(raw));
        }
    }

    private void validate(OrgCoupon coupon) {
        if (coupon.getValue() == null || coupon.getValue().signum() <= 0) {
            throw BadRequestException.field("value", "must be greater than zero");
        }
        if (OrgCoupon.TYPE_PERCENT.equals(coupon.getDiscountType())) {
            if (coupon.getValue().compareTo(BigDecimal.valueOf(100)) > 0) {
                throw BadRequestException.field("value", "cannot exceed 100%");
            }
            // Plans here span ₹4,999 to ₹5,00,000, so an uncapped percentage is a real
            // exposure: "50% off" meant for a Platform trial would take ₹2,50,000 off a
            // Managed Academy annual contract.
            if (coupon.getMaxDiscountAmount() == null
                    && coupon.getValue().compareTo(BigDecimal.valueOf(25)) > 0) {
                throw new BadRequestException(
                        "A discount above 25% needs a maximum amount, otherwise it could take a very "
                                + "large sum off an Enterprise or Managed Academy contract.");
            }
        }
        if (coupon.getValidFrom() != null && coupon.getValidTo() != null
                && coupon.getValidFrom().isAfter(coupon.getValidTo())) {
            throw new BadRequestException("The start date is after the end date.");
        }
    }

    private String str(Object value) {
        return value != null ? value.toString() : null;
    }

    private BigDecimal decimal(Object value) {
        if (value == null) {
            return null;
        }
        try {
            return new BigDecimal(value.toString().trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private Integer integer(Object value) {
        if (value == null) {
            return null;
        }
        try {
            return Integer.parseInt(value.toString().trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
