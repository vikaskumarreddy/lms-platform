package com.institute.lms.dto.subscription;

import com.institute.lms.entity.PlanAddon;
import com.institute.lms.subscription.Entitlement;
import com.institute.lms.subscription.LimitKey;
import com.institute.lms.util.JsonUtils;
import lombok.Data;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

/**
 * An add-on definition as returned to the platform editor and the tenant Account page.
 *
 * <p>{@link #fulfilmentNotes} is populated only for platform users. Several notes
 * describe work the platform cannot currently do (SSO has no implementation,
 * dedicated infrastructure means a separate deployment, branded apps need per-tenant
 * builds), which is guidance for whoever scopes the work — not something to show a
 * prospective customer.
 */
@Data
public class AddonResponse {

    private Long id;
    private String code;
    private String name;
    private String description;

    private String category;
    private String categoryLabel;
    private String pricingModel;
    private String pricingModelLabel;
    private Boolean recurring;
    private Boolean quantified;

    private String unitLabel;
    private BigDecimal unitPriceMin;
    private BigDecimal unitPriceMax;
    private BigDecimal defaultUnitPrice;

    private Integer minQty;
    private Integer maxQty;
    private Integer qtyIncrement;

    private String incrementsLimitKey;
    /** Human label for the raised limit, e.g. "faculty seats". */
    private String incrementsLimitLabel;
    private String grantsEntitlementKey;
    private String grantsEntitlementLabel;

    private List<String> appliesToPlanCodes = new ArrayList<>();
    private Boolean requiresQuote;
    /** Platform-only. Null in tenant-facing responses. */
    private String fulfilmentNotes;

    private String hsnSacCode;
    private BigDecimal gstRatePct;
    private Boolean taxInclusive;

    private Boolean isActive;
    private Integer displayOrder;

    public static AddonResponse from(PlanAddon addon, boolean includeInternalNotes) {
        AddonResponse r = new AddonResponse();
        r.id = addon.getId();
        r.code = addon.getCode();
        r.name = addon.getName();
        r.description = addon.getDescription();

        if (addon.getCategory() != null) {
            r.category = addon.getCategory().name();
            r.categoryLabel = addon.getCategory().getLabel();
        }
        if (addon.getPricingModel() != null) {
            r.pricingModel = addon.getPricingModel().name();
            r.pricingModelLabel = addon.getPricingModel().getLabel();
            r.recurring = addon.getPricingModel().isRecurring();
            r.quantified = addon.getPricingModel().isQuantified();
        }

        r.unitLabel = addon.getUnitLabel();
        r.unitPriceMin = addon.getUnitPriceMin();
        r.unitPriceMax = addon.getUnitPriceMax();
        r.defaultUnitPrice = addon.getDefaultUnitPrice();

        r.minQty = addon.getMinQty();
        r.maxQty = addon.getMaxQty();
        r.qtyIncrement = addon.getQtyIncrement();

        r.incrementsLimitKey = addon.getIncrementsLimitKey();
        LimitKey limit = LimitKey.fromKey(addon.getIncrementsLimitKey());
        r.incrementsLimitLabel = limit != null ? limit.getPluralLabel() : null;

        r.grantsEntitlementKey = addon.getGrantsEntitlementKey();
        Entitlement ent = Entitlement.fromKey(addon.getGrantsEntitlementKey());
        r.grantsEntitlementLabel = ent != null ? ent.getLabel() : null;

        r.appliesToPlanCodes = JsonUtils.readStringList(addon.getAppliesToPlanCodes());
        r.requiresQuote = addon.getRequiresQuote();
        r.fulfilmentNotes = includeInternalNotes ? addon.getFulfilmentNotes() : null;

        r.hsnSacCode = addon.getHsnSacCode();
        r.gstRatePct = addon.getGstRatePct();
        r.taxInclusive = addon.getTaxInclusive();

        r.isActive = addon.getIsActive();
        r.displayOrder = addon.getDisplayOrder();
        return r;
    }
}
