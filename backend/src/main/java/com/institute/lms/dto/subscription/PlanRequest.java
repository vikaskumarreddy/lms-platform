package com.institute.lms.dto.subscription;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.institute.lms.util.JsonUtils;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

/**
 * Create/update payload for a platform plan.
 *
 * <p>Replaces the previous {@code Map<String,String>} request binding, which forced
 * every field through manual string parsing and silently defaulted booleans when a
 * key was simply absent — so a partial update could switch a plan's state without
 * the caller ever mentioning it.
 *
 * <p>Deliberately tolerant of two payload shapes for {@link #features} and
 * {@link #entitlements}: the existing plan editor posts them as pre-serialised JSON
 * strings, while the new editor sends real arrays and objects. Accepting both means
 * the API can be extended before the UI is rewritten without a flag day. Null means
 * "leave unchanged" on update, so partial payloads are safe.
 */
@Data
@JsonIgnoreProperties(ignoreUnknown = true)
public class PlanRequest {

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

    private Integer trialDays;
    private Integer graceDays;
    private Boolean selfServeUpgradeEnabled;
    private Boolean requiresQuote;
    private String fulfilmentNotes;

    /** Legacy fields still posted by the current plan editor. */
    private BigDecimal price;
    private String period;

    /** Either a JSON array string or a real array of feature bullet strings. */
    private Object features;

    /** Either a JSON object string or a real map of Entitlement name to true/number. */
    private Object entitlements;

    /**
     * Normalises {@link #features} to a JSON array string, or null when not supplied.
     * A supplied-but-empty list yields {@code "[]"}, which is a meaningful "clear it"
     * instruction rather than "leave unchanged".
     */
    public String featuresJson() {
        return normaliseJson(features, "[");
    }

    /** Normalises {@link #entitlements} to a JSON object string, or null when not supplied. */
    public String entitlementsJson() {
        return normaliseJson(entitlements, "{");
    }

    /**
     * @param expectedPrefix "[" for arrays, "{" for objects — used to reject a string
     *                       that is plainly not the JSON shape we expect, rather than
     *                       storing it and failing later at read time
     */
    private String normaliseJson(Object value, String expectedPrefix) {
        if (value == null) {
            return null;
        }
        if (value instanceof String s) {
            String trimmed = s.trim();
            if (trimmed.isEmpty()) {
                return expectedPrefix.equals("[") ? "[]" : "{}";
            }
            return trimmed.startsWith(expectedPrefix) ? trimmed : null;
        }
        if (value instanceof List<?> || value instanceof Map<?, ?>) {
            return JsonUtils.write(value);
        }
        return null;
    }
}
