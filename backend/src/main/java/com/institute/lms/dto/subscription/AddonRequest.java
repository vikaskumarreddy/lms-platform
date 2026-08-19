package com.institute.lms.dto.subscription;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.institute.lms.util.JsonUtils;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

/**
 * Create/update payload for an add-on definition. Null means "leave unchanged" on
 * update, so partial payloads are safe.
 */
@Data
@JsonIgnoreProperties(ignoreUnknown = true)
public class AddonRequest {

    private String code;
    private String name;
    private String description;
    /** {@code AddonCategory} name. */
    private String category;
    /** {@code AddonPricingModel} name. */
    private String pricingModel;

    private String unitLabel;
    private BigDecimal unitPriceMin;
    private BigDecimal unitPriceMax;
    private BigDecimal defaultUnitPrice;

    private Integer minQty;
    private Integer maxQty;
    private Integer qtyIncrement;

    /** {@code LimitKey} name whose allowance this raises, or null. */
    private String incrementsLimitKey;
    /** {@code Entitlement} name this grants, or null. */
    private String grantsEntitlementKey;

    /** Either a JSON array string or a real array of plan codes; empty means any plan. */
    private Object appliesToPlanCodes;

    private Boolean requiresQuote;
    private String fulfilmentNotes;

    private String hsnSacCode;
    private BigDecimal gstRatePct;
    private Boolean taxInclusive;

    private Boolean isActive;
    private Integer displayOrder;

    /** Normalises {@link #appliesToPlanCodes} to a JSON array string, or null if not supplied. */
    public String appliesToPlanCodesJson() {
        if (appliesToPlanCodes == null) {
            return null;
        }
        if (appliesToPlanCodes instanceof String s) {
            String trimmed = s.trim();
            if (trimmed.isEmpty()) {
                return "[]";
            }
            return trimmed.startsWith("[") ? trimmed : null;
        }
        if (appliesToPlanCodes instanceof List<?>) {
            return JsonUtils.write(appliesToPlanCodes);
        }
        return null;
    }
}
