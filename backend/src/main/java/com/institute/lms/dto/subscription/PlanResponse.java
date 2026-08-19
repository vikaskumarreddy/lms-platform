package com.institute.lms.dto.subscription;

import com.institute.lms.entity.OrgSubscription;
import com.institute.lms.subscription.Entitlement;
import com.institute.lms.util.JsonUtils;
import lombok.Data;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * A plan as returned to both the platform editor and the tenant Account page.
 *
 * <p>Entitlements and features are emitted as real arrays/objects rather than
 * pre-serialised JSON strings, so the UI does not have to parse them itself.
 * {@link #entitlementDetails} additionally resolves each granted key against the
 * {@link Entitlement} enum, giving the UI a display label, category and — critically —
 * the {@code salesQualified} flag, so features the platform cannot actually
 * self-provision (SSO, dedicated infrastructure, white-labelled apps) can be shown
 * as contracted rather than instantly available.
 */
@Data
public class PlanResponse {

    private Long id;
    private String code;
    private String name;
    private String tagline;
    private String description;

    private Integer tierRank;
    private Integer displayOrder;
    private Boolean isPublic;
    private Boolean isActive;
    private Boolean isPopular;

    private BigDecimal priceMonthly;
    private BigDecimal priceYearly;
    private BigDecimal annualDiscountPct;
    /** Monthly price x 12, so the UI can show the saving without recomputing it. */
    private BigDecimal yearlyListPrice;
    private String currency;
    private Boolean isCustomPriced;

    private Boolean taxInclusive;
    private String hsnSacCode;
    private BigDecimal gstRatePct;

    private Integer maxActiveStudents;
    private Integer maxFacultyAccounts;
    private Integer maxBranches;
    private Integer maxOrganizations;
    private Integer storageGb;
    private BigDecimal includedTrainingHours;
    private Boolean limitsConfigurable;

    private Integer overageStudentsAllowed;
    private BigDecimal overageStudentPrice;
    /** Monthly price divided by the student allowance — makes tier value comparable. */
    private BigDecimal effectivePricePerStudent;

    private Integer trialDays;
    private Integer graceDays;
    private Boolean selfServeUpgradeEnabled;
    private Boolean requiresQuote;
    private String fulfilmentNotes;

    private List<String> features = new ArrayList<>();
    private Map<String, Object> entitlements = new LinkedHashMap<>();
    private List<EntitlementDetail> entitlementDetails = new ArrayList<>();

    /** How many organizations are currently on this plan; drives the delete guard in the UI. */
    private Long organizationsUsing;

    /**
     * True when this plan's annual price falls outside the intended 15-20% discount
     * band. Surfaced in the plan editor so pricing drift is visible at the point of
     * editing rather than discovered on an invoice.
     */
    private Boolean annualDiscountOutOfBand;

    @Data
    public static class EntitlementDetail {
        private String key;
        private String label;
        private String category;
        private String categoryLabel;
        private String valueType;
        private Object value;
        /**
         * True when the feature needs manual delivery and cannot be provisioned by
         * flipping this flag — SSO, dedicated infrastructure, white-labelled apps,
         * custom integrations.
         */
        private Boolean salesQualified;
    }

    public static PlanResponse from(OrgSubscription plan) {
        return from(plan, null);
    }

    public static PlanResponse from(OrgSubscription plan, Long organizationsUsing) {
        PlanResponse r = new PlanResponse();
        r.id = plan.getId();
        r.code = plan.getCode();
        r.name = plan.getName();
        r.tagline = plan.getTagline();
        r.description = plan.getDescription();

        r.tierRank = plan.getTierRank();
        r.displayOrder = plan.getDisplayOrder();
        r.isPublic = plan.getIsPublic();
        r.isActive = plan.getIsActive();
        r.isPopular = plan.getIsPopular();

        r.priceMonthly = plan.getPriceMonthly();
        r.priceYearly = plan.getPriceYearly();
        r.annualDiscountPct = plan.getAnnualDiscountPct();
        r.currency = plan.getCurrency();
        r.isCustomPriced = plan.getIsCustomPriced();

        r.taxInclusive = plan.getTaxInclusive();
        r.hsnSacCode = plan.getHsnSacCode();
        r.gstRatePct = plan.getGstRatePct();

        r.maxActiveStudents = plan.getMaxActiveStudents();
        r.maxFacultyAccounts = plan.getMaxFacultyAccounts();
        r.maxBranches = plan.getMaxBranches();
        r.maxOrganizations = plan.getMaxOrganizations();
        r.storageGb = plan.getStorageGb();
        r.includedTrainingHours = plan.getIncludedTrainingHours();
        r.limitsConfigurable = plan.getLimitsConfigurable();

        r.overageStudentsAllowed = plan.getOverageStudentsAllowed();
        r.overageStudentPrice = plan.getOverageStudentPrice();

        r.trialDays = plan.getTrialDays();
        r.graceDays = plan.getGraceDays();
        r.selfServeUpgradeEnabled = plan.getSelfServeUpgradeEnabled();
        r.requiresQuote = plan.getRequiresQuote();
        r.fulfilmentNotes = plan.getFulfilmentNotes();

        r.features = JsonUtils.readStringList(plan.getFeatures());
        r.entitlements = JsonUtils.readMap(plan.getEntitlements());
        r.entitlementDetails = describe(r.entitlements);

        r.organizationsUsing = organizationsUsing;

        if (plan.getPriceMonthly() != null) {
            r.yearlyListPrice = plan.getPriceMonthly().multiply(BigDecimal.valueOf(12));
            if (plan.getMaxActiveStudents() != null && plan.getMaxActiveStudents() > 0) {
                r.effectivePricePerStudent = plan.getPriceMonthly()
                        .divide(BigDecimal.valueOf(plan.getMaxActiveStudents()), 2, java.math.RoundingMode.HALF_UP);
            }
        }
        r.annualDiscountOutOfBand = isDiscountOutOfBand(plan);
        return r;
    }

    /**
     * Resolves the raw entitlement map into UI-ready detail, skipping keys that are
     * present but not granted. Unknown keys are kept with a null category so a plan
     * edited against a newer schema still renders rather than losing rows silently.
     */
    private static List<EntitlementDetail> describe(Map<String, Object> raw) {
        List<EntitlementDetail> out = new ArrayList<>();
        raw.forEach((key, value) -> {
            boolean granted = JsonUtils.getBoolean(raw, key)
                    || (value instanceof Number n && n.doubleValue() != 0d);
            if (!granted) {
                return;
            }
            Entitlement e = Entitlement.fromKey(key);
            EntitlementDetail d = new EntitlementDetail();
            d.setKey(key);
            d.setValue(value);
            if (e != null) {
                d.setLabel(e.getLabel());
                d.setCategory(e.getCategory().name());
                d.setCategoryLabel(e.getCategory().getLabel());
                d.setValueType(e.getValueType().name());
                d.setSalesQualified(e.isSalesQualified());
            } else {
                d.setLabel(key);
                d.setSalesQualified(false);
            }
            out.add(d);
        });
        return out;
    }

    /**
     * Flags a plan whose annual price implies a discount outside 15-20%. Computed
     * from the actual prices rather than trusting the stored percentage, so a price
     * edited without updating the percentage is still caught.
     */
    private static Boolean isDiscountOutOfBand(OrgSubscription plan) {
        BigDecimal monthly = plan.getPriceMonthly();
        BigDecimal yearly = plan.getPriceYearly();
        if (monthly == null || yearly == null || monthly.signum() <= 0) {
            return null;
        }
        BigDecimal list = monthly.multiply(BigDecimal.valueOf(12));
        BigDecimal saving = list.subtract(yearly);
        BigDecimal pct = saving.multiply(BigDecimal.valueOf(100))
                .divide(list, 2, java.math.RoundingMode.HALF_UP);
        return pct.compareTo(BigDecimal.valueOf(15)) < 0 || pct.compareTo(BigDecimal.valueOf(20)) > 0;
    }
}
